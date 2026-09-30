#import <Cocoa/Cocoa.h>
#include "pluginterfaces/base/ipluginbase.h"
#include "pluginterfaces/gui/iplugview.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "public.sdk/source/vst/hosting/hostclasses.h"
#include <vector>
#include <cmath>
#include <fstream>
using namespace Steinberg;using namespace Steinberg::Vst;
static IComponent* component=nullptr;
static IAudioProcessor* processor=nullptr;
static IEditController* controller=nullptr;
static IPlugView* editor=nullptr;
static CFBundleRef pluginBundle=nullptr;
static HostApplication host;
static NSWindow* meterWindow;
static NSTimer* timer;
static uint64_t frame=0;
static std::string root;
static void report(const char*message){std::ofstream f(root+"/build/plugin-host-test.log",std::ios::app);f<<message<<std::endl;}
@interface TestDelegate:NSObject<NSApplicationDelegate,NSWindowDelegate>
@end
@implementation TestDelegate
-(void)applicationDidFinishLaunching:(NSNotification*)notification {
    root=[[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent].UTF8String;
    std::ofstream(root+"/build/plugin-host-test.log")<<"Native VST3 integration test\n";
    NSString* path=[NSString stringWithUTF8String:(root+"/outputs/Just Meter.vst3").c_str()];
    pluginBundle=CFBundleCreate(nullptr,(__bridge CFURLRef)[NSURL fileURLWithPath:path]);
    if(!pluginBundle||!CFBundleLoadExecutable(pluginBundle)){report("FAIL: load bundle");return;}
    auto entry=(bool(*)(CFBundleRef))CFBundleGetFunctionPointerForName(pluginBundle,CFSTR("bundleEntry"));entry(pluginBundle);
    auto factoryFn=(IPluginFactory*(*)())CFBundleGetFunctionPointerForName(pluginBundle,CFSTR("GetPluginFactory"));
    IPluginFactory*factory=factoryFn();PClassInfo info;factory->getClassInfo(0,&info);factory->createInstance(info.cid,IComponent::iid,(void**)&component);factory->release();
    if(!component||component->initialize(&host)!=kResultOk){report("FAIL: component initialize");return;}
    component->queryInterface(IAudioProcessor::iid,(void**)&processor);component->queryInterface(IEditController::iid,(void**)&controller);
    SpeakerArrangement arrange=SpeakerArr::kStereo;processor->setBusArrangements(&arrange,1,&arrange,1);
    ProcessSetup setup{kRealtime,kSample32,1024,48000};processor->setupProcessing(setup);component->setActive(true);processor->setProcessing(true);
    editor=controller->createView(ViewType::kEditor);
    if(!editor){report("FAIL: create editor");return;}
    meterWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1000,760) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    meterWindow.title=@"Just Meter · VST3 验证 · 1 kHz / −20 dBFS";meterWindow.delegate=self;
    if(editor->attached((__bridge void*)meterWindow.contentView,kPlatformTypeNSView)!=kResultTrue){report("FAIL: attach NSView");return;}
    ViewRect size(0,0,1000,760);editor->onSize(&size);[meterWindow center];[meterWindow makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    report("PASS: bundle, component, controller, native editor attached");
    timer=[NSTimer scheduledTimerWithTimeInterval:1024.0/48000 repeats:YES block:^(NSTimer*){
        float l[1024],r[1024],ol[1024],orr[1024];for(int i=0;i<1024;++i)l[i]=r[i]=.1*sin(2*M_PI*1000*(frame+i)/48000);
        float*in[2]={l,r};float*out[2]={ol,orr};AudioBusBuffers input,output;input.numChannels=output.numChannels=2;input.channelBuffers32=in;output.channelBuffers32=out;
        ProcessContext context{};context.state=ProcessContext::kPlaying;context.sampleRate=48000;
        ProcessData data{};data.processMode=kRealtime;data.symbolicSampleSize=kSample32;data.numSamples=1024;data.numInputs=data.numOutputs=1;data.inputs=&input;data.outputs=&output;data.processContext=&context;
        processor->process(data);
        if(memcmp(l,ol,sizeof l)||memcmp(r,orr,sizeof r)){report("FAIL: pass-through changed audio");[timer invalidate];}
        frame+=1024;
        if(frame>=480000){[timer invalidate];report("PASS: 480256 frames of float32 audio passed through bit-identically");}
    }];
}
-(void)windowDidResize:(NSNotification*)n {if(editor){NSSize s=meterWindow.contentView.bounds.size;ViewRect r(0,0,s.width,s.height);editor->onSize(&r);}}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender{return YES;}
-(void)applicationWillTerminate:(NSNotification*)n {
    [timer invalidate];if(editor){editor->removed();editor->release();}if(processor){processor->setProcessing(false);processor->release();}if(controller)controller->release();if(component){component->setActive(false);component->terminate();component->release();}
    report("PASS: editor and component released");
}
@end
int main(){@autoreleasepool{NSApplication*app=NSApplication.sharedApplication;TestDelegate*d=[TestDelegate new];app.delegate=d;[app setActivationPolicy:NSApplicationActivationPolicyRegular];[app run];}return 0;}
