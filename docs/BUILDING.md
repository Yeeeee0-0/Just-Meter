# 本地构建 / Build from Source

在 Apple Silicon Mac 上构建。当前构建脚本使用 Apple Command Line Tools 27 / macOS 27 SDK，目标最低系统为 macOS 26。需要 Git、Python 3（含 pip）。脚本会将固定版本的依赖下载到项目内部，不需要全局安装 CMake。

Build on an Apple Silicon Mac. The current scripts use Apple Command Line Tools 27 / macOS 27 SDK, targeting macOS 26 or later. Git and Python 3 with pip are required. Dependencies are downloaded into the project; a global CMake installation is not required.

在仓库根目录依次运行 / Run from the repository root:

```sh
bash scripts/bootstrap.sh
bash scripts/build-app.sh
bash scripts/build-plugin.sh
bash scripts/test.sh
python3 scripts/build-installer.py
python3 Tests/installer_tests.py
```

首次准备依赖需要联网。编译和测试不会自动安装到系统目录或修改 DAW 的扫描缓存。

The initial dependency download requires internet access. Building and testing do not install to system directories or alter DAW scan caches.

## 输出 / Outputs

- `outputs/Just Meter.app`
- `outputs/Just Meter.vst3`
- `outputs/Just-Meter-0.1.3-macOS-arm64-preview.pkg`

本地构建采用临时签名。它不能替代 Developer ID 签名与 Apple 公证。

Local builds use ad-hoc signing. This does not replace Developer ID signing or Apple notarization.

## 依赖 / Dependencies

由 `scripts/bootstrap.sh` 固定 / Pinned by `scripts/bootstrap.sh`:

- libebur128: `67b33abe1558160ed76ada1322329b0e9e058b02`
- VST3 SDK 3.8.1: `3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96`
- CMake: `4.4.3`, installed under `build/tools`

## 结构 / Structure

- `Sources/DSP`: shared loudness, spectrum, history and CSV engine.
- `Sources/UI`: SwiftUI/AppKit views, localization, layouts and audio capture.
- `Sources/App`: standalone entry point, app icon and localized permission descriptions.
- `Sources/Plugin`: VST3 component and native editor integration.
- `Installer`: bilingual installer resources and app entitlements.
- `Tests`: numerical, layout, installer and native-host tests.
- `scripts`: dependency setup, build, packaging and release tools.

## 正式签名 / Developer ID Release

`scripts/release-macos.py` 支持为 App、VST3 和安装包签名，并提交 Apple 公证及附加公证票据。需要自己的 Developer ID Application / Installer 证书及钥匙串中的公证认证配置。证书、私钥和账号认证信息不应放进源码仓库。

`scripts/release-macos.py` signs the app, plug-in and installer, submits the package for Apple notarization and staples the ticket. It requires your own Developer ID Application / Installer identities and a notarytool Keychain profile. Keep certificates, private keys and authentication data outside the repository.

```sh
python3 scripts/release-macos.py \
  --application-identity 'Developer ID Application: YOUR NAME (TEAMID)' \
  --installer-identity 'Developer ID Installer: YOUR NAME (TEAMID)' \
  --notary-profile 'YOUR_KEYCHAIN_PROFILE'
```

该流程与 GitHub 预览版本发布分开；当前 0.1.3 预览包尚未完成正式签名或公证。

This workflow is separate from the GitHub preview release. The current 0.1.3 preview package is not Developer ID signed or notarized.
