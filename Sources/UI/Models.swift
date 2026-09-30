import AppKit
import SwiftUI
import AVFoundation

import UniformTypeIdentifiers

typealias ViewState<Value> = SwiftUI.State<Value>

let accent = Color(red: 0.22, green: 0.73, blue: 0.79)

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case spectrum, loudness, history, stereo, peaks
    var id: String { rawValue }
    var title: String { switch self {case .spectrum: return "频谱";case .loudness:return "响度";case .history:return "响度历史";case .stereo:return "立体声";case .peaks:return "峰值"} }
    var icon: String { switch self {case .spectrum:return "waveform.path";case .loudness:return "chart.bar.xaxis";case .history:return "chart.xyaxis.line";case .stereo:return "circle.lefthalf.filled";case .peaks:return "waveform.path.ecg"} }
    var fields: [String] { switch self {case .spectrum:return ["实时曲线","参考曲线"];case .loudness:return ["整段 I","瞬时 M","短时 S","范围 LRA","最大瞬时"];case .history:return ["短时 S","瞬时 M","整段 I"];case .stereo:return ["向量图","相关度","左右平衡"];case .peaks:return ["True Peak","Sample Peak"]} }
}
struct Widget: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var kind: WidgetKind
    var width = 1
    var height = 1
    var fields: [String]
    init(_ kind: WidgetKind) { self.kind=kind;fields=kind.fields }
}
struct MeterLayout: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var widgets: [Widget]
    static let standard = MeterLayout(id:"default", name:"默认", widgets:[Widget(.spectrum),Widget(.loudness),Widget(.history),Widget(.stereo)])
}
struct Preferences: Codable {
    var theme = "system"
    // Optional so existing layouts, app preferences and VST3 project states still decode.
    var interfaceLanguage: String? = nil
    var language: AppLanguage { AppLanguage(rawValue:interfaceLanguage ?? "") ?? .preferred() }
    // Optional storage keeps pre-0.1.1 preference files readable.
    var interfaceScale: Double? = nil
    var scale: Double { get { interfaceScale ?? 1 } set { interfaceScale = newValue } }
    static let scales: [Double] = [0.5, 0.75, 1, 1.2]
    var transparency = 35.0
    var unit = "LUFS"
    var reference = -16.0
    var target = -16.0
    var peakLimit = -1.0
    var pinned = false
    var followTransport = true
    var layouts: [MeterLayout] = []
    var selected = "default"
    mutating func sanitize() {
        if let value=interfaceLanguage,AppLanguage(rawValue:value)==nil {interfaceLanguage=nil}
        if !Self.scales.contains(scale) { scale = 1 }
        if !["system","light","dark"].contains(theme){theme="system"}
        if !["LUFS","LKFS","LU"].contains(unit){unit="LUFS"}
        transparency=transparency.isFinite ? min(85,max(0,transparency)) : 35
        reference=reference.isFinite ? min(0,max(-60,reference)) : -16
        target=target.isFinite ? min(0,max(-60,target)) : -16
        peakLimit=peakLimit.isFinite ? min(6,max(-60,peakLimit)) : -1
        var used=Set<String>()
        layouts=Array(layouts.filter{$0.id != "default" && used.insert($0.id).inserted}.prefix(64))
        for i in layouts.indices {
            layouts[i].name=String(layouts[i].name.prefix(40))
            layouts[i].widgets=Array(layouts[i].widgets.prefix(64))
            var ids=Set<String>()
            for j in layouts[i].widgets.indices {
                if !ids.insert(layouts[i].widgets[j].id).inserted{layouts[i].widgets[j].id=UUID().uuidString}
                layouts[i].widgets[j].width=min(2,max(1,layouts[i].widgets[j].width));layouts[i].widgets[j].height=min(2,max(1,layouts[i].widgets[j].height))
                let allowed=layouts[i].widgets[j].kind.fields;var fields=Set<String>()
                layouts[i].widgets[j].fields=layouts[i].widgets[j].fields.filter{allowed.contains($0) && fields.insert($0).inserted}
                if layouts[i].widgets[j].fields.isEmpty{layouts[i].widgets[j].fields=[allowed[0]]}
            }
            if layouts[i].widgets.isEmpty {layouts[i].widgets=[Widget(.loudness)]}
        }
        if selected != "default" && !layouts.contains(where:{$0.id==selected}){selected="default"}
    }
}

