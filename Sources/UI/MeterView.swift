import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Backdrop: NSViewRepresentable {
    var transparency: Double
    func makeNSView(context:Context)->NSVisualEffectView {let v=NSVisualEffectView();v.material = .underWindowBackground;v.blendingMode = .behindWindow;v.state = .active;return v}
    func updateNSView(_ v:NSVisualEffectView,context:Context) {v.alphaValue = transparency==0 ? 0 : 1}
}
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var scheme
    @Environment(\.accessibilityReduceTransparency) var reduce
    var transparency:Double
    var radius:CGFloat=22
    func body(content:Content)->some View {
        if reduce {
            content.background(scheme == .dark ? Color(white:0.14) : Color(white:0.97),in:RoundedRectangle(cornerRadius:radius))
        } else {
            content
                .background((scheme == .dark ? Color(white:0.09) : Color.white).opacity(0.55 * (1-transparency/85)),in:RoundedRectangle(cornerRadius:radius))
                .glassEffect(.regular,in:RoundedRectangle(cornerRadius:radius))
        }
    }
}
struct MeterRoot: View {
    @ObservedObject var model:MeterModel
    var body:some View {
        GeometryReader { geo in
            let scale=CGFloat(model.preferences.scale)
            MeterContent(model:model)
                .environment(\.locale,Locale(identifier:model.language.rawValue))
                .frame(width:geo.size.width/scale,height:geo.size.height/scale)
                .scaleEffect(scale,anchor:.topLeading)
                .frame(width:geo.size.width,height:geo.size.height,alignment:.topLeading)
        }
    }
}
struct MeterContent: View {
    @ObservedObject var model:MeterModel
    @Environment(\.colorScheme) var scheme
    @Environment(\.accessibilityReduceTransparency) var reduce
    @ViewState var layoutPopover=false
    @ViewState var dragging:String?
    var body: some View {
        VStack(spacing:0) {
            header
            if model.settings { SettingsView(model:model) }
            else {
                if model.draft != nil {editBar}
                GeometryReader { geo in
                    let items=model.layout.widgets
                    let packed=pack(items)
                    let rows=packed.map{$0.row+$0.widget.height}.max() ?? 2
                    let unitHeight=max(210,(geo.size.height-14)/2)
                    ScrollView {
                        ZStack(alignment:.topLeading) {
                            ForEach(packed) {item in
                                let w=(geo.size.width-14)/2
                                WidgetView(model:model,widget:item.widget)
                                    .frame(width:w*CGFloat(item.widget.width)+14*CGFloat(item.widget.width-1),height:unitHeight*CGFloat(item.widget.height)+14*CGFloat(item.widget.height-1))
                                    .offset(x:CGFloat(item.column)*(w+14),y:CGFloat(item.row)*(unitHeight+14))
                                    .onDrag {guard model.draft != nil else{return NSItemProvider()};dragging=item.id;return NSItemProvider(object:item.id as NSString)}
                                    .onDrop(of:[.text],isTargeted:nil){providers in guard let id=dragging,model.draft != nil else{return false};withAnimation(.easeInOut(duration:0.18)){model.moveWidget(id,to:item.id)};dragging=nil;return true}
                            }
                        }.frame(width:geo.size.width,height:CGFloat(rows)*unitHeight+CGFloat(max(0,rows-1))*14,alignment:.topLeading)
                    }.scrollIndicators(.hidden)
                }.padding(.horizontal,18)
            }
            footer
        }
        .background {
            ZStack {
                Backdrop(transparency:reduce ? 0 : model.preferences.transparency)
                (scheme == .dark ? Color(red:0.075,green:0.088,blue:0.1) : Color(red:0.92,green:0.94,blue:0.95)).opacity(reduce ? 1 : 1-model.preferences.transparency/100)
            }
        }
        .tint(accent)
        .preferredColorScheme(model.colorScheme)
        .onChange(of:model.preferences.interfaceScale){_,_ in model.persist()}
        .onChange(of:model.preferences.theme){_,_ in model.persist()}
        .onChange(of:model.preferences.transparency){_,_ in model.persist()}
        .onChange(of:model.preferences.unit){_,_ in model.persist()}
        .onChange(of:model.preferences.reference){_,_ in model.persist()}
        .onChange(of:model.preferences.target){_,_ in model.persist()}
        .onChange(of:model.preferences.peakLimit){_,_ in model.persist()}
        .onChange(of:model.preferences.followTransport){_,_ in model.persist()}
        .sheet(isPresented:$model.showAbout){AboutView(model:model)}
        .alert("Just Meter",isPresented:Binding(get:{model.message != nil},set:{if !$0{model.message=nil}})){Button(model.text("好")){model.message=nil}} message:{Text(model.message?.resolved(in:model.language) ?? "")}
    }
    var header:some View {
        HStack(spacing:10) {
            Image(systemName:"waveform.path").font(.system(size:20,weight:.medium)).foregroundStyle(accent)
            Text("Just Meter").font(.system(size:17,weight:.semibold,design:.rounded)).tracking(-0.4)
            Spacer()
            if !model.settings && model.draft==nil {
                Button {layoutPopover.toggle()} label:{HStack(spacing:9){Text(model.layoutName(model.layout)).lineLimit(1);Image(systemName:"chevron.down").font(.system(size:9,weight:.semibold))}.frame(maxWidth:150)}.buttonStyle(.glass).fixedSize()
                    .popover(isPresented:$layoutPopover,arrowEdge:.bottom){
                        VStack(alignment:.leading,spacing:6){
                            Text(model.text("布局")).font(.caption).foregroundStyle(.secondary).padding(.horizontal,8)
                            ForEach(model.allLayouts){l in Button{model.preferences.selected=l.id;model.persist();layoutPopover=false}label:{HStack{Text(model.layoutName(l));Spacer();if l.id==model.preferences.selected{Image(systemName:"checkmark")}}}.buttonStyle(.plain).padding(8)}
                            Divider()
                            Button(model.text("新建布局…")){layoutPopover=false;model.beginEdit(nil,fromSettings:false)}.buttonStyle(.plain).padding(8)
                            Button(model.text(model.layout.id=="default" ? "复制默认并编辑…" : "编辑当前布局…")){layoutPopover=false;model.beginEdit(model.layout,fromSettings:false)}.buttonStyle(.plain).padding(8)
                        }.padding(12).frame(width:220).glassEffect(.regular,in:RoundedRectangle(cornerRadius:18))
                    }
            }
            if !model.plugin {
                Button{model.preferences.pinned.toggle();model.persist()}label:{Image(systemName:model.preferences.pinned ? "pin.fill" : "pin").frame(width:18,height:18)}.buttonStyle(.glass).help(model.text(model.preferences.pinned ? "取消置顶" : "窗口始终置顶")).accessibilityLabel(model.text(model.preferences.pinned ? "已置顶" : "窗口置顶"))
            }
            Button{withAnimation(.easeInOut(duration:0.18)){model.settings.toggle()}}label:{Image(systemName:model.settings ? "xmark" : "gearshape").frame(width:18,height:18)}.buttonStyle(.glass).disabled(model.draft != nil).help(model.text(model.settings ? "返回仪表" : "设置")).accessibilityLabel(model.text(model.settings ? "返回仪表" : "设置"))
        }.tint(.primary).padding(.horizontal,16).padding(.vertical,12)
            .modifier(GlassCard(transparency:model.preferences.transparency,radius:18))
            .padding(.horizontal,18).padding(.top,10).padding(.bottom,14)
    }
    var editBar:some View {
        HStack {
            Image(systemName:"square.grid.2x2").foregroundStyle(accent)
            TextField(model.text("布局名称"),text:Binding(get:{model.draft?.name ?? ""},set:{model.draft?.name=$0})).textFieldStyle(.roundedBorder).frame(maxWidth:200)
            Text(model.text("拖动组件换位")).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu(model.text("添加组件"),systemImage:"plus"){ForEach(WidgetKind.allCases){kind in Button(model.text(kind.title)){model.draft?.widgets.append(Widget(kind))}}}.menuStyle(.borderlessButton).fixedSize()
            Button(model.text("取消")){model.finishEdit(save:false)}.buttonStyle(.glass)
            Button(model.text("保存布局")){model.finishEdit(save:true)}.buttonStyle(.glassProminent)
        }.padding(12).glassEffect(.regular,in:RoundedRectangle(cornerRadius:16)).padding(.horizontal,18).padding(.bottom,12)
    }
    var footer:some View {
        HStack(spacing:10) {
            if !model.plugin {
                Menu {Button(model.text("导入音频文件…"),systemImage:"doc.badge.plus"){model.chooseFile()};Button(model.text("系统音频"),systemImage:"speaker.wave.2"){model.audio?.startSystem()};Button(model.text("默认音频输入"),systemImage:"mic"){model.audio?.startInput()};if model.running{Divider();Button(model.text("断开音频来源")){model.audio?.stop();model.source="音频来源已断开"}}}label:{Image(systemName:"waveform.badge.mic").font(.system(size:15))}.menuStyle(.borderlessButton).frame(width:25).help(model.text("选择音频来源"))
            }
            Circle().fill(model.running || (model.plugin && model.snapshot.active != 0) ? accent : Color.secondary.opacity(0.5)).frame(width:5,height:5)
            Text(model.source.resolved(in:model.language)).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1)
            if let p=model.progress{ProgressView(value:p).frame(width:60)}
            if model.snapshot.droppedFrames>0 {Image(systemName:"exclamationmark.triangle.fill").foregroundStyle(.orange).help(model.text("音频队列发生丢帧，请重置后重新测量。"))}
            Spacer(minLength:0)
            Text(model.time).monospacedDigit().font(.system(size:11)).foregroundStyle(.secondary)
            Button{model.togglePause()}label:{Image(systemName:model.paused ? "play.fill" : "pause.fill")}.buttonStyle(.plain).frame(width:25).help(model.text(model.paused ? "继续测量" : "暂停测量")).accessibilityLabel(model.text(model.paused ? "继续测量" : "暂停测量"))
            Button{model.reset()}label:{Image(systemName:"arrow.counterclockwise")}.buttonStyle(.plain).frame(width:25).help(model.text("重置测量")).accessibilityLabel(model.text("重置测量"))
        }.padding(.horizontal,24).frame(height:48)
    }
}

