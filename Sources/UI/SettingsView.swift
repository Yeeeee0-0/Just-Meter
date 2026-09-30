import SwiftUI
import AppKit

struct SettingsView:View {
    @ObservedObject var model:MeterModel
    @ViewState var rename:MeterLayout?=nil
    @ViewState var renameText=""
    @ViewState var deleting:MeterLayout?=nil
    var body:some View {
        VStack(alignment:.leading,spacing:20){
            HStack(alignment:.firstTextBaseline){Text(model.text("设置")).font(.system(size:28,weight:.semibold,design:.rounded));Spacer();Text(model.text("让每一次测量，更合你的习惯。")).font(.system(size:12)).foregroundStyle(.secondary)}
            Picker(model.text("设置分类"),selection:$model.settingsTab){ForEach(["外观","布局","响度","日志"],id:\.self){Text(model.text($0)).tag($0)}}.pickerStyle(.segmented).labelsHidden().frame(maxWidth:460)
            ScrollView {
                VStack(alignment:.leading,spacing:0){
                    switch model.settingsTab {
                    case "外观":appearance
                    case "布局":layouts
                    case "响度":loudness
                    default:logs
                    }
                }.padding(22).modifier(GlassCard(transparency:model.preferences.transparency))
            }.scrollIndicators(.hidden)
            HStack{Spacer();Button(model.text("关于 Just Meter")){model.showAbout=true}.buttonStyle(.plain).font(.system(size:11)).foregroundStyle(.secondary)}
        }.padding(.horizontal,28).padding(.top,8)
        .sheet(item:$rename){_ in VStack(alignment:.leading,spacing:18){Text(model.text("重命名布局")).font(.headline);TextField(model.text("名称"),text:$renameText).textFieldStyle(.roundedBorder);HStack{Spacer();Button(model.text("取消")){rename=nil};Button(model.text("保存")){if let l=rename,let i=model.preferences.layouts.firstIndex(where:{$0.id==l.id}){let name=renameText.trimmingCharacters(in:.whitespacesAndNewlines);if !name.isEmpty{model.preferences.layouts[i].name=String(name.prefix(40));model.persist()}};rename=nil}.buttonStyle(.glassProminent)}}.padding(28).frame(width:340).glassEffect(.regular,in:RoundedRectangle(cornerRadius:24))}
        .alert(model.text("删除布局？"),isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}})){Button(model.text("取消"),role:.cancel){deleting=nil};Button(model.text("删除"),role:.destructive){if let l=deleting{model.deleteLayout(l)};deleting=nil}} message:{Text(model.language.format("“{0}”将被删除。删除当前布局后会返回默认布局。",deleting?.name ?? ""))}
    }
    func row<Content:View>(_ title:String,_ detail:String,@ViewBuilder content:()->Content)->some View {
        HStack(alignment:.center,spacing:24){VStack(alignment:.leading,spacing:6){Text(model.text(title)).font(.system(size:13,weight:.medium));Text(model.text(detail)).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)}.frame(maxWidth:.infinity,alignment:.leading);content().frame(maxWidth:300)}.padding(.vertical,18)
    }
    var appearance:some View {
        Group{
            row("语言 / Language","切换后立即生效，并记住你的选择。"){
                Picker("Language",selection:Binding(get:{model.language},set:{model.setLanguage($0)})){
                    ForEach(AppLanguage.allCases){language in Text(language.name).tag(language)}
                }.labelsHidden().frame(width:170)
            };Divider()
            row("外观模式","跟随系统，或选择固定的浅色与深色外观。"){
                Picker(model.text("外观模式"),selection:$model.preferences.theme){Text(model.text("跟随系统")).tag("system");Text(model.text("浅色")).tag("light");Text(model.text("深色")).tag("dark")}.labelsHidden().frame(width:170)
            };Divider()
            row("界面缩放","缩放所有组件、文字和操作控件。窗口大小可以单独拖动调整。"){
                Picker(model.text("界面缩放"),selection:Binding(get:{model.preferences.scale},set:{model.preferences.scale=$0;model.persist()})){
                    ForEach(Preferences.scales,id:\.self){value in Text("\(Int((value*100).rounded()))%").tag(value)}
                }.labelsHidden().frame(width:170)
            };Divider()
            row("毛玻璃透明度","调整窗口与组件的底色透明程度。文字、数字和图线保持清晰。"){
                VStack(alignment:.trailing,spacing:7){Text("\(Int(model.preferences.transparency))%").font(.system(size:12)).monospacedDigit();Slider(value:$model.preferences.transparency,in:0...85,step:1).accessibilityLabel(model.text("界面透明度"));HStack{Text(model.text("不透明"));Spacer();Text(model.text("通透"))}.font(.system(size:10)).foregroundStyle(.secondary)}
            };Divider()
            row("辅助功能","系统开启减少透明度时，自动使用实色背景。"){Text(model.text("跟随 macOS")).font(.caption).foregroundStyle(.secondary)}
        }
    }
    var layouts:some View {
        Group {
            HStack{Text(model.text("默认布局固定首位。自定义布局可自由编辑和排序。")).font(.caption).foregroundStyle(.secondary);Spacer();Button(model.text("新建布局"),systemImage:"plus"){model.beginEdit(nil,fromSettings:true)}.buttonStyle(.glass)}.padding(.bottom,16)
            ForEach(Array(model.allLayouts.enumerated()),id:\.element.id){i,l in
                HStack(spacing:14){Text(String(format:"%02d",i+1)).font(.system(size:11,design:.monospaced)).foregroundStyle(.tertiary).frame(width:22);VStack(alignment:.leading,spacing:4){Text(model.layoutName(l)).font(.system(size:13,weight:.medium));Text(l.id=="default" ? model.text("系统预设 · 四个 1 × 1 组件") : model.language.format("{0} 个组件",String(l.widgets.count))).font(.system(size:10)).foregroundStyle(.secondary)};Spacer()
                    if model.preferences.selected==l.id{Text(model.text("使用中")).font(.system(size:10)).foregroundStyle(accent).padding(.horizontal,8)}else{Button(model.text("使用")){model.preferences.selected=l.id;model.persist()}}
                    if l.id=="default"{Button(model.text("复制并编辑")){model.beginEdit(l,fromSettings:true)}}else{
                        Button(model.text("编辑")){model.beginEdit(l,fromSettings:true)}
                        Menu{Button(model.text("重命名…")){rename=l;renameText=l.name};Button(model.text("上移")){model.moveLayout(l.id,-1)}.disabled(i<=1);Button(model.text("下移")){model.moveLayout(l.id,1)}.disabled(i>=model.allLayouts.count-1);Divider();Button(model.text("删除…"),role:.destructive){deleting=l}}label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).frame(width:24)
                    }
                }.buttonStyle(.glass).controlSize(.small).padding(.vertical,16)
                if i<model.allLayouts.count-1 {Divider()}
            }
        }
    }
    var loudness:some View {
        Group {
            row("测量标准","K 加权 · 400 ms 瞬时 · 3 s 短时 · 绝对与相对门限") {Text("EBU R128 / BS.1770").font(.caption).foregroundStyle(.secondary)};Divider()
            row("响度单位","切换单位不会重置测量。范围始终使用 LU，真峰值使用 dBTP。") {Picker(model.text("响度单位"),selection:$model.preferences.unit){Text("LUFS").tag("LUFS");Text("LKFS").tag("LKFS");Text(model.text("LU · 相对")).tag("LU")}.labelsHidden().frame(width:160)};Divider()
            if model.preferences.unit=="LU" {row("相对参考","0 LU 对应的绝对响度。"){HStack{TextField(model.text("参考值"),value:$model.preferences.reference,format:.number.precision(.fractionLength(1))).textFieldStyle(.roundedBorder).frame(width:75);Text("LUFS").font(.caption)}};Divider()}
            row("目标响度","用于历史图参考线，不改变音频。"){HStack{TextField(model.text("目标响度"),value:$model.preferences.target,format:.number.precision(.fractionLength(1))).textFieldStyle(.roundedBorder).frame(width:75);Text("LUFS").font(.caption)}};Divider()
            row("真峰值上限","超出此值时，峰值读数显示为橙色。"){HStack{TextField(model.text("真峰值上限"),value:$model.preferences.peakLimit,format:.number.precision(.fractionLength(1))).textFieldStyle(.roundedBorder).frame(width:75);Text("dBTP").font(.caption)}}
            if model.plugin {Divider();row("跟随宿主播放","开启后，宿主停止时不再累计测量。"){Toggle(model.text("跟随宿主播放"),isOn:$model.preferences.followTransport).labelsHidden().toggleStyle(.switch)}}
            Text(model.text("第一版使用 EBU 测量流程。WLM 的 DIAL / LM1 专用模式和告警计数将在后续版本接入。")).font(.system(size:11)).foregroundStyle(.secondary).padding(.top,16)
        }
    }
    var logs:some View {
        Group {
            row("导出测量日志","导出时间、瞬时、短时、整段响度和真峰值保持。CSV 始终使用 LUFS。") {Button(model.text("导出 CSV…")){model.exportCSV()}.buttonStyle(.glass).disabled(model.history.isEmpty)};Divider()
            row("历史容量","曲线和 CSV 保存最近 60 分钟，每 100 ms 一个记录；整段测量从上次重置开始累计。") {Text("100 ms").font(.caption).foregroundStyle(.secondary)}
            if model.snapshot.droppedFrames>0 {Text(model.language.format("本次测量丢失 {0} 帧。请降低系统负载并重新测量。",String(model.snapshot.droppedFrames))).font(.caption).foregroundStyle(.orange)}
        }
    }
}