final class MeterModel: ObservableObject {
    let engine: JMHandle
    let plugin: Bool
    let ownsEngine: Bool
    @Published var preferences: Preferences
    @Published var snapshot = JMSnapshot()
    @Published var spectrum = [Float](repeating:-100,count:64)
    @Published var referenceSpectrum: [Float]? = nil
    @Published var vectors = [Float](repeating:0,count:256)
    @Published var history: [JMHistory] = []
    @Published var settings = false
    @Published var settingsTab = "外观"
    @Published var draft: MeterLayout? = nil
    @Published var source: LocalizedMessage = "选择音频来源，开始测量"
    @Published var running = false
    @Published var paused = false
    @Published var progress: Double? = nil
    @Published var message: LocalizedMessage? = nil
    @Published var showAbout = false
    var editingFromSettings = false
    var languageDidChange: (() -> Void)?
    var language: AppLanguage { preferences.language }
    func text(_ key:String)->String { language.text(key) }
    func layoutName(_ layout:MeterLayout)->String {layout.id == "default" ? text("默认") : layout.name}
    func setLanguage(_ value:AppLanguage) {preferences.interfaceLanguage=value.rawValue;persist();languageDidChange?()}
    weak var window: NSWindow?
    var timer: Timer?
    var audio: AudioSource?
    var stateVersion: UInt64 = 0
    private var observers: [NSObjectProtocol] = []
    var persistenceKey: String { plugin ? "JustMeter.plugin.preferences.v1" : "JustMeter.app.preferences.v1" }
    var allLayouts: [MeterLayout] { [MeterLayout.standard] + preferences.layouts }
    var layout: MeterLayout { draft ?? allLayouts.first(where:{$0.id==preferences.selected}) ?? .standard }
    var colorScheme: ColorScheme? { preferences.theme=="system" ? nil : (preferences.theme=="dark" ? .dark : .light) }
    init(engine: JMHandle? = nil, plugin: Bool = false) {
        self.engine=engine ?? jm_create()!;self.plugin=plugin;ownsEngine=engine==nil
        let key=plugin ? "JustMeter.plugin.preferences.v1" : "JustMeter.app.preferences.v1"
        preferences = UserDefaults.standard.data(forKey:key).flatMap{try? JSONDecoder().decode(Preferences.self,from:$0)} ?? Preferences()
        preferences.sanitize()
        if plugin { source="等待宿主音频";restoreState() }
        else { audio=AudioSource(engine:self.engine,model:self) }
        timer=Timer.scheduledTimer(withTimeInterval:1.0/20,repeats:true) { [weak self] _ in self?.refresh() }
    }
    deinit { timer?.invalidate();audio?.shutdown();if ownsEngine {jm_destroy(engine)} }
    func refresh() {
        if plugin && jm_state_version(engine) != stateVersion {restoreState()}
        var s=JMSnapshot();jm_snapshot(engine,&s);snapshot=s
        jm_spectrum(engine,&spectrum);jm_vectors(engine,&vectors)
        var h=[JMHistory](repeating:JMHistory(),count:720);let n=Int(jm_history(engine,&h,720));history=Array(h.prefix(n))
        if plugin { source=s.active==0 ? "等待宿主音频" : LocalizedMessage("宿主音频 · {0} kHz · {1} 声道",arguments:[String(Int(s.sampleRate/1000)),String(s.channels)]) }
    }
    func persist() {
        preferences.sanitize()
        if let data=try? JSONEncoder().encode(preferences){UserDefaults.standard.set(data,forKey:persistenceKey)}
        if plugin,let data=try? JSONEncoder().encode(preferences) {data.withUnsafeBytes{p in jm_set_state(engine,p.baseAddress?.assumingMemoryBound(to:CChar.self),Int32(p.count))};stateVersion=jm_state_version(engine);jm_set_follow_transport(engine,preferences.followTransport ? 1:0)}
        if !plugin { window?.level=preferences.pinned ? .floating : .normal }
        window?.appearance=preferences.theme=="system" ? nil : NSAppearance(named:preferences.theme=="dark" ? .darkAqua : .aqua)
    }
    func formatted(_ value: Double, loudness: Bool = true) -> String {

        guard value.isFinite else {return "−∞"}
        return String(format:"%.1f",value - (loudness && preferences.unit=="LU" ? preferences.reference : 0)).replacingOccurrences(of:"-",with:"−")
    }
    func restoreState() {
        let n=Int(jm_get_state(engine,nil,0));if n==0{stateVersion=jm_state_version(engine);preferences.followTransport=jm_follow_transport(engine) != 0;return};guard n>0,n<1048576 else{return};var bytes=[CChar](repeating:0,count:n)
        let actual=Int(jm_get_state(engine,&bytes,Int32(n)));guard actual==n else{return}
        let data=bytes.withUnsafeBytes{Data($0)}
        if var p=try? JSONDecoder().decode(Preferences.self,from:data){p.sanitize();preferences=p}
        stateVersion=jm_state_version(engine);jm_set_follow_transport(engine,preferences.followTransport ? 1:0)
    }
    var time: String { let s=max(0,Int(snapshot.seconds));return String(format:"%02d:%02d:%02d",s/3600,s/60%60,s%60) }
    func reset() { jm_reset(engine); referenceSpectrum=nil }
    func togglePause() { paused.toggle();jm_pause(engine,paused ? 1:0) }
    func beginEdit(_ layout: MeterLayout?, fromSettings: Bool) {
        editingFromSettings=fromSettings
        if let l=layout,l.id != "default" { draft=l }
        else { var l=layout ?? .standard;l.id=UUID().uuidString;l.name=language.format("自定义布局 {0}",String(preferences.layouts.count+1));draft=l }
        settings=false
    }
    func finishEdit(save: Bool) {
        if save,var l=draft {
            l.name=String(l.name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(40));if l.name.isEmpty {l.name=text("自定义布局")}
            if let i=preferences.layouts.firstIndex(where:{$0.id==l.id}) {preferences.layouts[i]=l} else {preferences.layouts.append(l)}
            if !editingFromSettings {preferences.selected=l.id};persist()
        }
        draft=nil;settings=editingFromSettings
    }
    func deleteLayout(_ l: MeterLayout) {guard l.id != "default" else{return};preferences.layouts.removeAll{$0.id==l.id};if preferences.selected==l.id{preferences.selected="default"};persist()}
    func moveLayout(_ id: String, _ step: Int) {guard let i=preferences.layouts.firstIndex(where:{$0.id==id}) else{return};let j=i+step;guard preferences.layouts.indices.contains(j)else{return};preferences.layouts.swapAt(i,j);persist()}
    func moveWidget(_ id: String, to target: String) {guard var d=draft,let i=d.widgets.firstIndex(where:{$0.id==id}),let j=d.widgets.firstIndex(where:{$0.id==target}),i != j else{return};let w=d.widgets.remove(at:i);d.widgets.insert(w,at:j);draft=d}
    func modifyWidget(_ id: String,_ action: (inout Widget)->Void){guard var d=draft,let i=d.widgets.firstIndex(where:{$0.id==id})else{return};action(&d.widgets[i]);draft=d}
    func exportCSV() {let p=NSSavePanel();p.title=text("导出 CSV…");p.prompt=text("保存");p.allowedContentTypes=[.commaSeparatedText];p.nameFieldStringValue="Just Meter.csv";p.begin{[weak self] response in if response == .OK,let url=p.url,let self=self{if jm_write_csv(self.engine,url.path)==0{self.message="无法写入日志文件。"}}}}
    func chooseFile() {let p=NSOpenPanel();p.title=text("分析音频文件…");p.allowedContentTypes=[.audio];p.allowsMultipleSelection=false;p.begin{[weak self] response in if response == .OK,let url=p.url{self?.audio?.analyze(url)}}}
}