struct PackedWidget:Identifiable {var widget:Widget;var row:Int;var column:Int;var id:String{widget.id}}
func pack(_ widgets:[Widget])->[PackedWidget] {
    var occupied=Set<Int>();var result:[PackedWidget]=[]
    for w in widgets {
        var cell=0
        while true {
            let row=cell/2,col=cell%2
            if col+w.width<=2 {
                let cells=(0..<w.height).flatMap{dy in (0..<w.width).map{dx in (row+dy)*2+col+dx}}
                if cells.allSatisfy({!occupied.contains($0)}) {occupied.formUnion(cells);result.append(PackedWidget(widget:w,row:row,column:col));break}
            };cell += 1
        }
    };return result
}

struct WidgetView:View {
    @ObservedObject var model:MeterModel
    var widget:Widget
    @ViewState var config=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:7) {
                if model.draft != nil {Image(systemName:"line.3.horizontal").foregroundStyle(.secondary)}
                Text(model.text(widget.kind.title)).font(.system(size:13,weight:.semibold))
                Spacer()
                if model.draft != nil {Button("\(widget.width) × \(widget.height)"){config.toggle()}.buttonStyle(.glass).controlSize(.small).popover(isPresented:$config){WidgetConfig(model:model,widget:widget)}}
                else {Text(subtitle).font(.system(size:10,weight:.medium)).foregroundStyle(.tertiary)}
            }
            switch widget.kind {
            case .spectrum:
                SpectrumPlot(language:model.language,values:widget.fields.contains("实时曲线") ? model.spectrum : [],reference:widget.fields.contains("参考曲线") ? model.referenceSpectrum : nil)
                FrequencyAxis()
                if widget.fields.contains("参考曲线") {HStack {Button(model.text(model.referenceSpectrum==nil ? "捕获参考" : "更新参考")){model.referenceSpectrum=model.spectrum};if model.referenceSpectrum != nil{Button(model.text("清除")){model.referenceSpectrum=nil}};Spacer();Text("FFT 2048 · Hann")}.buttonStyle(.plain).font(.system(size:10)).foregroundStyle(.secondary)}
            case .loudness: LoudnessReadout(model:model,fields:widget.fields)
            case .history: HistoryPlot(model:model,fields:widget.fields)
                ViewThatFits(in:.horizontal) {historyLegend(compact:false);historyLegend(compact:true)}
            case .stereo:
                if widget.fields.contains("向量图"){VectorPlot(language:model.language,values:model.vectors)}
                if widget.fields.contains("相关度"){HStack {Text(model.text("相关度"));Spacer();Text(model.snapshot.active==0 ? "—" : String(format:"%+.2f",model.snapshot.correlation)).monospacedDigit()}.font(.system(size:11));BalanceBar(value:model.snapshot.correlation,correlation:true)}
                if widget.fields.contains("左右平衡"){HStack{Text("L");BalanceBar(value:model.snapshot.balance,correlation:false);Text("R")}.font(.system(size:9)).foregroundStyle(.secondary)}
            case .peaks:
                ForEach(widget.fields,id:\.self){f in VStack(alignment:.leading,spacing:8){Text(model.text(f)).font(.caption).foregroundStyle(.secondary);HStack(alignment:.firstTextBaseline){Text(model.formatted(f=="True Peak" ? model.snapshot.truePeak : model.snapshot.samplePeak,loudness:false)).font(.system(size:46,weight:.light,design:.rounded)).monospacedDigit();Text(f=="True Peak" ? "dBTP" : "dBFS").foregroundStyle(.secondary)}}}
                Spacer(minLength:0);Button(model.text("清除峰值保持")){jm_clear_peak(model.engine)}.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(18).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            .modifier(GlassCard(transparency:model.preferences.transparency))
    }
    var subtitle:String {switch widget.kind{case .spectrum:return "SPECTRUM";case .loudness:return "EBU R128 · ITU-K";case .history:return "LOUDNESS HISTORY";case .stereo:return "STEREO FIELD";case .peaks:return "PEAK LEVEL"}}
    func historyLegend(compact:Bool)->some View {
        HStack(spacing:10) {
            ForEach(widget.fields,id:\.self){field in
                HStack(spacing:4){
                    Circle().fill(historyColor(field)).frame(width:4,height:4)
                    Text(compact ? String(field.suffix(1)) : model.text(field))
                }.fixedSize().help(model.text(field)).accessibilityLabel(model.text(field))
            }
            Spacer(minLength:0)
            Text(model.history.isEmpty ? model.text("等待音频") : "\(Int(model.history.first?.time ?? 0))–\(Int(model.snapshot.seconds)) s").fixedSize()
        }.font(.system(size:10)).foregroundStyle(.secondary)
    }
}

