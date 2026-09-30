#include "public.sdk/source/vst/vstsinglecomponenteffect.h"
#include "public.sdk/source/common/pluginview.h"
#include "public.sdk/source/main/pluginfactory.h"
#include "base/source/fstreamer.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "MeterCore.h"
#include <algorithm>
#include <array>
#include <cstring>
#include <vector>
#include <string>
#include <thread>
#include <chrono>
using namespace Steinberg;
using namespace Steinberg::Vst;
extern "C" {
void* jm_create_editor(void*);
void jm_destroy_editor(void*);
void jm_attach_editor(void*,void*);
void jm_resize_editor(void*,int32,int32);
}
class MeterEditor:public CPluginView {
    JMHandle engine;void* view=nullptr;FUnknown* owner;
public:
    MeterEditor(JMHandle e,FUnknown* o):engine(e),owner(o){owner->addRef();rect=ViewRect(0,0,1000,760);}
    ~MeterEditor() override {if(view)jm_destroy_editor(view);owner->release();}
    tresult PLUGIN_API isPlatformTypeSupported(FIDString type) override {
#if defined(_WIN32)
        return type&&strcmp(type,kPlatformTypeHWND)==0?kResultTrue:kResultFalse;
#else
        return type&&strcmp(type,kPlatformTypeNSView)==0?kResultTrue:kResultFalse;
#endif
    }
    tresult PLUGIN_API attached(void* parent,FIDString type) override {
        if(!parent||isPlatformTypeSupported(type)!=kResultTrue)return kResultFalse;
        if(view)jm_destroy_editor(view);view=jm_create_editor(engine);if(!view)return kResultFalse;jm_attach_editor(view,parent);jm_resize_editor(view,rect.getWidth(),rect.getHeight());return CPluginView::attached(parent,type);
    }
    tresult PLUGIN_API removed() override {if(view){jm_destroy_editor(view);view=nullptr;}return CPluginView::removed();}
    tresult PLUGIN_API canResize() override{return kResultTrue;}
    tresult PLUGIN_API checkSizeConstraint(ViewRect*r) override{if(!r)return kInvalidArgument;r->right=r->left+std::max(780,r->getWidth());r->bottom=r->top+std::max(660,r->getHeight());return kResultTrue;}
    tresult PLUGIN_API onSize(ViewRect*r) override{if(!r)return kInvalidArgument;CPluginView::onSize(r);if(view)jm_resize_editor(view,r->getWidth(),r->getHeight());return kResultTrue;}
};
class JustMeter:public SingleComponentEffect {
    JMHandle engine=jm_create();
    bool bypass=false;
    std::array<float,1024*6> scratch{};
public:
    ~JustMeter() override{jm_destroy(engine);}
    static FUnknown* createInstance(void*){return static_cast<IAudioProcessor*>(new JustMeter);}
    tresult PLUGIN_API initialize(FUnknown*context) override {
        auto r=SingleComponentEffect::initialize(context);if(r!=kResultOk)return r;
        addAudioInput(STR16("Input"),SpeakerArr::kStereo);addAudioOutput(STR16("Output"),SpeakerArr::kStereo);
        parameters.addParameter(STR16("Bypass metering"),nullptr,1,0,ParameterInfo::kCanAutomate|ParameterInfo::kIsBypass,0);
        processContextRequirements.needTransportState();return kResultOk;
    }
    tresult PLUGIN_API setBusArrangements(SpeakerArrangement*in,int32 ni,SpeakerArrangement*out,int32 no) override {
        if(ni!=1||no!=1||!in||!out||in[0]!=out[0])return kResultFalse;
        if(in[0]!=SpeakerArr::kMono&&in[0]!=SpeakerArr::kStereo&&in[0]!=SpeakerArr::k50&&in[0]!=SpeakerArr::k51)return kResultFalse;
        auto*i=static_cast<AudioBus*>(audioInputs.at(0).get());auto*o=static_cast<AudioBus*>(audioOutputs.at(0).get());i->setArrangement(in[0]);o->setArrangement(out[0]);return kResultTrue;
    }
    tresult PLUGIN_API canProcessSampleSize(int32 size) override {return size==kSample32||size==kSample64?kResultTrue:kResultFalse;}
    tresult PLUGIN_API setProcessing(TBool state) override{return kResultOk;}
    tresult PLUGIN_API setupProcessing(ProcessSetup&setup) override {jm_reset(engine);return SingleComponentEffect::setupProcessing(setup);}
    tresult PLUGIN_API process(ProcessData&d) override {
        if(d.inputParameterChanges){for(int32 i=0;i<d.inputParameterChanges->getParameterCount();++i){auto*q=d.inputParameterChanges->getParameterData(i);if(q&&q->getParameterId()==0){int32 offset;ParamValue v;if(q->getPoint(q->getPointCount()-1,offset,v)==kResultTrue)bypass=v>0.5;}}}
        if(d.numInputs<1||d.numOutputs<1||d.numSamples<=0)return kResultOk;
        auto&in=d.inputs[0];auto&out=d.outputs[0];int ch=std::min(in.numChannels,out.numChannels);if(ch<1||ch>6)return kResultOk;
        out.silenceFlags=in.silenceFlags;
        // Metering never changes the signal, including bypass and host stop states.
        for(int c=0;c<out.numChannels;++c){bool silent=c>=ch||(in.silenceFlags&(uint64(1)<<c));
            if(d.symbolicSampleSize==kSample32){auto*p=out.channelBuffers32[c];if(!p)continue;if(silent)std::fill(p,p+d.numSamples,0);else if(p!=in.channelBuffers32[c])std::memcpy(p,in.channelBuffers32[c],d.numSamples*sizeof(float));}
            else{auto*p=out.channelBuffers64[c];if(!p)continue;if(silent)std::fill(p,p+d.numSamples,0);else if(p!=in.channelBuffers64[c])std::memcpy(p,in.channelBuffers64[c],d.numSamples*sizeof(double));}
        }
        bool measure=!bypass&&(!jm_follow_transport(engine)||!d.processContext||(d.processContext->state&ProcessContext::kPlaying));
        if(measure){
            for(int offset=0;offset<d.numSamples;offset+=1024){int n=std::min(1024,d.numSamples-offset);
                if(d.processMode==kOffline){while(jm_queue_available(engine)<2)std::this_thread::sleep_for(std::chrono::milliseconds(1));}
                if(d.symbolicSampleSize==kSample32){const float* p[6];for(int c=0;c<ch;++c)p[c]=(in.silenceFlags&(uint64(1)<<c))?nullptr:in.channelBuffers32[c]+offset;jm_feed(engine,p,ch,n,processSetup.sampleRate);}
                else{for(int i=0;i<n;++i)for(int c=0;c<ch;++c)scratch[i*ch+c]=(in.silenceFlags&(uint64(1)<<c))?0:float(in.channelBuffers64[c][offset+i]);jm_feed_interleaved(engine,scratch.data(),ch,n,processSetup.sampleRate);}
            }
        }return kResultOk;
    }
    IPlugView* PLUGIN_API createView(FIDString name) override {if(name&&strcmp(name,ViewType::kEditor)==0)return new MeterEditor(engine,static_cast<IEditController*>(this));return nullptr;}
    tresult PLUGIN_API getState(IBStream*state) override {if(!state)return kInvalidArgument;IBStreamer s(state,kLittleEndian);int n=jm_get_state(engine,nullptr,0);std::vector<char>b(n);jm_get_state(engine,b.data(),n);if(!s.writeInt32(1)||!s.writeBool(bypass)||!s.writeBool(jm_follow_transport(engine))||!s.writeInt32(n))return kResultFalse;if(n&&s.writeRaw(b.data(),n)!=n)return kResultFalse;return kResultOk;}
    tresult PLUGIN_API setState(IBStream*state) override {if(!state)return kInvalidArgument;IBStreamer s(state,kLittleEndian);int32 version,n;bool follow;if(!s.readInt32(version)||version!=1||!s.readBool(bypass)||!s.readBool(follow)||!s.readInt32(n)||n<0||n>1048576)return kResultFalse;std::vector<char>b(n);if(n&&s.readRaw(b.data(),n)!=n)return kResultFalse;jm_set_state(engine,b.data(),n);jm_set_follow_transport(engine,follow);setParamNormalized(0,bypass?1:0);return kResultOk;}
    tresult PLUGIN_API getEditorState(IBStream*state) override{return getState(state);}
    tresult PLUGIN_API setEditorState(IBStream*state) override{return setState(state);}
};
bool InitModule(){return true;}
bool DeinitModule(){return true;}
BEGIN_FACTORY_DEF("Just Meter","","")
DEF_CLASS2(INLINE_UID(0x4A4D4554,0x45524150,0x504C4553,0x494C4943),PClassInfo::kManyInstances,kVstAudioEffectClass,"Just Meter",0,"Fx|Analyzer","0.1.3",kVstVersionString,JustMeter::createInstance)
END_FACTORY
