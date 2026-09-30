#include "MeterCore.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <thread>
#include <chrono>
#include <vector>
constexpr double PI=3.141592653589793;
void feed(JMHandle h,int seconds,double amplitude,int channels=2,bool inverse=false,int block=1024,int rate=48000,double frequency=1000,double phase=0) {
    int total=seconds*rate;std::vector<float>data(block*channels);
    for(int start=0;start<total;start+=block){int n=std::min(block,total-start);for(int i=0;i<n;++i)for(int c=0;c<channels;++c)data[i*channels+c]=amplitude*sin(2*PI*frequency*(start+i)/rate+phase)*(inverse&&c==1?-1:1);
        while(jm_queue_available(h)<(n+1023)/1024+1)std::this_thread::sleep_for(std::chrono::milliseconds(1));assert(jm_feed_interleaved(h,data.data(),channels,n,rate)==n);
    }jm_wait_idle(h);
}
JMSnapshot snapshot(JMHandle h){JMSnapshot s;jm_snapshot(h,&s);return s;}
void near(double value,double expected,double tolerance,const char*name){printf("%s: %.6f (expected %.3f +/- %.3f)\n",name,value,expected,tolerance);assert(std::isfinite(value));assert(fabs(value-expected)<tolerance);}
int main(){
    auto h=jm_create();feed(h,10,.1);auto s=snapshot(h);
    near(s.integrated,-20,0.15,"Stereo 1 kHz integrated LUFS");near(s.momentary,-20,0.15,"Momentary");near(s.shortTerm,-20,0.15,"Short term");near(s.truePeak,-20,0.15,"True peak dBTP");near(s.samplePeak,-20,.01,"Sample peak");near(s.correlation,1,.0001,"In-phase correlation");near(s.seconds,10,.001,"Duration");near(s.range,0,.15,"Constant-tone LRA");assert(s.droppedFrames==0);
    double integrated=s.integrated;jm_pause(h,1);feed(h,1,.9);s=snapshot(h);near(s.seconds,10,.001,"Pause duration");near(s.integrated,integrated,.001,"Pause measurement");jm_pause(h,0);
    feed(h,5,0);s=snapshot(h);near(s.integrated,integrated,.2,"Silence gated integrated loudness");
    jm_reset(h);jm_wait_idle(h);s=snapshot(h);assert(s.active==0&&s.seconds==0&&!std::isfinite(s.integrated));
    feed(h,10,.1,1,false,511);s=snapshot(h);near(s.integrated,-23.01,.15,"Mono integrated");
    jm_reset(h);jm_wait_idle(h);feed(h,10,.1,2,true,97);s=snapshot(h);near(s.integrated,integrated,.02,"Block-size independence");near(s.correlation,-1,.001,"Out-of-phase correlation");
    float bins[64];jm_spectrum(h,bins);double maximum=-100;for(float b:bins)maximum=std::max(maximum,double(b));near(maximum,-20,2,"Anti-phase spectrum does not cancel");
    jm_reset(h);jm_wait_idle(h);feed(h,4,.5,2,false,1024,48000,12000,PI/4);s=snapshot(h);printf("Intersample detection: sample %.3f, true %.3f dB\n",s.samplePeak,s.truePeak);assert(s.truePeak-s.samplePeak>2);assert(s.droppedFrames==0);
    jm_reset(h);jm_wait_idle(h);feed(h,10,.1,2,false,512,44100);s=snapshot(h);near(s.integrated,-20,.15,"44.1 kHz integrated");
    JMHistory history[100];assert(jm_history(h,history,100)>0);assert(jm_write_csv(h,"build/test-log.csv")==1);
    jm_destroy(h);puts("All DSP tests passed.");
}
