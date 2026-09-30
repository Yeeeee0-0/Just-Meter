#include "MeterCore.h"
#ifdef _WIN32
#include <windows.h>
#endif
#include "ebur128.h"
#include <array>
#include <atomic>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstdio>
#include <mutex>
#include <thread>
#include <vector>
#include <string>
#include <cstring>

namespace {
constexpr int N=2048, B=1024, Q=256, HC=36000;
constexpr double PI=3.14159265358979323846;
double db(double x) { return x>1e-12 ? 20*log10(x) : -INFINITY; }
JMSnapshot empty() { JMSnapshot s{}; s.integrated=s.momentary=s.shortTerm=s.maxMomentary=s.truePeak=s.samplePeak=s.leftPeak=s.rightPeak=-INFINITY; return s; }
struct Block { float data[B*6]; int frames, channels; double rate; };
struct Engine {
    std::array<Block,Q> queue;
    std::atomic<uint64_t> write{0}, read{0}, dropped{0};
    std::atomic<bool> running{true}, paused{false}, clearPeak{false};
    std::atomic<uint64_t> resetRequested{0}, resetApplied{0}, resetIndex{0};
    std::mutex lock;
    std::mutex stateLock;
    std::string savedState;
    std::atomic<uint64_t> stateVersion{0};
    std::atomic<bool> followTransport{true};
    JMSnapshot snap=empty();
    std::array<float,64> spectrum;
    std::array<float,256> vectors{};
    std::vector<JMHistory> history;
    size_t historyStart=0;
    std::thread worker;
    ebur128_state* meter=nullptr;
    std::array<float,N> fftSamples{};
    std::array<float,N> fftRight{};
    int fftCursor=0, sinceFFT=0, rate=48000, channels=2;
    uint64_t total=0, untilUpdate=0;
    double maxM=-INFINITY, peak=-INFINITY, samplePeak=-INFINITY;
    double ll=0,rr=0,lr=0; int stereoN=0;
    Engine() { spectrum.fill(-100); history.reserve(HC); worker=std::thread([this]{run();}); }
    ~Engine() { running=false; worker.join(); if(meter) ebur128_destroy(&meter); }
    void initialize(int ch,int sr) {
        if(meter) ebur128_destroy(&meter);
        channels=ch;rate=sr;
        meter=ebur128_init(ch,sr,EBUR128_MODE_I|EBUR128_MODE_S|EBUR128_MODE_LRA|EBUR128_MODE_TRUE_PEAK|EBUR128_MODE_HISTOGRAM);
        if(ch==5 && meter) { ebur128_set_channel(meter,3,EBUR128_LEFT_SURROUND); ebur128_set_channel(meter,4,EBUR128_RIGHT_SURROUND); }
        total=untilUpdate=0;maxM=peak=samplePeak=-INFINITY;ll=rr=lr=0;stereoN=0;fftCursor=sinceFFT=0;fftSamples.fill(0);fftRight.fill(0);
        std::lock_guard<std::mutex> g(lock);snap=empty();history.clear();historyStart=0;spectrum.fill(-100);vectors.fill(0);
    }
    void fft(std::array<float,64>& bins) {
        std::array<std::complex<double>,N> a,right;
        auto transform=[&](std::array<std::complex<double>,N>& a,const std::array<float,N>& samples){
        for(int i=0;i<N;++i) a[i]=samples[(fftCursor+i)%N]*(0.5-0.5*cos(2*PI*i/(N-1)));
        for(int i=1,j=0;i<N;++i) { int bit=N>>1;for(;j&bit;bit>>=1) j^=bit;j^=bit;if(i<j)std::swap(a[i],a[j]); }
        for(int len=2;len<=N;len<<=1) { auto wlen=std::polar(1.0,-2*PI/len);for(int i=0;i<N;i+=len){std::complex<double>w(1);for(int j=0;j<len/2;++j){auto u=a[i+j],v=a[i+j+len/2]*w;a[i+j]=u+v;a[i+j+len/2]=u-v;w*=wlen;}} }
        };transform(a,fftSamples);transform(right,fftRight);
        for(int b=0;b<64;++b) { double lo=20*pow(1000.0,b/64.0),hi=20*pow(1000.0,(b+1)/64.0);int i0=std::max(1,int(lo*N/rate)),i1=std::min(N/2,int(ceil(hi*N/rate)));double amp=0;for(int k=i0;k<=i1;++k)amp=std::max(amp,sqrt((norm(a[k])+norm(right[k]))*.5)*4/N);bins[b]=std::clamp(db(amp),-100.0,6.0); }
    }
    void publish(bool addHistory) {
        JMSnapshot s=empty();s.sampleRate=rate;s.channels=channels;s.seconds=double(total)/rate;s.active=total>0;
        if(total>=uint64_t(rate*.4)) ebur128_loudness_momentary(meter,&s.momentary);
        if(total>=uint64_t(rate*3)) ebur128_loudness_shortterm(meter,&s.shortTerm);
        ebur128_loudness_global(meter,&s.integrated);ebur128_loudness_range(meter,&s.range);
        maxM=std::max(maxM,s.momentary);s.maxMomentary=maxM;
        s.truePeak=peak;s.samplePeak=samplePeak;s.correlation=(ll>1e-20&&rr>1e-20)?std::clamp(lr/sqrt(ll*rr),-1.0,1.0):0;
        s.balance=ll+rr>1e-20?(rr-ll)/(rr+ll):0;
        double p=0;ebur128_prev_sample_peak(meter,0,&p);s.leftPeak=db(p);ebur128_prev_sample_peak(meter,channels>1?1:0,&p);s.rightPeak=db(p);
        std::array<float,64> bins;fft(bins);
        std::lock_guard<std::mutex> g(lock);snap=s;
        for(int b=0;b<64;++b)spectrum[b]=std::max(bins[b],spectrum[b]-2.5f);
        if(addHistory) { JMHistory h{s.seconds,s.momentary,s.shortTerm,s.integrated,s.truePeak};if(history.size()<HC)history.push_back(h);else{history[historyStart]=h;historyStart=(historyStart+1)%HC;} }
        ll=rr=lr=0;stereoN=0;
    }
    void run() {
        while(running) {
            auto request=resetRequested.load();
            if(request!=resetApplied.load()) { auto index=resetIndex.load();initialize(channels,rate);read.store(index);resetApplied=request; }
            if(clearPeak.exchange(false)) {peak=samplePeak=-INFINITY;std::lock_guard<std::mutex>g(lock);snap.truePeak=snap.samplePeak=-INFINITY;}
            auto r=read.load(std::memory_order_relaxed);
            if(r==write.load(std::memory_order_acquire)) {std::this_thread::sleep_for(std::chrono::milliseconds(1));continue;}
            const auto &b=queue[r%Q];
            if(!meter||b.channels!=channels||int(b.rate)!=rate) initialize(b.channels,int(b.rate));
            if(meter) {
                int offset=0;
                while(offset<b.frames) {
                    int n=std::min(b.frames-offset,int(rate/10-untilUpdate));
                    ebur128_add_frames_float(meter,b.data+offset*channels,n);
                    for(int c=0;c<channels;++c){double p=0;ebur128_prev_true_peak(meter,c,&p);peak=std::max(peak,db(p));ebur128_prev_sample_peak(meter,c,&p);samplePeak=std::max(samplePeak,db(p));}
                    for(int i=0;i<n;++i) {float l=b.data[(offset+i)*channels],r=b.data[(offset+i)*channels+(channels>1?1:0)];fftSamples[fftCursor]=l;fftRight[fftCursor]=r;fftCursor=(fftCursor+1)%N;ll+=l*l;rr+=r*r;lr+=l*r;}
                    total+=n;untilUpdate+=n;offset+=n;
                    if(untilUpdate>=uint64_t(rate/10)){publish(true);untilUpdate=0;}
                }
                {std::lock_guard<std::mutex>g(lock);for(int i=0;i<128;++i){int f=i*(b.frames-1)/127;vectors[i*2]=b.data[f*channels];vectors[i*2+1]=b.data[f*channels+(channels>1?1:0)];}}
                // Keep the final partial block visible for finite files.
                if(r+1==write.load(std::memory_order_acquire)&&untilUpdate>0) publish(false);
            }
            read.store(r+1,std::memory_order_release);
        }
    }
};
}
extern "C" {
JMHandle jm_create(){return new Engine;}
void jm_destroy(JMHandle h){delete static_cast<Engine*>(h);}
int jm_queue_available(JMHandle h){auto&e=*static_cast<Engine*>(h);return int(Q-(e.write.load()-e.read.load()));}
static int feed(JMHandle h,const float*const* p,const float* inter,int ch,int frames,double rate){
    if(!h||ch<1||ch>6||frames<=0||rate<8000||rate>384000)return 0;
    auto&e=*static_cast<Engine*>(h);if(e.paused)return frames;int fed=0;
    while(fed<frames){auto w=e.write.load(std::memory_order_relaxed);if(w-e.read.load(std::memory_order_acquire)>=Q){e.dropped+=frames-fed;break;}auto&b=e.queue[w%Q];b.frames=std::min(B,frames-fed);b.channels=ch;b.rate=rate;
        for(int i=0;i<b.frames;++i)for(int c=0;c<ch;++c){float v=inter?inter[(fed+i)*ch+c]:(p[c]?p[c][fed+i]:0);b.data[i*ch+c]=std::isfinite(v)?v:0;}
        fed+=b.frames;e.write.store(w+1,std::memory_order_release);
    }return fed;
}
int jm_feed(JMHandle h,const float*const*p,int c,int n,double r){return feed(h,p,nullptr,c,n,r);}
int jm_feed_interleaved(JMHandle h,const float*p,int c,int n,double r){return feed(h,nullptr,p,c,n,r);}
void jm_wait_idle(JMHandle h){auto&e=*static_cast<Engine*>(h);while(e.read.load()!=e.write.load()||e.resetRequested.load()!=e.resetApplied.load())std::this_thread::sleep_for(std::chrono::milliseconds(1));}
void jm_reset(JMHandle h){auto&e=*static_cast<Engine*>(h);e.dropped=0;e.resetIndex=e.write.load();e.resetRequested.fetch_add(1);}
void jm_pause(JMHandle h,int v){static_cast<Engine*>(h)->paused=v!=0;}
void jm_clear_peak(JMHandle h){static_cast<Engine*>(h)->clearPeak=true;}
void jm_snapshot(JMHandle h,JMSnapshot*s){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.lock);*s=e.snap;s->paused=e.paused;s->droppedFrames=e.dropped;}
void jm_spectrum(JMHandle h,float*p){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.lock);std::copy(e.spectrum.begin(),e.spectrum.end(),p);}
void jm_vectors(JMHandle h,float*p){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.lock);std::copy(e.vectors.begin(),e.vectors.end(),p);}
int jm_history(JMHandle h,JMHistory*p,int cap){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.lock);int size=int(e.history.size()),n=std::min(size,cap);for(int i=0;i<n;++i){int j=n>1?i*(size-1)/(n-1):0;p[i]=e.history[(e.historyStart+j)%size];}return n;}
int jm_write_csv(JMHandle h,const char*path){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.lock);FILE*f=nullptr;
#ifdef _WIN32
int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path,-1,nullptr,0);if(!count)return 0;std::vector<wchar_t>widePath(count);MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,path,-1,widePath.data(),count);f=_wfopen(widePath.data(),L"w");
#else
f=fopen(path,"w");
#endif
if(!f)return 0;fprintf(f,"Time_s,M_LUFS,S_LUFS,I_LUFS,TruePeakHold_dBTP\n");for(size_t i=0;i<e.history.size();++i){auto&a=e.history[(e.historyStart+i)%e.history.size()];fprintf(f,"%.3f,%.3f,%.3f,%.3f,%.3f\n",a.time,a.momentary,a.shortTerm,a.integrated,a.truePeak);}return fclose(f)==0;}
int jm_get_state(JMHandle h,char*out,int capacity){auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.stateLock);int n=int(e.savedState.size());if(out&&capacity>=n)memcpy(out,e.savedState.data(),n);return n;}
void jm_set_state(JMHandle h,const char*in,int length){if(length<0||length>1048576)return;auto&e=*static_cast<Engine*>(h);std::lock_guard<std::mutex>g(e.stateLock);e.savedState.assign(in,length);e.stateVersion++;}
uint64_t jm_state_version(JMHandle h){return static_cast<Engine*>(h)->stateVersion.load();}
void jm_set_follow_transport(JMHandle h,int follow){static_cast<Engine*>(h)->followTransport=follow!=0;}
int jm_follow_transport(JMHandle h){return static_cast<Engine*>(h)->followTransport;}
}
