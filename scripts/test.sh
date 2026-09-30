#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
clang++ -std=c++17 -O2 -I Sources/DSP Tests/meter_tests.cpp -L build -lMeterCore -Wl,-rpath,@executable_path -o build/meter_tests
build/meter_tests | tee build/dsp-tests.log
swiftc -swift-version 5 -O -target arm64-apple-macos26.0 -module-cache-path build/module-cache -import-objc-header Sources/DSP/MeterCore.h Sources/UI/Localization.swift Sources/UI/SystemAudioCapture.swift Sources/UI/Models.swift Sources/UI/MeterView.swift Sources/UI/SettingsView.swift Tests/layout_tests.swift -L build -lMeterCore -Xlinker -rpath -Xlinker @executable_path -o build/layout_tests
build/layout_tests | tee build/layout-tests.log
build/vst/bin/Release/validator 'outputs/Just Meter.vst3' > build/vst3-validation.log
rg 'Result:|failed' build/vst3-validation.log
codesign --verify --deep --strict 'outputs/Just Meter.app'
codesign --verify --deep --strict 'outputs/Just Meter.vst3'