struct LoudnessReadout:View {
    @ObservedObject var model:MeterModel
    var fields:[String]
    func value(_ field:String)->Double{switch field{case "整段 I":return model.snapshot.integrated;case "瞬时 M":return model.snapshot.momentary;case "短时 S":return model.snapshot.shortTerm;case "范围 LRA":return model.snapshot.range;default:return model.snapshot.maxMomentary}}
    var body:some View {
        GeometryReader {geo in
            let gap=max(4,min(12,geo.size.height*0.03))
            VStack(alignment:.leading,spacing:gap){
                if let first=fields.first {
                    VStack(alignment:.leading,spacing:1){Text(model.text(first)).font(.system(size:min(11,geo.size.height*0.05))).foregroundStyle(.secondary);HStack(alignment:.firstTextBaseline,spacing:8){Text(model.formatted(value(first),loudness:first != "范围 LRA")).font(.system(size:min(64,geo.size.height*0.22),weight:.light,design:.rounded)).tracking(-2).monospacedDigit().contentTransition(.numericText());Text(first=="范围 LRA" ? "LU" : model.preferences.unit).font(.system(size:12)).foregroundStyle(.secondary)}}
                }
                LazyVGrid(columns:[GridItem(.flexible(),alignment:.leading),GridItem(.flexible(),alignment:.leading)],alignment:.leading,spacing:gap) {
                    ForEach(Array(fields.dropFirst()),id:\.self){f in HStack(alignment:.firstTextBaseline){VStack(alignment:.leading,spacing:2){Text(model.text(f)).font(.system(size:min(10,geo.size.height*0.045))).foregroundStyle(.secondary);Text(model.formatted(value(f),loudness:f != "范围 LRA")).font(.system(size:min(23,geo.size.height*0.09),weight:.regular,design:.rounded)).monospacedDigit()};Spacer();Text(f=="范围 LRA" ? "LU" : model.preferences.unit).font(.system(size:9)).foregroundStyle(.tertiary)}}
                }
                Spacer(minLength:0)
                Divider().opacity(0.55)
                HStack {Text("True Peak");Text(model.formatted(model.snapshot.truePeak,loudness:false)).monospacedDigit().foregroundStyle(model.snapshot.truePeak>model.preferences.peakLimit ? .orange : .primary);Text("dBTP").foregroundStyle(.tertiary);Spacer();Button{jm_clear_peak(model.engine)}label:{Image(systemName:"arrow.counterclockwise")}.buttonStyle(.plain).help(model.text("清除峰值保持"))}.font(.system(size:min(11,geo.size.height*0.05))).foregroundStyle(.secondary)
            }
        }
    }
}

