#pragma once
#include "Common.h"
#include "AudioCapture.h"
#include "WebView2.h"
#include "json.hpp"
#include <memory>
namespace jm {
class Editor:public std::enable_shared_from_this<Editor>{
    HWND window=nullptr;
    HMODULE module=nullptr;
    JMHandle engine=nullptr;
    bool plugin=false,ownsEngine=false,ready=false,comInitialized=false;
    std::unique_ptr<AudioCapture> audio;
    ComPtr<ICoreWebView2Controller> controller;
    ComPtr<ICoreWebView2> web;
    nlohmann::json preferences=nlohmann::json::object();
    std::filesystem::path settingsPath;
    uint64_t version=0;
    unsigned ticks=0;
    nlohmann::json history=nlohmann::json::array();
    std::wstring smokePath;
    bool smokeStarted=false,allowEmbeddedNavigation=false;
    std::string startupStage="window";
    Editor(JMHandle handle,bool isPlugin);
    void initializeBrowser();
    void browserFailure(HRESULT error);
    void receive(const std::wstring& message);
    void send(const nlohmann::json& message);
    void sendState();
    void refresh();
    void persist();
    void restore();
    void appearance();
    void fileDialog(bool save);
    void showError(const std::string& message);
    static LRESULT CALLBACK procedure(HWND,UINT,WPARAM,LPARAM);
public:
    static std::shared_ptr<Editor> create(JMHandle handle,bool plugin);
    ~Editor();
    HWND attach(HWND parent=nullptr);
    void resize(int width,int height);
    void analyze(const std::wstring& path);
    void setSmokePath(const std::wstring& path){smokePath=path;}
};
}
