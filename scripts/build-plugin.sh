#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
swiftc -swift-version 5 -O -target arm64-apple-macos26.0 -module-cache-path build/module-cache -import-objc-header Sources/DSP/MeterCore.h -emit-library -module-name JustMeterUI Sources/UI/*.swift -L build -lMeterCore -Xlinker -install_name -Xlinker @rpath/libMeterUI.dylib -Xlinker -rpath -Xlinker @loader_path -o build/libMeterUI.dylib
env XCODE_VERSION=27.0 build/tools/cmake/data/bin/cmake -S . -B build/vst -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 -DXCODE_VERSION=27.0
build/tools/cmake/data/bin/cmake --build build/vst --target JustMeter validator -j 6
PLUGIN="$ROOT/outputs/Just Meter.vst3"
ditto build/vst/VST3/Release/JustMeter.vst3 "$PLUGIN"
mkdir -p "$PLUGIN/Contents/Frameworks"
cp build/libMeterCore.dylib build/libMeterUI.dylib "$PLUGIN/Contents/Frameworks/"
mkdir -p "$PLUGIN/Contents/Resources/Licenses"
cp vendor/libebur128/COPYING "$PLUGIN/Contents/Resources/Licenses/libebur128-MIT.txt"
cp vendor/vst3sdk/LICENSE.txt "$PLUGIN/Contents/Resources/Licenses/VST3-SDK-MIT.txt"
cp LICENSE "$PLUGIN/Contents/Resources/Licenses/Just-Meter-MIT.txt"
codesign --force --sign - "$PLUGIN/Contents/Frameworks/libMeterCore.dylib"
codesign --force --sign - "$PLUGIN/Contents/Frameworks/libMeterUI.dylib"
codesign --force --sign - "$PLUGIN"