final class AudioSource: NSObject {
    let engine: JMHandle
    weak var model: MeterModel?
    var input: AVAudioEngine?
    private let control=NSLock()
    private var systemCapture:SystemAudioCapture?
    let queue=DispatchQueue(label:"JustMeter.audio",qos:.userInitiated)
    private var token=0
    private var startedAt=Date()
    private var watchdog:Timer?
    private let diagnosticURL=FileManager.default.temporaryDirectory.appendingPathComponent("JustMeter-capture.log")
    private func diagnostic(_ text:String) {
        let line="\(Date()) \(text)\n"
        if let h=try? FileHandle(forWritingTo:diagnosticURL){defer{try? h.close()};_ = try? h.seekToEnd();try? h.write(contentsOf:Data(line.utf8))}
    }
    var generation:Int{get{control.lock();defer{control.unlock()};return token}set{control.lock();token=newValue;control.unlock()}}
    init(engine:JMHandle,model:MeterModel){self.engine=engine;self.model=model}
    func stop() {
        generation += 1
        watchdog?.invalidate();watchdog=nil
        if let e=input {e.inputNode.removeTap(onBus:0);e.stop()};input=nil
        systemCapture?.stop();systemCapture=nil
        model?.running=false;model?.progress=nil
    }
    func shutdown() {stop();queue.sync{}}
    func prepare() {stop();queue.sync{};model?.paused=false;jm_pause(engine,0);jm_reset(engine);jm_wait_idle(engine)}
    func startInput() {
        AVCaptureDevice.requestAccess(for:.audio){[weak self] allowed in DispatchQueue.main.async{guard let self=self else{return};guard allowed else{self.model?.message="请在系统设置 → 隐私与安全性 → 麦克风中允许 Just Meter 使用音频输入。";return};self.runInput()}}
    }
    private func runInput() {
        prepare();let e=AVAudioEngine();let format=e.inputNode.outputFormat(forBus:0)
        guard format.channelCount>0,format.channelCount<=6,format.sampleRate>0 else{model?.message="当前默认输入设备不可用，或超过 6 声道。";return}
        e.inputNode.installTap(onBus:0,bufferSize:1024,format:format){[engine] buffer,_ in
            guard let ptr=buffer.floatChannelData else{return};let channels=(0..<Int(buffer.format.channelCount)).map{UnsafePointer(ptr[$0]) as UnsafePointer<Float>?};channels.withUnsafeBufferPointer{_ = jm_feed(engine,$0.baseAddress,Int32(channels.count),Int32(buffer.frameLength),buffer.format.sampleRate)}
        }
        do {try e.start();input=e;model?.source=LocalizedMessage("默认音频输入 · {0} kHz",arguments:[String(Int(format.sampleRate/1000))]);model?.running=true} catch {e.inputNode.removeTap(onBus:0);model?.message=LocalizedMessage(error.localizedDescription,verbatim:true)}
    }
    func startSystem() {
        prepare();let ticket=generation
        try? Data().write(to:diagnosticURL)
        diagnostic("start Core Audio system capture; app=\(Bundle.main.bundlePath)")
        startedAt=Date();model?.source="系统音频 · 正在连接…"
        do {
            let capture=SystemAudioCapture(engine:engine,language:model?.language ?? .preferred())
            try capture.start();systemCapture=capture
            model?.source="系统音频 · 等待播放";model?.running=true
            diagnostic("Core Audio tap started; sampleRate=\(capture.snapshot.rate)")
            watchdog=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in self?.checkCapture(ticket)}
        } catch {
            diagnostic("capture error: \(error)");model?.source="系统音频 · 连接失败";model?.running=false;model?.message=LocalizedMessage(error.localizedDescription,verbatim:true)
        }
    }
    private var lastCaptureState=""
    private func checkCapture(_ ticket:Int) {
        guard ticket==generation,let capture=systemCapture else{return}
        let state=capture.snapshot
        let elapsed=Date().timeIntervalSince(startedAt)
        let text:LocalizedMessage
        if state.invalid {text="系统音频 · 输入格式异常，请重新连接"}
        else if state.frames==0 && elapsed>5 {text="系统音频 · 等待数据，请播放音频或检查录制权限"}
        else if Date().timeIntervalSince(state.lastSignal)>3 && elapsed>5 {text="系统音频 · 当前静音，等待播放"}
        else if state.frames>0 {text=LocalizedMessage("系统音频 · {0} kHz · Stereo",arguments:[String(Int(state.rate/1000))])}
        else {text="系统音频 · 等待播放"}
        model?.source=text
        let diagnosticText=text.resolved(in:.english)
        if diagnosticText != lastCaptureState {lastCaptureState=diagnosticText;diagnostic("\(diagnosticText); callbacks=\(state.callbacks), frames=\(state.frames)")}
    }
    func analyze(_ url:URL) {
        prepare();let ticket=generation;let language=model?.language ?? .preferred();model?.source=LocalizedMessage("分析 · {0}",arguments:[url.lastPathComponent]);model?.running=true;model?.progress=0
        queue.async{[weak self] in
            guard let self=self else{return}
            do {
                let file=try AVAudioFile(forReading:url,commonFormat:.pcmFormatFloat32,interleaved:false);let format=file.processingFormat
                guard format.channelCount<=6,let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:1024) else{throw NSError(domain:"JustMeter",code:1,userInfo:[NSLocalizedDescriptionKey:language.text("第一版支持 1–6 声道音频文件。")])}
                var count=0
                while file.framePosition<file.length {
                    if self.generation != ticket {return}
                    while jm_queue_available(self.engine)<2 {if self.generation != ticket{return};Thread.sleep(forTimeInterval:0.002)}
                    // Pause keeps the source position stable while measurement is paused.
                    var state=JMSnapshot();jm_snapshot(self.engine,&state)
                    if state.paused != 0 {Thread.sleep(forTimeInterval:0.02);continue}
                    try file.read(into:buffer,frameCount:1024)
                    guard buffer.frameLength>0,let p=buffer.floatChannelData else{break}
                    let ptr=(0..<Int(format.channelCount)).map{UnsafePointer(p[$0]) as UnsafePointer<Float>?};ptr.withUnsafeBufferPointer{_ = jm_feed(self.engine,$0.baseAddress,Int32(format.channelCount),Int32(buffer.frameLength),format.sampleRate)}
                    count += 1;if count%100==0{let value=Double(file.framePosition)/Double(file.length);DispatchQueue.main.async{[weak self] in if self?.generation==ticket{self?.model?.progress=value}}}
                }
                jm_wait_idle(self.engine)
                DispatchQueue.main.async{[weak self] in guard self?.generation==ticket else{return};self?.model?.running=false;self?.model?.progress=nil;self?.model?.source=LocalizedMessage("{0} · 分析完成",arguments:[url.lastPathComponent])}
            }catch{DispatchQueue.main.async{[weak self] in guard self?.generation==ticket else{return};self?.model?.message=LocalizedMessage(error.localizedDescription,verbatim:true);self?.model?.running=false;self?.model?.progress=nil}}
        }
    }
}
