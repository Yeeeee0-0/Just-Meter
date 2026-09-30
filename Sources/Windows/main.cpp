#include "Editor.h"
#include <shellapi.h>
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR,int){
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    try{
        auto editor=jm::Editor::create(nullptr,false);
        int count=0;LPWSTR* args=CommandLineToArgvW(GetCommandLineW(),&count);std::wstring file;
        for(int i=1;i<count;++i){if(wcscmp(args[i],L"--analyze")==0&&i+1<count)file=args[++i];else if(wcscmp(args[i],L"--smoke-test")==0&&i+1<count)editor->setSmokePath(args[++i]);else if(i==1)file=args[i];}LocalFree(args);
        editor->attach();if(!file.empty())editor->analyze(file);
        MSG message{};while(GetMessageW(&message,nullptr,0,0)>0){TranslateMessage(&message);DispatchMessageW(&message);}return 0;
    }catch(const std::exception&e){MessageBoxW(nullptr,jm::wide(e.what()).c_str(),L"Just Meter",MB_OK|MB_ICONERROR);return 1;}
}
