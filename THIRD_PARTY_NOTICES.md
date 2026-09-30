# Third-Party Notices / 第三方说明

Just Meter is released under the MIT License. Dependencies retain their respective copyrights and licenses.

Just Meter 采用 MIT 许可证；第三方依赖保留各自版权及许可证。

## libebur128

- Project: https://github.com/jiixyj/libebur128
- Commit: `67b33abe1558160ed76ada1322329b0e9e058b02`
- License: MIT
- Copyright (c) 2011 Jan Kokemüller
- License file: `vendor/libebur128/COPYING` after bootstrapping; `Contents/Resources/Licenses/libebur128-MIT.txt` in the app and plug-in.

## Steinberg VST3 SDK

- Project: https://github.com/steinbergmedia/vst3sdk
- Version: 3.8.1
- Commit: `3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96`
- License: MIT
- Copyright (c) 2026 Steinberg Media Technologies GmbH
- License file: `vendor/vst3sdk/LICENSE.txt` after bootstrapping; `Contents/Resources/Licenses/VST3-SDK-MIT.txt` in the plug-in.

The dependency sources are fetched by `scripts/bootstrap.sh`, rather than copied into this repository. Their complete license texts accompany the distributed binaries.

依赖源码由 `scripts/bootstrap.sh` 获取，不在本仓库重复存放。完整许可文本随编译产物分发。

## Windows dependencies

- Microsoft WebView2 SDK 1.0.3650.58: https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.3650.58. Microsoft license; complete SDK terms accompany Windows binaries. The bundled Evergreen Runtime is distributed under Microsoft's runtime redistribution terms and retains its own installer and license.
- nlohmann/json 3.12.0: https://github.com/nlohmann/json, MIT, copyright Niels Lohmann. Complete license included in Windows packages.
- Inno Setup: https://jrsoftware.org/, installer compiler. Simplified Chinese messages maintained by Zhenghan Yang (Kira): https://github.com/kira-96/Inno-Setup-Chinese-Simplified-Translation. Translation attribution is preserved in the fetched source.

Windows dependency setup: `scripts/bootstrap-windows.ps1`. Windows binaries and installer include the complete license texts in `Licenses/`.
