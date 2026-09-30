cmake_minimum_required(VERSION 3.25)
project(JustMeter VERSION 0.1.3 LANGUAGES C CXX)
set(CMAKE_OSX_DEPLOYMENT_TARGET "26.0")
set(CMAKE_OSX_ARCHITECTURES "arm64")
set(SMTG_ENABLE_VST3_PLUGIN_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SMTG_ENABLE_VST3_HOSTING_EXAMPLES ON CACHE BOOL "" FORCE)
set(SMTG_ENABLE_VSTGUI_SUPPORT OFF CACHE BOOL "" FORCE)
set(SMTG_CREATE_PLUGIN_LINK OFF CACHE BOOL "" FORCE)
set(SMTG_RUN_VST_VALIDATOR OFF CACHE BOOL "" FORCE)
set(SMTG_CREATE_MODULE_INFO OFF CACHE BOOL "" FORCE)
set(SMTG_ENABLE_AUV2_BUILDS OFF CACHE BOOL "" FORCE)
add_subdirectory(vendor/vst3sdk)
smtg_add_vst3plugin(JustMeter Sources/Plugin/JustMeter.cpp vendor/vst3sdk/public.sdk/source/vst/vstsinglecomponenteffect.cpp vendor/vst3sdk/public.sdk/source/main/macmain.cpp)
target_compile_features(JustMeter PRIVATE cxx_std_17)
target_include_directories(JustMeter PRIVATE Sources/DSP)
target_link_libraries(JustMeter PRIVATE sdk "${CMAKE_SOURCE_DIR}/build/libMeterCore.dylib" "${CMAKE_SOURCE_DIR}/build/libMeterUI.dylib")
set_target_properties(JustMeter PROPERTIES BUILD_RPATH "@loader_path/../Frameworks" INSTALL_RPATH "@loader_path/../Frameworks" BUILD_WITH_INSTALL_RPATH TRUE)
smtg_target_set_bundle(JustMeter BUNDLE_IDENTIFIER "studio.justmeter.vst3" COMPANY_NAME "Just Meter")
# The SDK only sets these for the Xcode generator. Our command-line build
# also needs a stable identity and version for signing and installer upgrades.
set_target_properties(JustMeter PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "studio.justmeter.vst3"
    MACOSX_BUNDLE_BUNDLE_NAME "Just Meter"
    MACOSX_BUNDLE_BUNDLE_VERSION "4"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_INFO_STRING "Just Meter ${PROJECT_VERSION}"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Sources/Plugin/Info.plist.in")
add_executable(IntegrationHost MACOSX_BUNDLE Tests/plugin_host.mm)
target_compile_features(IntegrationHost PRIVATE cxx_std_17)
target_compile_options(IntegrationHost PRIVATE -fobjc-arc)
target_include_directories(IntegrationHost PRIVATE vendor/vst3sdk)
target_link_libraries(IntegrationHost PRIVATE sdk sdk_hosting "-framework Cocoa" "-framework CoreFoundation")
set_target_properties(IntegrationHost PROPERTIES MACOSX_BUNDLE_GUI_IDENTIFIER "studio.justmeter.testhost")