struct WidgetConfig:View {
    @ObservedObject var model:MeterModel
    var widget:Widget
    @Environment(\.dismiss) var dismiss
    var current:Widget {model.draft?.widgets.first(where:{$0.id==widget.id}) ?? widget}
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(model.language.format("{0} · 组件设置",model.text(widget.kind.title))).font(.headline)
            Text(model.text("尺寸 · 宽 × 高")).font(.caption).foregroundStyle(.secondary)
            HStack {ForEach(["1×1","1×2","2×1","2×2"],id:\.self){size in Button(size){let x=size.split(separator:"×");model.modifyWidget(widget.id){$0.width=Int(x[0])!;$0.height=Int(x[1])!}}.buttonStyle(.glass).tint(size=="\(current.width)×\(current.height)" ? accent : .secondary)}}
            Divider();Text(model.text("显示数据 · 首项优先")).font(.caption).foregroundStyle(.secondary)
            ForEach(current.fields + widget.kind.fields.filter{!current.fields.contains($0)},id:\.self){field in
                HStack {
                    Toggle(model.text(field),isOn:Binding(get:{current.fields.contains(field)},set:{on in model.modifyWidget(widget.id){if on{$0.fields.append(field)}else if $0.fields.count>1{$0.fields.removeAll{$0==field}}}})).toggleStyle(.checkbox)
                    Spacer()
                    if let index=current.fields.firstIndex(of:field),index>0 {Button{model.modifyWidget(widget.id){$0.fields.swapAt(index,index-1)}}label:{Image(systemName:"arrow.up")}.buttonStyle(.plain).help(model.text("向前移动"))}
                }.font(.system(size:12))
            }
            Divider()
            HStack {
                Button(model.text("移除组件"),role:.destructive){if (model.draft?.widgets.count ?? 0)>1{model.draft?.widgets.removeAll{$0.id==widget.id};dismiss()}}.disabled((model.draft?.widgets.count ?? 0)<=1)
                Spacer();Button(model.text("完成")){dismiss()}.buttonStyle(.glassProminent)
            }
        }.padding(22).frame(width:310).glassEffect(.regular,in:RoundedRectangle(cornerRadius:20))
    }
}

struct AboutView:View {
    @ObservedObject var model:MeterModel
    @Environment(\.dismiss) var dismiss
    var body:some View {
        VStack(spacing:16) {
            Text("Yee Huang").font(.system(size:26,weight:.semibold,design:.rounded))
            Link("yeehuang2002@163.com",destination:URL(string:"mailto:yeehuang2002@163.com")!)
                .font(.system(size:13)).textSelection(.enabled)
            Button(model.text("完成")){dismiss()}.buttonStyle(.glassProminent).padding(.top,8)
        }.padding(32).frame(width:330).glassEffect(.regular,in:RoundedRectangle(cornerRadius:24))
    }
}
