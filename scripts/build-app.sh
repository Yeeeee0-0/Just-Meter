#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/outputs/Just Meter.app"
mkdir -p build/objects build/module-cache "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
export CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache"
clang -O3 -fPIC -mmacosx-version-min=26.0 -c vendor/libebur128/ebur128/ebur128.c -o build/objects/ebur128.o
clang++ -std=c++17 -O3 -fPIC -mmacosx-version-min=26.0 -I vendor/libebur128/ebur128 -dynamiclib Sources/DSP/MeterCore.cpp build/objects/ebur128.o -install_name @rpath/libMeterCore.dylib -o build/libMeterCore.dylib
cp build/libMeterCore.dylib "$APP/Contents/Frameworks/"
swiftc -swift-version 5 -O -target arm64-apple-macos26.0 -module-cache-path build/module-cache -import-objc-header Sources/DSP/MeterCore.h Sources/UI/Localization.swift Sources/UI/SystemAudioCapture.swift Sources/UI/Models.swift Sources/UI/MeterView.swift Sources/UI/SettingsView.swift Sources/App/main.swift -L build -lMeterCore -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$APP/Contents/MacOS/JustMeter"
python3 scripts/package.py
codesign --force --sign - "$APP/Contents/Frameworks/libMeterCore.dylib"
codesign --force --sign - "$APP"