struct SpectrumPlot:View {
    var language:AppLanguage
    var values:[Float];var reference:[Float]?
    var body:some View {Canvas{context,size in
        for i in 0...4 {let y=CGFloat(i)*size.height/4;var p=Path();p.move(to:CGPoint(x:0,y:y));p.addLine(to:CGPoint(x:size.width,y:y));context.stroke(p,with:.color(.secondary.opacity(0.10)),lineWidth:1);context.draw(Text("\(-i*25)").font(.system(size:9)).foregroundColor(.secondary.opacity(0.5)),at:CGPoint(x:size.width-12,y:min(size.height-5,y+8)))}
        func line(_ bins:[Float])->Path {var p=Path();for (i,v) in bins.enumerated(){let pt=CGPoint(x:CGFloat(i)*size.width/63,y:(1-CGFloat(max(-100,min(0,v))+100)/100)*size.height);if i==0{p.move(to:pt)}else{p.addLine(to:pt)}};return p}
        if let r=reference{context.stroke(line(r),with:.color(.secondary.opacity(0.55)),style:StrokeStyle(lineWidth:1,dash:[4,4]))}
        if !values.isEmpty {let p=line(values);var fill=p;fill.addLine(to:CGPoint(x:size.width,y:size.height));fill.addLine(to:CGPoint(x:0,y:size.height));fill.closeSubpath();context.fill(fill,with:.linearGradient(Gradient(colors:[accent.opacity(0.35),accent.opacity(0.015)]),startPoint:.zero,endPoint:CGPoint(x:0,y:size.height)));context.stroke(p,with:.color(accent),style:StrokeStyle(lineWidth:1.8,lineCap:.round,lineJoin:.round))}
    }.accessibilityLabel(language.text("实时频谱，20 Hz 至 20 kHz"))}
}
struct FrequencyAxis:View {
    var body:some View {GeometryReader{geo in
        ForEach([20,100,1000,10000,20000],id:\.self){f in
            Text(f==20 ? "20 Hz" : (f>=1000 ? "\(f/1000)k" : "\(f)")).font(.system(size:9)).foregroundStyle(.tertiary)
                .position(x:min(geo.size.width-10,max(13,CGFloat(log(Double(f)/20)/log(1000))*geo.size.width)),y:6)
        }
    }.frame(height:12)}
}
func historyColor(_ f:String)->Color { f=="短时 S" ? accent : (f=="瞬时 M" ? Color.secondary.opacity(0.5) : Color(red:0.63,green:0.58,blue:0.84)) }
struct HistoryPlot:View {
    @ObservedObject var model:MeterModel;var fields:[String]
    var body:some View {Canvas{context,size in
        let left:CGFloat=28;let width=size.width-left
        func y(_ v:Double)->CGFloat{CGFloat(1-(max(-60,min(0,v))+60)/60)*size.height}
        for level in stride(from:0,through:-60,by:-15){let yy=y(Double(level));var p=Path();p.move(to:CGPoint(x:left,y:yy));p.addLine(to:CGPoint(x:size.width,y:yy));context.stroke(p,with:.color(.secondary.opacity(0.1)),lineWidth:1);context.draw(Text(model.formatted(Double(level))).font(.system(size:8)).foregroundColor(.secondary.opacity(0.6)),at:CGPoint(x:11,y:min(size.height-5,yy+5)))}
        var target=Path();target.move(to:CGPoint(x:left,y:y(model.preferences.target)));target.addLine(to:CGPoint(x:size.width,y:y(model.preferences.target)));context.stroke(target,with:.color(accent.opacity(0.25)),style:StrokeStyle(lineWidth:1,dash:[3,5]))
        for f in fields {var p=Path();var started=false;for (i,h) in model.history.enumerated(){let v=f=="短时 S" ? h.shortTerm : (f=="瞬时 M" ? h.momentary : h.integrated);guard v.isFinite else{started=false;continue};let pt=CGPoint(x:left+CGFloat(i)/CGFloat(max(1,model.history.count-1))*width,y:y(v));if started{p.addLine(to:pt)}else{p.move(to:pt);started=true}};context.stroke(p,with:.color(historyColor(f)),style:StrokeStyle(lineWidth:f=="短时 S" ? 1.8 : 1,lineJoin:.round))}
        if model.history.isEmpty {context.draw(Text(model.text("等待音频输入")).font(.system(size:12)).foregroundColor(.secondary.opacity(0.5)),at:CGPoint(x:size.width/2,y:size.height/2))}
    }.accessibilityLabel(model.text("响度历史曲线"))}
}
struct VectorPlot:View {
    var language:AppLanguage
    var values:[Float]
    var body:some View {Canvas{context,size in
        let center=CGPoint(x:size.width/2,y:size.height/2),r=min(size.width/2,size.height/2)-6
        var grid=Path();grid.addEllipse(in:CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2));for sign in [-1.0,1.0]{grid.move(to:CGPoint(x:center.x-r*0.707,y:center.y-r*0.707*sign));grid.addLine(to:CGPoint(x:center.x+r*0.707,y:center.y+r*0.707*sign))};grid.move(to:CGPoint(x:center.x,y:center.y-r));grid.addLine(to:CGPoint(x:center.x,y:center.y+r));context.stroke(grid,with:.color(.secondary.opacity(0.12)),lineWidth:1)
        var p=Path();for i in 0..<values.count/2 {let l=Double(values[i*2]),rr=Double(values[i*2+1]);let pt=CGPoint(x:center.x+CGFloat((rr-l)*0.7)*r,y:center.y-CGFloat((l+rr)*0.7)*r);if i==0{p.move(to:pt)}else{p.addLine(to:pt)}};context.stroke(p,with:.color(accent.opacity(0.8)),style:StrokeStyle(lineWidth:1,lineJoin:.round))
    }.accessibilityLabel(language.text("立体声向量图"))}
}
struct BalanceBar:View {var value:Double;var correlation:Bool
    var body:some View {GeometryReader{g in ZStack(alignment:.leading){Capsule().fill(.secondary.opacity(0.1));Capsule().fill(correlation && value<0 ? .orange : accent).frame(width:4,height:7).offset(x:(g.size.width-4)*CGFloat((max(-1,min(1,value))+1)/2));Rectangle().fill(.secondary.opacity(0.3)).frame(width:1).offset(x:g.size.width/2)}}.frame(height:5)}
}
