# Just Meter for Windows

Windows 10 (1809+) / Windows 11, x64. Preview build.

## 安装 / Installation

运行 Setup.exe，选择中文或 English，再选择独立软件、VST3 插件或两者。安装器包含 Microsoft WebView2 离线运行时，仅在系统缺少运行时时安装。安装 VST3 后重新扫描 DAW 插件列表。

Run Setup.exe, choose Chinese or English, and select the standalone app, VST3, or both. The installer includes Microsoft's offline WebView2 Runtime installer and installs it only if needed. Rescan your DAW after installing the VST3.

- App: `C:\Program Files\Just Meter\Just Meter.exe`
- VST3: `C:\Program Files\Common Files\VST3\JustMeter.vst3`

便携压缩包需要预先安装 Microsoft WebView2 Runtime；其中 VST3 文件夹需手动放入上述 VST3 目录。卸载器保留用户布局与偏好。

The portable archive requires the Microsoft WebView2 Runtime. Copy its complete VST3 folder to the location above. Uninstalling preserves user layouts and preferences.

## 功能 / Features

与 macOS 版共用同一套响度、频谱和立体声测量核心以及 VST3 音频处理代码。默认四格布局、自定义组件布局、中英切换、浅色/深色/系统模式、缩放、透明度、置顶、参考频谱、文件测量和 CSV 日志均提供对应的 Windows 界面。

Shares the macOS measurement core and VST3 audio processing: integrated/momentary/short-term loudness, LRA, maximum momentary, true/sample peak, spectrum, stereo field, transport following and unchanged audio pass-through. The Windows UI provides the same layouts, widgets, language/theme/scale/transparency settings, pinning, reference spectrum, file measurement and CSV export.

系统音频使用 Windows WASAPI loopback，采集默认输出设备；音频输入使用默认录音设备。更改系统设备后重新选择来源。独占输出、受保护音频和 ASIO 直通不一定会进入系统混音器；DAW 内请使用 VST3。

System audio uses WASAPI loopback on the default output; input uses the default recording endpoint. Reselect the source after changing devices. Exclusive, protected, and direct ASIO audio may bypass the Windows mixer; use the VST3 inside a DAW.

Windows 11 使用原生 Acrylic 窗口背景；Windows 10 使用兼容玻璃样式。Apple Liquid Glass 是 macOS 专属 API，Windows 的材质使用相同视觉方向的实现。音频文件由 Windows Media Foundation 解码，编码支持受系统版本影响。当前预览版没有 WLM DIAL/LM1 或响度矫正功能。

Windows 11 uses native Acrylic with a compatible glass style on Windows 10. Apple's Liquid Glass API is macOS-specific. File decoding uses Windows Media Foundation; codec availability depends on the OS. This preview does not include WLM DIAL/LM1 or audio correction.

此预览版未配置 Windows 代码签名证书，首次下载或运行可能遇到 SmartScreen 提示。

This preview is not Authenticode-signed, so Windows SmartScreen may show a first-run or download prompt.

## 从源码构建 / Build

Visual Studio 2022 C++ tools + Windows SDK, CMake 3.25+, Python + Pillow, Node.js, Git, Inno Setup 6.

```powershell
./scripts/bootstrap-windows.ps1
python -m pip install Pillow==11.3.0
cmake -S . -B build/windows -A x64
cmake --build build/windows --config Release --parallel
ctest --test-dir build/windows -C Release --output-on-failure
node Tests/windows_model_tests.js
./scripts/test-windows-gui.ps1
./scripts/package-windows.ps1
```

Yee Huang · yeehuang2002@163.com
