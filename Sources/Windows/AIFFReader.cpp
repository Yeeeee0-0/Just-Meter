#include "AudioCapture.h"
#include "Common.h"
#include <fstream>
#include <vector>
#include <array>
#include <cmath>
#include <cstring>
#include <algorithm>
#include <chrono>
namespace jm {
namespace {
uint32_t be32(const unsigned char*p){return uint32_t(p[0])<<24|uint32_t(p[1])<<16|uint32_t(p[2])<<8|p[3];}
uint16_t be16(const unsigned char*p){return uint16_t(p[0])<<8|p[1];}
void readExact(std::ifstream&f,void*p,size_t n){if(!f.read(static_cast<char*>(p),std::streamsize(n)))throw std::runtime_error("Truncated AIFF file");}
}
bool AudioCapture::analyzeAIFF(const std::wstring& path){
    std::ifstream f(std::filesystem::path(path),std::ios::binary);std::array<unsigned char,12> header{};
    if(!f.read(reinterpret_cast<char*>(header.data()),12)||memcmp(header.data(),"FORM",4)||(memcmp(header.data()+8,"AIFF",4)&&memcmp(header.data()+8,"AIFC",4)))return false;
    const uint64_t size=std::filesystem::file_size(path),end=uint64_t(be32(header.data()+4))+8;if(end>size)throw std::runtime_error("Truncated AIFF container");
    uint32_t frames=0;int channels=0,bits=0;double rate=0;bool little=false,floating=false;uint64_t audioOffset=0,audioBytes=0;
    for(uint64_t offset=12;offset+8<=end;){
        f.seekg(std::streamoff(offset));unsigned char chunk[8];readExact(f,chunk,8);const uint32_t length=be32(chunk+4);if(uint64_t(length)>end-offset-8)throw std::runtime_error("Invalid AIFF chunk size");
        if(!memcmp(chunk,"COMM",4)){
            if(length<18)throw std::runtime_error("Invalid AIFF format chunk");unsigned char comm[22]{};readExact(f,comm,std::min(length,uint32_t(22)));channels=be16(comm);frames=be32(comm+2);bits=be16(comm+6);
            const int exponent=be16(comm+8)&0x7fff;const uint64_t mantissa=uint64_t(be32(comm+10))<<32|be32(comm+14);rate=std::ldexp(double(mantissa),exponent-16383-63);if(comm[8]&0x80)rate=-rate;
            if(!memcmp(header.data()+8,"AIFC",4)){if(length<22)throw std::runtime_error("Invalid AIFC compression");const auto code=comm+18;little=!memcmp(code,"sowt",4);floating=!memcmp(code,"fl32",4)||!memcmp(code,"FL32",4)||!memcmp(code,"fl64",4)||!memcmp(code,"FL64",4);if(!little&&!floating&&memcmp(code,"NONE",4)&&memcmp(code,"twos",4))throw std::runtime_error("Compressed AIFC is not supported; export PCM AIFF or WAV");}
        }else if(!memcmp(chunk,"SSND",4)){
            if(length<8)throw std::runtime_error("Invalid AIFF audio chunk");unsigned char ssnd[8];readExact(f,ssnd,8);uint32_t skip=be32(ssnd);if(skip>length-8)throw std::runtime_error("Invalid AIFF audio offset");audioOffset=offset+16+skip;audioBytes=length-8-skip;
        }offset+=8+uint64_t(length)+(length&1);
    }
    if(channels<1||channels>6||!std::isfinite(rate)||rate<8000||rate>384000||!audioOffset||(floating?(bits!=32&&bits!=64):(bits!=8&&bits!=16&&bits!=24&&bits!=32)))throw std::runtime_error("Unsupported AIFF format");
    const int bytes=bits/8;if(uint64_t(frames)*channels*bytes>audioBytes)throw std::runtime_error("AIFF audio data is incomplete");f.seekg(std::streamoff(audioOffset));
    {std::lock_guard<std::mutex>g(mutex);status.rate=rate;status.channels=channels;}
    std::vector<unsigned char> raw(1024*channels*bytes);std::vector<float> pcm(1024*channels);
    for(uint64_t fed=0;fed<frames&&!cancelled;){
        JMSnapshot s{};jm_snapshot(engine,&s);if(s.paused||jm_queue_available(engine)<2){std::this_thread::sleep_for(std::chrono::milliseconds(2));continue;}
        const int n=int(std::min(uint64_t(1024),uint64_t(frames)-fed));readExact(f,raw.data(),size_t(n)*channels*bytes);
        for(int i=0;i<n*channels;++i){const auto*p=raw.data()+i*bytes;uint64_t value=0;for(int b=0;b<bytes;++b)value=value<<8|p[little?bytes-1-b:b];
            if(floating&&bits==32){uint32_t v=uint32_t(value);memcpy(&pcm[i],&v,4);}else if(floating){double v;memcpy(&v,&value,8);pcm[i]=float(v);}else{int64_t signedValue=int64_t(value);if(value&(uint64_t(1)<<(bits-1)))signedValue-=int64_t(1)<<bits;pcm[i]=float(signedValue/std::ldexp(1.0,bits-1));}
        }jm_feed_interleaved(engine,pcm.data(),channels,n,rate);fed+=n;std::lock_guard<std::mutex>g(mutex);status.progress=double(fed)/frames;
    }
    jm_wait_idle(engine);std::lock_guard<std::mutex>g(mutex);status.running=false;status.progress=-1;if(!cancelled)status.source="complete";return true;
}
}
