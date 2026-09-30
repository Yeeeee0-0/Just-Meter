import AppKit
import AVFoundation
final class PlaybackDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    var player:AVAudioPlayer?
    let status=NSTextField(labelWithString:"通过默认输出播放校准音频，验证 Just Meter 的系统音频输入。")
    func applicationDidFinishLaunching(_ n:Notification){
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:520,height:150),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title="Just Meter · 系统音频测试源"
        status.frame=NSRect(x:20,y:90,width:490,height:30);window.contentView?.addSubview(status)
        let button=NSButton(title:"播放校准音频 · 30 秒",target:self,action:#selector(play));button.frame=NSRect(x:20,y:30,width:230,height:36);window.contentView?.addSubview(button)
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func play(){do{
        player=try AVAudioPlayer(contentsOf:Bundle.main.url(forResource:"reference",withExtension:"wav")!)
        player?.numberOfLoops=2;player?.volume=0.2
        let started=player?.play() ?? false
        status.stringValue=started ? "正在播放 1 kHz 校准音频（音量 20%）":"播放失败"
    }catch{status.stringValue=error.localizedDescription}}
    func applicationShouldTerminateAfterLastWindowClosed(_ app:NSApplication)->Bool{true}
}
let app=NSApplication.shared;let delegate=PlaybackDelegate();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
