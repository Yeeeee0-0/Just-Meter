import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var name: String { self == .chinese ? "中文" : "English" }
    static func preferred(_ languages: [String] = Locale.preferredLanguages) -> AppLanguage {
        languages.first?.hasPrefix("zh") == true ? .chinese : .english
    }
    func text(_ key: String) -> String { self == .english ? Self.englishText[key] ?? key : key }
    func format(_ key: String, _ arguments: String...) -> String {
        LocalizedMessage(key, arguments: arguments).resolved(in: self)
    }

    // Keys are stable, including legacy widget field IDs stored in DAW projects.
    // This per-instance catalog also works inside a DAW without using its bundle.
    static let englishText: [String: String] = [
        "设置": "Settings", "让每一次测量，更合你的习惯。": "Make every measurement feel your own.",
        "设置分类": "Settings category", "外观": "Appearance", "布局": "Layouts", "响度": "Loudness", "日志": "Logs",
        "关于 Just Meter": "About Just Meter", "重命名布局": "Rename Layout", "名称": "Name",
        "取消": "Cancel", "保存": "Save", "删除布局？": "Delete Layout?", "删除": "Delete",
        "“{0}”将被删除。删除当前布局后会返回默认布局。": "“{0}” will be deleted. Deleting the current layout returns to Default.",
        "外观模式": "Appearance", "跟随系统，或选择固定的浅色与深色外观。": "Follow macOS or choose a light or dark appearance.",
        "跟随系统": "System", "浅色": "Light", "深色": "Dark",
        "语言 / Language": "Language / 语言", "切换后立即生效，并记住你的选择。": "Changes apply immediately and are remembered.",
        "界面缩放": "Interface Scale", "缩放所有组件、文字和操作控件。窗口大小可以单独拖动调整。": "Scale widgets, text and controls. Resize the window separately by dragging its edges.",
        "毛玻璃透明度": "Glass Transparency", "调整窗口与组件的底色透明程度。文字、数字和图线保持清晰。": "Adjust the transparency of windows and widgets while keeping text, numbers and graphs clear.",
        "界面透明度": "Interface transparency", "不透明": "Opaque", "通透": "Clear",
        "辅助功能": "Accessibility", "系统开启减少透明度时，自动使用实色背景。": "Use solid backgrounds when Reduce Transparency is enabled in macOS.", "跟随 macOS": "Follows macOS",
        "默认布局固定首位。自定义布局可自由编辑和排序。": "Default stays first. Edit and reorder your custom layouts.",
        "新建布局": "New Layout", "默认": "Default", "系统预设 · 四个 1 × 1 组件": "Built-in · Four 1 × 1 widgets", "{0} 个组件": "{0} widgets",
        "使用中": "Active", "使用": "Use", "复制并编辑": "Duplicate & Edit", "编辑": "Edit", "重命名…": "Rename…",
        "上移": "Move Up", "下移": "Move Down", "删除…": "Delete…",
        "测量标准": "Measurement Standard", "K 加权 · 400 ms 瞬时 · 3 s 短时 · 绝对与相对门限": "K-weighted · 400 ms momentary · 3 s short-term · Absolute and relative gates",
        "响度单位": "Loudness Units", "切换单位不会重置测量。范围始终使用 LU，真峰值使用 dBTP。": "Changing units preserves measurements. Loudness range uses LU; true peak uses dBTP.",
        "LU · 相对": "LU · Relative", "相对参考": "Relative Reference", "0 LU 对应的绝对响度。": "Absolute loudness corresponding to 0 LU.", "参考值": "Reference",
        "目标响度": "Target Loudness", "用于历史图参考线，不改变音频。": "Reference line in the history graph. Does not alter audio.",
        "真峰值上限": "True Peak Limit", "超出此值时，峰值读数显示为橙色。": "Peak readings turn orange above this level.",
        "跟随宿主播放": "Follow Host Transport", "开启后，宿主停止时不再累计测量。": "Pause measurement accumulation when the host stops.",
        "第一版使用 EBU 测量流程。WLM 的 DIAL / LM1 专用模式和告警计数将在后续版本接入。": "This preview uses EBU measurement. WLM-specific DIAL / LM1 modes and warning counters are planned for a later version.",
        "导出测量日志": "Export Measurement Log", "导出时间、瞬时、短时、整段响度和真峰值保持。CSV 始终使用 LUFS。": "Export time, momentary, short-term, integrated loudness and true peak hold. CSV always uses LUFS.",
        "导出 CSV…": "Export CSV…", "历史容量": "History Capacity", "曲线和 CSV 保存最近 60 分钟，每 100 ms 一个记录；整段测量从上次重置开始累计。": "Graphs and CSV retain the last 60 minutes at 100 ms intervals. Integrated loudness accumulates from the last reset.",
        "本次测量丢失 {0} 帧。请降低系统负载并重新测量。": "{0} frames were dropped. Reduce system load and measure again.",
        "{0} · 组件设置": "{0} · Widget Settings", "尺寸 · 宽 × 高": "Size · Width × Height", "显示数据 · 首项优先": "Displayed Data · First Item Takes Priority",
        "向前移动": "Move Up", "移除组件": "Remove Widget", "完成": "Done", "好": "OK",
        "新建布局…": "New Layout…", "复制默认并编辑…": "Duplicate Default & Edit…", "编辑当前布局…": "Edit Current Layout…",
        "取消置顶": "Disable Always on Top", "窗口始终置顶": "Always on Top", "已置顶": "Always on Top Enabled", "窗口置顶": "Always on Top",
        "返回仪表": "Back to Meter", "布局名称": "Layout Name", "拖动组件换位": "Drag widgets to rearrange", "添加组件": "Add Widget", "保存布局": "Save Layout",
        "导入音频文件…": "Import Audio File…", "系统音频": "System Audio", "默认音频输入": "Default Audio Input", "断开音频来源": "Disconnect Source",
        "选择音频来源": "Choose Audio Source", "音频来源已断开": "Audio source disconnected", "音频队列发生丢帧，请重置后重新测量。": "Audio frames were dropped. Reset and measure again.",
        "继续测量": "Resume Measurement", "暂停测量": "Pause Measurement", "重置测量": "Reset Measurement",
        "频谱": "Spectrum", "响度历史": "Loudness History", "立体声": "Stereo", "峰值": "Peaks",
        "实时曲线": "Live Spectrum", "参考曲线": "Reference Spectrum", "整段 I": "Integrated I", "瞬时 M": "Momentary M", "短时 S": "Short-term S", "范围 LRA": "Range LRA", "最大瞬时": "Max Momentary",
        "向量图": "Vectorscope", "相关度": "Correlation", "左右平衡": "Stereo Balance",
        "捕获参考": "Capture Reference", "更新参考": "Update Reference", "清除": "Clear", "等待音频": "Waiting for audio",
        "清除峰值保持": "Clear Peak Hold", "实时频谱，20 Hz 至 20 kHz": "Live spectrum, 20 Hz to 20 kHz", "等待音频输入": "Waiting for audio input", "响度历史曲线": "Loudness history graph", "立体声向量图": "Stereo vectorscope",
        "选择音频来源，开始测量": "Choose an audio source to start measuring", "等待宿主音频": "Waiting for host audio",
        "宿主音频 · {0} kHz · {1} 声道": "Host audio · {0} kHz · {1} channels", "自定义布局 {0}": "Custom Layout {0}", "自定义布局": "Custom Layout",
        "无法写入日志文件。": "Unable to write the log file.",
        "请在系统设置 → 隐私与安全性 → 麦克风中允许 Just Meter 使用音频输入。": "Allow Just Meter to use audio input in System Settings → Privacy & Security → Microphone.",
        "当前默认输入设备不可用，或超过 6 声道。": "The default input device is unavailable or has more than 6 channels.",
        "默认音频输入 · {0} kHz": "Default audio input · {0} kHz", "系统音频 · 正在连接…": "System audio · Connecting…",
        "系统音频 · 等待播放": "System audio · Waiting for playback", "系统音频 · 连接失败": "System audio · Connection failed",
        "系统音频 · 输入格式异常，请重新连接": "System audio · Invalid input format; reconnect",
        "系统音频 · 等待数据，请播放音频或检查录制权限": "System audio · Play audio or check recording permission",
        "系统音频 · 当前静音，等待播放": "System audio · Silent; waiting for playback", "系统音频 · {0} kHz · Stereo": "System audio · {0} kHz · Stereo",
        "分析 · {0}": "Analyzing · {0}", "{0} · 分析完成": "{0} · Analysis complete", "第一版支持 1–6 声道音频文件。": "This preview supports audio files with 1–6 channels.",
        "{0}失败（{1}）。请确认系统设置 → 隐私与安全性 → 屏幕与系统音频录制中允许 Just Meter 录制系统音频，然后重新连接。": "{0} failed ({1}). Allow Just Meter in System Settings → Privacy & Security → Screen & System Audio Recording, then reconnect.",
        "创建系统音频捕获": "Create system audio capture", "读取系统音频格式": "Read system audio format", "连接系统音频": "Connect system audio", "注册系统音频输入": "Register system audio input", "启动系统音频": "Start system audio",
        "系统返回了不支持的音频格式。请重新选择系统输出设备后连接。": "The system returned an unsupported audio format. Reselect the system output device and reconnect.",
        "设置…": "Settings…", "隐藏 Just Meter": "Hide Just Meter", "退出 Just Meter": "Quit Just Meter", "文件": "File", "分析音频文件…": "Analyze Audio File…",
        "撤销": "Undo", "剪切": "Cut", "复制": "Copy", "粘贴": "Paste", "全选": "Select All"
    ]
}

struct LocalizedMessage: ExpressibleByStringLiteral {
    let key: String
    var arguments: [String] = []
    var verbatim = false
    init(stringLiteral value: String) { key = value }
    init(_ key: String, arguments: [String] = [], verbatim: Bool = false) {
        self.key = key; self.arguments = arguments; self.verbatim = verbatim
    }
    func resolved(in language: AppLanguage) -> String {
        let template = verbatim ? key : language.text(key)
        // Substitute once so file and layout names remain literal, even with {0} in them.
        return template.components(separatedBy: "{").enumerated().map { index, part in
            guard index > 0 else { return part }
            guard let end = part.firstIndex(of: "}"), let i = Int(part[..<end]), arguments.indices.contains(i) else { return "{" + part }
            return arguments[i] + part[part.index(after: end)...]
        }.joined()
    }
}
