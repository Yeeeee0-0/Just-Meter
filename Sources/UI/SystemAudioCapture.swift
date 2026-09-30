import Foundation
import CoreAudio

/// Audio-only system capture. No display selection or screen-recording session.
final class SystemAudioCapture {
    struct Status {var callbacks=0;var frames=0;var rate=0.0;var lastSignal=Date.distantPast;var invalid=false}
    private let engine:JMHandle
    private let language:AppLanguage
    private let queue=DispatchQueue(label:"JustMeter.system-audio",qos:.userInteractive)
    private var tap:AudioObjectID=0
    private var device:AudioObjectID=0
    private var io:AudioDeviceIOProcID?
    private var format=AudioStreamBasicDescription()
    private var status=Status()
    var snapshot:Status {queue.sync{status}}
    init(engine:JMHandle,language:AppLanguage){self.engine=engine;self.language=language}
    deinit{stop()}
    private func check(_ result:OSStatus,_ action:String)throws {
        guard result==noErr else{throw NSError(domain:"JustMeter.CoreAudio",code:Int(result),userInfo:[NSLocalizedDescriptionKey:language.format("{0}失败（{1}）。请确认系统设置 → 隐私与安全性 → 屏幕与系统音频录制中允许 Just Meter 录制系统音频，然后重新连接。",language.text(action),String(result))])}
    }
    func start()throws {
        do {
            let description=CATapDescription(stereoGlobalTapButExcludeProcesses:[])
            description.name="Just Meter System Audio"
            description.isPrivate=true
            description.muteBehavior = .unmuted
            try check(AudioHardwareCreateProcessTap(description,&tap),"创建系统音频捕获")
            var address=AudioObjectPropertyAddress(mSelector:kAudioTapPropertyFormat,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
            var size=UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try check(AudioObjectGetPropertyData(tap,&address,0,nil,&size,&format),"读取系统音频格式")
            guard format.mFormatID==kAudioFormatLinearPCM,format.mFormatFlags & kAudioFormatFlagIsFloat != 0,format.mBitsPerChannel==32,format.mChannelsPerFrame==2,format.mSampleRate>=8000 else{
                throw NSError(domain:"JustMeter.CoreAudio",code:1,userInfo:[NSLocalizedDescriptionKey:language.text("系统返回了不支持的音频格式。请重新选择系统输出设备后连接。")])
            }
            status.rate=format.mSampleRate
            let aggregate:[String:Any]=[
                kAudioAggregateDeviceNameKey:"Just Meter Audio Capture",
                kAudioAggregateDeviceUIDKey:UUID().uuidString,
                kAudioAggregateDeviceIsPrivateKey:true,
                kAudioAggregateDeviceTapAutoStartKey:true,
                kAudioAggregateDeviceTapListKey:[[kAudioSubTapUIDKey:description.uuid.uuidString,kAudioSubTapDriftCompensationKey:true]]
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary,&device),"连接系统音频")
            try check(AudioDeviceCreateIOProcIDWithBlock(&io,device,queue){[weak self] _,input,_,_,_ in self?.consume(input)},"注册系统音频输入")
            try check(AudioDeviceStart(device,io),"启动系统音频")
        }catch{stop();throw error}
    }
    func stop(){
        if device != 0,let io=io {AudioDeviceStop(device,io);AudioDeviceDestroyIOProcID(device,io)}
        io=nil
        // AudioDeviceStop/Destroy synchronize IO; draining prevents engine use after release.
        queue.sync{}
        if device != 0{AudioHardwareDestroyAggregateDevice(device);device=0}
        if tap != 0{AudioHardwareDestroyProcessTap(tap);tap=0}
    }
    private func consume(_ input:UnsafePointer<AudioBufferList>){
        status.callbacks += 1
        let buffers=UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating:input))
        guard !buffers.isEmpty else{return}
        let planar=format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let expected=planar ? 2:1
        guard buffers.count==expected else{status.invalid=true;return}
        let channels=planar ? 1:2
        guard buffers.allSatisfy({$0.mNumberChannels==channels && $0.mData != nil && $0.mDataByteSize>0}) else{return}
        let n=Int(buffers.map{Int($0.mDataByteSize)/MemoryLayout<Float>.size/channels}.min() ?? 0)
        guard n>0 else{return}
        var peak:Float=0
        for b in buffers {let p=b.mData!.assumingMemoryBound(to:Float.self);for i in 0..<(n*channels){peak=max(peak,abs(p[i]))}}
        if peak>0.000001{status.lastSignal=Date()}
        let fed:Int32
        if planar {
            let p=buffers.map{Optional(UnsafePointer($0.mData!.assumingMemoryBound(to:Float.self)))}
            fed=p.withUnsafeBufferPointer{jm_feed(engine,$0.baseAddress,2,Int32(n),format.mSampleRate)}
        } else {fed=jm_feed_interleaved(engine,buffers[0].mData!.assumingMemoryBound(to:Float.self),2,Int32(n),format.mSampleRate)}
        status.frames += Int(fed)
    }
}
