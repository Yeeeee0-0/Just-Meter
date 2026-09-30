#include "Editor.h"
#include <shellapi.h>
#include <fstream>
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR,int){
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    std::wstring smoke;
    try{
        int count=0;LPWSTR* args=CommandLineToArgvW(GetCommandLineW(),&count);std::wstring file;
        for(int i=1;i<count;++i){if(wcscmp(args[i],L"--analyze")==0&&i+1<count)file=args[++i];else if(wcscmp(args[i],L"--smoke-test")==0&&i+1<count)smoke=args[++i];else if(i==1)file=args[i];}LocalFree(args);
        auto editor=jm::Editor::create(nullptr,false);editor->setSmokePath(smoke);
        editor->attach();if(!file.empty())editor->analyze(file);
        MSG message{};while(GetMessageW(&message,nullptr,0,0)>0){TranslateMessage(&message);DispatchMessageW(&message);}return 0;
    }catch(const std::exception&e){if(!smoke.empty()){std::ofstream(std::filesystem::path(smoke))<<nlohmann::json({{"fatal",e.what()}}).dump(2);return 1;}MessageBoxW(nullptr,jm::wide(e.what()).c_str(),L"Just Meter",MB_OK|MB_ICONERROR);return 1;}
}
