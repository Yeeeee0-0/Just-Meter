#include <windows.h>
#include <objbase.h>
#include "pluginterfaces/base/ipluginbase.h"
#include "pluginterfaces/gui/iplugview.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "public.sdk/source/vst/hosting/hostclasses.h"
#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
using namespace Steinberg;using namespace Steinberg::Vst;
template<class T>void process(IAudioProcessor*p,int32 format){
    T l[1024],r[1024],ol[1024],orr[1024];T*in[]={l,r},*out[]={ol,orr};
    ProcessSetup setup{kOffline,format,1024,48000};assert(p->setupProcessing(setup)==kResultOk);p->setProcessing(true);
    AudioBusBuffers a{},b{};a.numChannels=b.numChannels=2;
    if(format==kSample32){a.channelBuffers32=reinterpret_cast<Sample32**>(in);b.channelBuffers32=reinterpret_cast<Sample32**>(out);}else{a.channelBuffers64=reinterpret_cast<Sample64**>(in);b.channelBuffers64=reinterpret_cast<Sample64**>(out);}
    ProcessContext context{};context.state=ProcessContext::kPlaying;context.sampleRate=48000;
    ProcessData data{};data.processMode=kOffline;data.symbolicSampleSize=format;data.numSamples=1024;data.numInputs=data.numOutputs=1;data.inputs=&a;data.outputs=&b;data.processContext=&context;
    for(int block=0;block<256;++block){for(int i=0;i<1024;++i){l[i]=T(.1*sin(6.283185307179586*1000*(block*1024+i)/48000));r[i]=-l[i];}assert(p->process(data)==kResultOk);assert(!memcmp(l,ol,sizeof(l))&&!memcmp(r,orr,sizeof(r)));}
    context.state=0;assert(p->process(data)==kResultOk);assert(!memcmp(l,ol,sizeof(l)));
    p->setProcessing(false);
}
void pump(int milliseconds){ULONGLONG end=GetTickCount64()+milliseconds;while(GetTickCount64()<end){MSG msg;while(PeekMessageW(&msg,nullptr,0,0,PM_REMOVE)){TranslateMessage(&msg);DispatchMessageW(&msg);}Sleep(10);}}
int wmain(int argc,wchar_t**argv){
    assert(argc==2);SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
    HMODULE dll=LoadLibraryW(argv[1]);assert(dll);auto init=reinterpret_cast<bool(*)()>(GetProcAddress(dll,"InitDll"));auto finish=reinterpret_cast<bool(*)()>(GetProcAddress(dll,"ExitDll"));assert(init&&finish&&init());
    auto factoryFn=reinterpret_cast<IPluginFactory*(*)()>(GetProcAddress(dll,"GetPluginFactory"));assert(factoryFn);auto*f=factoryFn();PClassInfo info{};assert(f->getClassInfo(0,&info)==kResultOk);
    IComponent*c=nullptr;assert(f->createInstance(info.cid,IComponent::iid,reinterpret_cast<void**>(&c))==kResultOk);f->release();HostApplication host;assert(c->initialize(&host)==kResultOk);
    IAudioProcessor*p=nullptr;IEditController*control=nullptr;assert(c->queryInterface(IAudioProcessor::iid,reinterpret_cast<void**>(&p))==kResultOk);assert(c->queryInterface(IEditController::iid,reinterpret_cast<void**>(&control))==kResultOk);
    for(auto arrangement:{SpeakerArr::kMono,SpeakerArr::kStereo,SpeakerArr::k50,SpeakerArr::k51}){assert(p->setBusArrangements(&arrangement,1,&arrangement,1)==kResultOk);}
    auto stereo=SpeakerArr::kStereo;assert(p->setBusArrangements(&stereo,1,&stereo,1)==kResultOk);c->setActive(true);process<float>(p,kSample32);process<double>(p,kSample64);
    HWND window=CreateWindowExW(0,L"STATIC",L"Just Meter VST3 integration",WS_OVERLAPPEDWINDOW|WS_VISIBLE,0,0,1060,840,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);assert(window);
    for(int reopen=0;reopen<2;++reopen){auto*view=control->createView(ViewType::kEditor);assert(view&&view->isPlatformTypeSupported(kPlatformTypeHWND)==kResultTrue);assert(view->attached(window,kPlatformTypeHWND)==kResultTrue);ViewRect size(0,0,1000,760);assert(view->onSize(&size)==kResultTrue);pump(3500);assert(FindWindowExW(window,nullptr,L"JustMeter.Editor.Window",nullptr));view->removed();view->release();assert(!FindWindowExW(window,nullptr,L"JustMeter.Editor.Window",nullptr));}
    DestroyWindow(window);c->setActive(false);p->release();control->release();c->terminate();c->release();assert(finish());FreeLibrary(dll);CoUninitialize();
    std::cout<<"PASS: DLL load, channel layouts, bit-identical float32/64, stopped transport, HWND editor resize/reopen/release\n";
}
