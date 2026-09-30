<p align="center"><img src="Sources/App/Resources/AppIcon.png" width="128" alt="Just Meter icon"></p>

# Just Meter

**清晰看见每一段声音。**

**macOS · Windows · 独立应用 + VST3 · 中文 / English**

[English](#english) · [下载与安装](#下载与安装) · [macOS 构建](docs/BUILDING.md) · [Windows 使用与构建](https://github.com/Yeeeee0-0/Just-Meter/blob/windows-port/docs/Windows.md) · [MIT License](LICENSE)

Just Meter 是一款面向 macOS 和 Windows 的频谱与响度测量工具，提供独立应用和 VST3 插件。

频谱、响度、历史曲线和立体声信息汇集在简洁的玻璃风格界面中。默认四个模块以 2×2 平铺，也可以按自己的工作习惯调整组件的位置、尺寸和显示内容。两个平台共用测量核心，提供对应的布局、语言和外观设置。

## 下载与安装

当前版本：**0.1.3 Preview**。

| 平台 | 系统要求 | 下载 |
| --- | --- | --- |
| macOS | Apple Silicon · macOS 26+ | [macOS 安装包（Release）](https://github.com/Yeeeee0-0/Just-Meter/releases/tag/v0.1.3) |
| Windows | Windows 10 1809+ / Windows 11 · x64 | [Windows 预览构建（Actions）](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291/artifacts/11105345969) |

两个平台的安装器都可以选择 **独立应用、VST3 插件，或同时安装**。安装前退出 Just Meter 和 DAW。插件需要支持对应平台与架构的 VST3 宿主。

### macOS

下载并打开 `Just-Meter-0.1.3-macOS-arm64-preview.pkg`，按安装向导选择组件。安装器跟随系统显示中文或英文。

- 独立应用：`/Applications/Just Meter.app`
- VST3：`/Library/Audio/Plug-Ins/VST3/Just Meter.vst3`

### Windows

Windows 目前通过 GitHub Actions 提供预览构建，**尚未发布到 Releases**。下载需要登录 GitHub；若直接链接无法打开，可进入[构建页面](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291)，在 **Artifacts** 中下载 `Just-Meter-Windows-x64-preview`。此构建产物当前保留至 **2026-12-29**。

解压下载的构建压缩包，在其中的 `outputs` 文件夹选择：

| 文件 | 用途 |
| --- | --- |
| `Just-Meter-0.1.3-Windows-x64-preview-Setup.exe` | 推荐使用。中英文安装向导，可选择独立应用、VST3 或两者；包含 Microsoft WebView2 离线运行时，缺少时自动安装。 |
| `Just-Meter-0.1.3-Windows-x64-preview-Portable.zip` | 便携版，包含独立应用和 VST3。需要预先安装 WebView2；插件文件夹需要手动复制到 VST3 目录。 |
| `Just-Meter-0.1.3-Windows-SHA256SUMS.txt` | 用于核对安装包和便携包的 SHA-256 校验值。 |

默认安装位置：

- 独立应用：`C:\Program Files\Just Meter\Just Meter.exe`
- VST3：`C:\Program Files\Common Files\VST3\JustMeter.vst3`

安装器包含离线运行时，体积约 205 MiB；便携包约 1.5 MiB。手动安装插件时，请复制完整的 `JustMeter.vst3` 文件夹，保留其内部结构。

安装完成后，在 DAW 中重新扫描并搜索 **Just Meter**。升级时避免保留旧的手动安装副本；如果宿主缓存过扫描失败记录，可能需要清除该记录后重新扫描。

## 主要功能

- **频谱分析**：实时频谱显示，支持捕获参考曲线。
- **响度测量**：整段响度、瞬时响度、短时响度、响度范围与最大瞬时响度。
- **峰值监测**：真峰值、采样峰值与峰值保持。
- **立体声观察**：向量图、相关度与左右平衡。
- **历史与导出**：查看响度变化，导出 CSV 测量记录。
- **自定义布局**：支持 1×1、1×2、2×1、2×2 组件，调整排列、显示数据并保存布局预设。
- **外观调整**：浅色、深色与跟随系统外观，背景透明度、界面缩放，以及独立应用窗口置顶。
- **中英文支持**：软件内可即时切换语言，两个平台均提供中英文安装界面。

响度单位支持 LUFS、LKFS 和相对 LU，相对参考值可以自行设置。

macOS 使用原生玻璃材质；Windows 11 使用原生 Acrylic 背景，Windows 10 使用兼容的玻璃样式。界面采用相同的视觉方向，具体系统材质会有所不同。

## 两种使用方式

**独立应用**：测量系统播放的声音、默认音频输入，或导入音频文件进行离线分析。

**VST3 插件**：在 DAW 中测量轨道或总线音频。插件让音频原样通过，不进行增益调整、响度校正或限幅。

打开独立应用后，在左下角选择音频来源。macOS 首次使用系统音频或音频输入时，需要授予对应的录制权限。Windows 系统音频使用 WASAPI 回环采集默认输出设备，音频输入使用默认录音设备；更改默认设备后，请重新选择来源。独占模式、受保护音频和 ASIO 直通可能绕过系统混音器，测量 DAW 音频时可直接使用 VST3。

语言切换位置：**设置 → 外观 → 语言 / Language**。设置中也可以调整布局、外观和测量选项。音频分析在本机完成，不上传音频内容。

## 当前版本说明

**0.1.3 是预览版本。**

- **macOS**：尚未完成 Developer ID 正式签名与 Apple 公证，可能出现安全提示或插件扫描拦截。
- **Windows**：尚未进行 Authenticode 代码签名，下载或首次运行时可能出现 SmartScreen 提示。
- **已验证**：DSP 数值测试、VST3 validator 的全部 47 项校验、测试宿主中的界面加载与音频原样通过。Windows 还通过了文件分析、界面交互，以及独立应用 / 仅 VST3 / 同时安装的安装与卸载检查，见[构建记录](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291)。
- **待验证**：Windows 实体音频设备采集与各 DAW 的实际挂载；不同设备及长时间运行的兼容性仍需进一步测试。

目前提供 macOS Apple Silicon 和 Windows x64 的独立应用与 VST3；暂不提供 Intel Mac、Windows ARM64 原生构建或 AU 格式。

## 源码与构建

- [macOS 构建说明](docs/BUILDING.md)
- [Windows 使用与构建说明](https://github.com/Yeeeee0-0/Just-Meter/blob/windows-port/docs/Windows.md)

Windows 源码目前位于 [`windows-port` 分支](https://github.com/Yeeeee0-0/Just-Meter/tree/windows-port)，对应 [PR #1](https://github.com/Yeeeee0-0/Just-Meter/pull/1)。从源码构建 Windows 版时，请先切换到该分支。

## 作者与致谢

**Yee Huang**  
联系邮箱：[yeehuang2002@163.com](mailto:yeehuang2002@163.com)

本项目使用 AI 辅助开发，采用 [MIT 许可证](LICENSE)。响度计算使用 libebur128，插件接口使用 Steinberg VST3 SDK；Windows 界面使用 Microsoft WebView2。第三方许可证随应用与插件一并提供，详见 [macOS 第三方说明](THIRD_PARTY_NOTICES.md)与 [Windows 第三方说明](https://github.com/Yeeeee0-0/Just-Meter/blob/windows-port/THIRD_PARTY_NOTICES.md)。

---

# English

**See your sound clearly.**

**macOS · Windows · Standalone + VST3 · Chinese / English**

Just Meter is a spectrum and loudness meter for macOS and Windows, available as a standalone app and a VST3 plug-in.

Spectrum, loudness, history and stereo information share a clean, glass-style interface. Four widgets form the default 2×2 layout; rearrange and resize them, or choose the data they display. Both platforms share the measurement core and provide corresponding layout, language and appearance settings.

## Download and Install

Current version: **0.1.3 Preview**.

| Platform | Requirements | Download |
| --- | --- | --- |
| macOS | Apple Silicon · macOS 26+ | [macOS installer (Release)](https://github.com/Yeeeee0-0/Just-Meter/releases/tag/v0.1.3) |
| Windows | Windows 10 1809+ / Windows 11 · x64 | [Windows preview build (Actions)](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291/artifacts/11105345969) |

Both installers offer the **standalone app, VST3 plug-in, or both**. Quit Just Meter and your DAW before installing. The plug-in requires a VST3 host matching the platform and architecture.

### macOS Installation

Open `Just-Meter-0.1.3-macOS-arm64-preview.pkg` and choose the components to install. The installer follows the system language for Chinese or English.

- App: `/Applications/Just Meter.app`
- VST3: `/Library/Audio/Plug-Ins/VST3/Just Meter.vst3`

### Windows Installation

The Windows preview is currently distributed through GitHub Actions and **has not been published to Releases**. A GitHub sign-in is required. If the direct link is unavailable, open the [build page](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291) and download `Just-Meter-Windows-x64-preview` under **Artifacts**. This artifact is currently retained until **2026-12-29**.

Extract the downloaded artifact and choose a file from its `outputs` folder:

| File | Purpose |
| --- | --- |
| `Just-Meter-0.1.3-Windows-x64-preview-Setup.exe` | Recommended. Chinese / English setup with selectable app and VST3 components. Includes the offline Microsoft WebView2 Runtime installer and installs it if needed. |
| `Just-Meter-0.1.3-Windows-x64-preview-Portable.zip` | Portable app and VST3. Requires an existing WebView2 Runtime; install the plug-in folder manually. |
| `Just-Meter-0.1.3-Windows-SHA256SUMS.txt` | SHA-256 checksums for the installer and portable archive. |

Default installation locations:

- App: `C:\Program Files\Just Meter\Just Meter.exe`
- VST3: `C:\Program Files\Common Files\VST3\JustMeter.vst3`

The installer is approximately 205 MiB because it bundles the offline runtime; the portable archive is approximately 1.5 MiB. For a manual plug-in installation, copy the entire `JustMeter.vst3` folder, preserving its internal structure.

Rescan plug-ins in your DAW and search for **Just Meter**. Avoid keeping older manually installed duplicates. If your host cached an earlier scan failure, clear that entry and rescan.

## Features

- Real-time spectrum analysis with reference curves.
- Integrated, momentary and short-term loudness, loudness range and maximum momentary loudness.
- True peak, sample peak and peak hold.
- Stereo vectorscope, correlation and balance.
- Loudness history and CSV export.
- Custom layouts with 1×1, 1×2, 2×1 and 2×2 widgets.
- Light, dark and system appearance, adjustable transparency and interface scale, plus an always-on-top option for the standalone app.
- Instant Chinese / English switching and bilingual installers on both platforms.

Loudness units include LUFS, LKFS and relative LU with an adjustable reference level.

macOS uses native glass materials. Windows 11 uses a native Acrylic background, with a compatible glass style on Windows 10. The visual direction is shared; system materials vary by platform.

## Standalone App and VST3

Use the **standalone app** to measure system audio, the default audio input, or imported audio files.

Use the **VST3 plug-in** to measure tracks and buses in a compatible DAW. Audio passes through unchanged, without gain adjustment, loudness correction or limiting.

Select an audio source from the lower-left corner of the standalone app. macOS requires the corresponding recording permissions. Windows uses WASAPI loopback on the default output, or the default recording device for input; reselect the source after changing devices. Exclusive, protected and direct ASIO audio may bypass the Windows mixer. Use the VST3 to measure audio inside your DAW.

Change language in **Settings → Appearance → Language / 语言**. Settings also contains layout, appearance and measurement options. Audio is processed locally and is not uploaded.

## Preview Status

**Version 0.1.3 is a preview.**

- **macOS:** Developer ID signing and Apple notarization are not yet complete. Security warnings or blocked plug-in scans may occur.
- **Windows:** The binaries are not Authenticode-signed. SmartScreen may show download or first-run prompts.
- **Verified:** DSP tests, all 47 VST3 validator checks, editor loading and unchanged audio pass-through in a test host. Windows also passed file analysis, UI interaction, and app-only / VST3-only / combined installation and uninstallation checks. See the [build results](https://github.com/Yeeeee0-0/Just-Meter/actions/runs/36730470291).
- **Still to verify:** Physical Windows audio-device capture and individual DAWs. Compatibility across devices and extended sessions needs further testing.

Current builds target macOS Apple Silicon and Windows x64, with standalone and VST3 formats. Intel Mac, native Windows ARM64 and AU builds are not currently available.

## Source and Build

- [macOS build instructions](docs/BUILDING.md)
- [Windows usage and build instructions](https://github.com/Yeeeee0-0/Just-Meter/blob/windows-port/docs/Windows.md)

Windows source currently lives on the [`windows-port` branch](https://github.com/Yeeeee0-0/Just-Meter/tree/windows-port), with integration tracked in [PR #1](https://github.com/Yeeeee0-0/Just-Meter/pull/1). Check out that branch before building the Windows version.

## Author and Credits

**Yee Huang**  
Contact: [yeehuang2002@163.com](mailto:yeehuang2002@163.com)

Developed with AI assistance and released under the [MIT License](LICENSE). Loudness measurement uses libebur128; plug-in integration uses the Steinberg VST3 SDK; the Windows interface uses Microsoft WebView2. Third-party licenses are included with the app and plug-in. See the [macOS notices](THIRD_PARTY_NOTICES.md) and [Windows notices](https://github.com/Yeeeee0-0/Just-Meter/blob/windows-port/THIRD_PARTY_NOTICES.md).
