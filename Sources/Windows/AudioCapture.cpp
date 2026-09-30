#include "AudioCapture.h"
#include "Common.h"
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <ksmedia.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>
#include <vector>
#include <algorithm>
#include <cstring>
#include <chrono>
namespace jm {
void AudioCapture::stop(){cancelled=true;if(worker.joinable())worker.join();std::lock_guard<std::mutex> g(mutex);status.running=false;status.progress=-1;status.source="disconnected";status.error.clear();}
void AudioCapture::prepare(const char* source){stop();jm_pause(engine,0);jm_reset(engine);jm_wait_idle(engine);cancelled=false;std::lock_guard<std::mutex>g(mutex);status={};status.source=source;status.running=true;}
void AudioCapture::startSystem(){prepare("system");worker=std::thread([this]{try{capture(true);}catch(const std::exception&e){failure(e);}});}
void AudioCapture::startInput(){prepare("input");worker=std::thread([this]{try{capture(false);}catch(const std::exception&e){failure(e);}});}
void AudioCapture::startFile(const std::wstring& p){prepare("file");{std::lock_guard<std::mutex>g(mutex);status.file=utf8(std::filesystem::path(p).filename().wstring());status.progress=0;}worker=std::thread([this,p]{try{analyze(p);}catch(const std::exception&e){failure(e);}});}
SourceStatus AudioCapture::snapshot(){std::lock_guard<std::mutex>g(mutex);return status;}
void AudioCapture::failure(const std::exception&e){std::lock_guard<std::mutex>g(mutex);status.error=e.what();status.running=false;status.progress=-1;}
void AudioCapture::capture(bool loopback){
    ComApartment com;check(com.result,"Initialize audio thread");
    ComPtr<IMMDeviceEnumerator> enumerator;check(CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_ALL,IID_PPV_ARGS(&enumerator)),"Enumerate audio devices");
    ComPtr<IMMDevice> device;check(enumerator->GetDefaultAudioEndpoint(loopback?eRender:eCapture,eConsole,&device),"Open default audio device");
    ComPtr<IAudioClient> client;check(device->Activate(__uuidof(IAudioClient),CLSCTX_ALL,nullptr,&client),"Activate audio device");
    WAVEFORMATEX* raw=nullptr;check(client->GetMixFormat(&raw),"Read audio format");
    std::unique_ptr<WAVEFORMATEX,decltype(&CoTaskMemFree)> format(raw,CoTaskMemFree);
    int channels=raw->nChannels,bits=raw->wBitsPerSample;bool floating=raw->wFormatTag==WAVE_FORMAT_IEEE_FLOAT;
    if(raw->wFormatTag==WAVE_FORMAT_EXTENSIBLE&&raw->cbSize>=22){auto*f=reinterpret_cast<WAVEFORMATEXTENSIBLE*>(raw);floating=IsEqualGUID(f->SubFormat,KSDATAFORMAT_SUBTYPE_IEEE_FLOAT);if(!floating&&!IsEqualGUID(f->SubFormat,KSDATAFORMAT_SUBTYPE_PCM))throw std::runtime_error("Unsupported device format");}
    else if(!floating&&raw->wFormatTag!=WAVE_FORMAT_PCM)throw std::runtime_error("Unsupported device format");
    if(channels<1||channels>6||raw->nSamplesPerSec<8000||raw->nSamplesPerSec>384000||(floating&&bits!=32)||(!floating&&bits!=16&&bits!=24&&bits!=32))throw std::runtime_error("Select a 1-6 channel PCM audio device");
    struct Event{HANDLE h=CreateEventW(nullptr,FALSE,FALSE,nullptr);~Event(){if(h)CloseHandle(h);}} event;
    if(!event.h)throw std::runtime_error("Unable to create capture event");
    DWORD flags=AUDCLNT_STREAMFLAGS_EVENTCALLBACK|(loopback?AUDCLNT_STREAMFLAGS_LOOPBACK:0);
    check(client->Initialize(AUDCLNT_SHAREMODE_SHARED,flags,2000000,0,raw,nullptr),"Initialize shared capture");
    check(client->SetEventHandle(event.h),"Register capture event");
    ComPtr<IAudioCaptureClient> capture;check(client->GetService(IID_PPV_ARGS(&capture)),"Open capture stream");
    UINT32 capacity=0;check(client->GetBufferSize(&capacity),"Read capture buffer size");
    std::vector<float> samples(size_t(capacity)*channels);
    {std::lock_guard<std::mutex>g(mutex);status.rate=raw->nSamplesPerSec;status.channels=channels;}
    check(client->Start(),"Start audio capture");
    struct Stop{IAudioClient* c;~Stop(){c->Stop();}} stop{client.Get()};
    while(!cancelled){
        WaitForSingleObject(event.h,80);UINT32 pending=0;check(capture->GetNextPacketSize(&pending),"Read capture packet");
        while(pending&&!cancelled){BYTE* data=nullptr;UINT32 frames=0;DWORD state=0;check(capture->GetBuffer(&data,&frames,&state,nullptr,nullptr),"Read audio samples");
            if(frames>capacity){capture->ReleaseBuffer(frames);throw std::runtime_error("Audio packet exceeds capture buffer");}
            for(size_t i=0;i<size_t(frames)*channels;++i){float value=0;
                if(!(state&AUDCLNT_BUFFERFLAGS_SILENT)&&data){
                    const BYTE*p=data+i*(bits/8);
                    if(floating)std::memcpy(&value,p,4);
                    else if(bits==16){int16_t v;std::memcpy(&v,p,2);value=v/32768.f;}
                    else if(bits==24){int32_t v=int32_t(p[0])|(int32_t(p[1])<<8)|(int32_t(p[2])<<16);if(v&0x800000)v|=~0xffffff;value=v/8388608.f;}
                    else{int32_t v;std::memcpy(&v,p,4);value=float(v/2147483648.0);}
                }samples[i]=value;
            }
            jm_feed_interleaved(engine,samples.data(),channels,int(frames),raw->nSamplesPerSec);
            check(capture->ReleaseBuffer(frames),"Release capture buffer");check(capture->GetNextPacketSize(&pending),"Read next packet");
        }
    }
}
void AudioCapture::analyze(const std::wstring& path){
    ComApartment com;check(com.result,"Initialize file decoder");check(MFStartup(MF_VERSION,MFSTARTUP_LITE),"Initialize Media Foundation");
    struct Shutdown{~Shutdown(){MFShutdown();}} shutdown;
    ComPtr<IMFSourceReader> reader;check(MFCreateSourceReaderFromURL(path.c_str(),nullptr,&reader),"Open audio file");
    check(reader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,FALSE),"Select audio stream");check(reader->SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM,TRUE),"Enable audio stream");
    ComPtr<IMFMediaType> request;check(MFCreateMediaType(&request),"Create decoder format");request->SetGUID(MF_MT_MAJOR_TYPE,MFMediaType_Audio);request->SetGUID(MF_MT_SUBTYPE,MFAudioFormat_Float);
    check(reader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM,nullptr,request.Get()),"Decode audio to float PCM");
    ComPtr<IMFMediaType> actual;check(reader->GetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM,&actual),"Read decoded format");UINT32 channels=0,rate=0,bits=0;
    check(actual->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS,&channels),"Read channel count");check(actual->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,&rate),"Read sample rate");check(actual->GetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,&bits),"Read sample format");
    if(channels<1||channels>6||rate<8000||rate>384000||bits!=32)throw std::runtime_error("Audio files must contain 1-6 channels at 8-384 kHz");
    PROPVARIANT duration;PropVariantInit(&duration);double total=0;
    if(SUCCEEDED(reader->GetPresentationAttribute(MF_SOURCE_READER_MEDIASOURCE,MF_PD_DURATION,&duration))&&duration.vt==VT_UI8)total=duration.uhVal.QuadPart/10000000.0;PropVariantClear(&duration);
    {std::lock_guard<std::mutex>g(mutex);status.rate=rate;status.channels=channels;}
    uint64_t fed=0;
    while(!cancelled){
        JMSnapshot snapshot{};jm_snapshot(engine,&snapshot);if(snapshot.paused){std::this_thread::sleep_for(std::chrono::milliseconds(20));continue;}
        DWORD flags=0;LONGLONG timestamp=0;ComPtr<IMFSample> sample;
        check(reader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM,0,nullptr,&flags,&timestamp,&sample),"Decode audio packet");
        if(flags&MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)throw std::runtime_error("Audio format changed inside the file");
        if(sample){ComPtr<IMFMediaBuffer> buffer;check(sample->ConvertToContiguousBuffer(&buffer),"Read decoded samples");BYTE* data=nullptr;DWORD length=0;check(buffer->Lock(&data,nullptr,&length),"Lock decoded samples");
            const int frames=int(length/(sizeof(float)*channels));
            for(int offset=0;offset<frames&&!cancelled;){
                jm_snapshot(engine,&snapshot);if(snapshot.paused||jm_queue_available(engine)<2){std::this_thread::sleep_for(std::chrono::milliseconds(2));continue;}
                int n=std::min(1024,frames-offset);jm_feed_interleaved(engine,reinterpret_cast<const float*>(data)+size_t(offset)*channels,channels,n,rate);offset+=n;fed+=n;
            }buffer->Unlock();
            std::lock_guard<std::mutex>g(mutex);status.progress=total>0?std::min(0.999,double(fed)/rate/total):0;
        }
        if(flags&MF_SOURCE_READERF_ENDOFSTREAM)break;
    }
    jm_wait_idle(engine);std::lock_guard<std::mutex>g(mutex);status.running=false;status.progress=-1;if(!cancelled)status.source="complete";
}
}
