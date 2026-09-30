#include "Editor.h"
#include <dwmapi.h>
#include <shlobj.h>
#include <commdlg.h>
#include <fstream>
#include <iterator>
#include <array>
#include <cmath>
using Microsoft::WRL::Callback;
namespace jm {
using json=nlohmann::json;
namespace {
void moduleAnchor(){}
std::filesystem::path userFolder(){PWSTR p=nullptr;check(SHGetKnownFolderPath(FOLDERID_LocalAppData,KF_FLAG_CREATE,nullptr,&p),"Open application data folder");std::filesystem::path result=std::filesystem::path(p)/L"Just Meter";CoTaskMemFree(p);std::filesystem::create_directories(result);return result;}
bool systemChinese(){wchar_t language[LOCALE_NAME_MAX_LENGTH]{};GetUserDefaultLocaleName(language,LOCALE_NAME_MAX_LENGTH);return wcsncmp(language,L"zh",2)==0;}
template<class T>T preference(const json& p,const char* key,T fallback){try{auto i=p.find(key);return i!=p.end()&&!i->is_null()?i->get<T>():fallback;}catch(...){return fallback;}}
json readJSON(const std::filesystem::path& path){std::error_code error;if(!std::filesystem::exists(path,error)||std::filesystem::file_size(path,error)>1048576)return json::object();std::ifstream f(path,std::ios::binary);auto value=json::parse(f,nullptr,false);return value.is_object()?value:json::object();}
}
Editor::Editor(JMHandle handle,bool isPlugin):engine(handle?handle:jm_create()),plugin(isPlugin),ownsEngine(!handle){
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,reinterpret_cast<LPCWSTR>(&moduleAnchor),&module);
    settingsPath=userFolder()/(plugin?L"plugin-preferences.json":L"app-preferences.json");preferences=readJSON(settingsPath);
    if(plugin)restore();else audio=std::make_unique<AudioCapture>(engine);
}
std::shared_ptr<Editor> Editor::create(JMHandle handle,bool plugin){return std::shared_ptr<Editor>(new Editor(handle,plugin));}
Editor::~Editor(){if(audio)audio->stop();if(window)KillTimer(window,1);if(controller)controller->Close();web.Reset();controller.Reset();if(window){SetWindowLongPtrW(window,GWLP_USERDATA,0);DestroyWindow(window);}if(ownsEngine)jm_destroy(engine);if(comInitialized)CoUninitialize();}
HWND Editor::attach(HWND parent){
    if(window)return window;
    HRESULT com=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);check(com,"The plug-in editor requires a Windows STA UI thread");comInitialized=SUCCEEDED(com);
    WNDCLASSEXW wc{sizeof(wc)};wc.hInstance=module;wc.lpfnWndProc=procedure;wc.lpszClassName=L"JustMeter.Editor.Window";wc.hCursor=LoadCursorW(nullptr,IDC_ARROW);wc.hIcon=LoadIconW(module,MAKEINTRESOURCEW(101));wc.hIconSm=wc.hIcon;RegisterClassExW(&wc);
    DWORD style=plugin?(WS_CHILD|WS_VISIBLE|WS_CLIPCHILDREN|WS_CLIPSIBLINGS):(WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN);
    RECT r{0,0,1000,plugin?760:780};if(!plugin)AdjustWindowRectEx(&r,style,FALSE,0);
    window=CreateWindowExW(0,wc.lpszClassName,L"Just Meter",style,plugin?0:CW_USEDEFAULT,plugin?0:CW_USEDEFAULT,r.right-r.left,r.bottom-r.top,parent,nullptr,module,this);
    if(!window)throw std::runtime_error("Unable to create Just Meter window");
    appearance();ShowWindow(window,SW_SHOW);initializeBrowser();SetTimer(window,1,50,nullptr);return window;
}
LRESULT CALLBACK Editor::procedure(HWND hwnd,UINT msg,WPARAM w,LPARAM l){
    Editor* e=reinterpret_cast<Editor*>(GetWindowLongPtrW(hwnd,GWLP_USERDATA));
    if(msg==WM_NCCREATE){e=static_cast<Editor*>(reinterpret_cast<CREATESTRUCTW*>(l)->lpCreateParams);SetWindowLongPtrW(hwnd,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(e));e->window=hwnd;}
    if(!e)return DefWindowProcW(hwnd,msg,w,l);
    switch(msg){
    case WM_SIZE:if(e->controller){RECT r;GetClientRect(hwnd,&r);e->controller->put_Bounds(r);}return 0;
    case WM_TIMER:if(w==1)e->refresh();return 0;
    case WM_SETTINGCHANGE:case WM_THEMECHANGED:e->appearance();break;
    case WM_DPICHANGED:if(!e->plugin){auto*r=reinterpret_cast<RECT*>(l);SetWindowPos(hwnd,nullptr,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE);}return 0;
    case WM_GETMINMAXINFO:if(!e->plugin){const UINT dpi=GetDpiForWindow(hwnd);auto*m=reinterpret_cast<MINMAXINFO*>(l);m->ptMinTrackSize={MulDiv(780,dpi,96),MulDiv(660,dpi,96)};}return 0;
    case WM_ERASEBKGND:return 1;
    case WM_PAINT:{PAINTSTRUCT ps;HDC dc=BeginPaint(hwnd,&ps);if(!e->ready){FillRect(dc,&ps.rcPaint,GetSysColorBrush(COLOR_WINDOW));RECT r;GetClientRect(hwnd,&r);SetBkMode(dc,TRANSPARENT);DrawTextW(dc,L"Just Meter",-1,&r,DT_CENTER|DT_VCENTER|DT_SINGLELINE);}EndPaint(hwnd,&ps);return 0;}
    case WM_CLOSE:DestroyWindow(hwnd);return 0;
    case WM_DESTROY:KillTimer(hwnd,1);if(e->audio)e->audio->stop();if(e->controller)e->controller->Close();e->window=nullptr;if(!e->plugin)PostQuitMessage(0);return 0;
    }return DefWindowProcW(hwnd,msg,w,l);
}
void Editor::resize(int width,int height){if(window)SetWindowPos(window,nullptr,0,0,width,height,SWP_NOZORDER|SWP_NOACTIVATE);}
void Editor::browserFailure(HRESULT result){std::string message="Just Meter requires Microsoft Edge WebView2 Runtime. Run the Just Meter installer to install it. / 请运行 Just Meter 安装器安装 Microsoft Edge WebView2 运行时。";std::ostringstream s;s<<message<<"\n0x"<<std::hex<<static_cast<unsigned long>(result);showError(s.str());}
void Editor::initializeBrowser(){
    auto weak=weak_from_this();const auto cache=userFolder()/L"WebView2";
    HRESULT started=CreateCoreWebView2EnvironmentWithOptions(nullptr,cache.c_str(),nullptr,Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>([weak](HRESULT hr,ICoreWebView2Environment* env)->HRESULT{
        auto self=weak.lock();if(!self||!self->window)return S_OK;if(FAILED(hr)||!env){self->browserFailure(hr);return S_OK;}
        return env->CreateCoreWebView2Controller(self->window,Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>([weak](HRESULT result,ICoreWebView2Controller* control)->HRESULT{
            auto e=weak.lock();if(!e||!e->window)return S_OK;if(FAILED(result)||!control){e->browserFailure(result);return S_OK;}e->controller=control;control->get_CoreWebView2(&e->web);if(!e->web){e->browserFailure(E_FAIL);return S_OK;}
            RECT r;GetClientRect(e->window,&r);control->put_Bounds(r);control->put_IsVisible(TRUE);
            ComPtr<ICoreWebView2Controller2> transparent;if(SUCCEEDED(control->QueryInterface(IID_PPV_ARGS(&transparent))))transparent->put_DefaultBackgroundColor(COREWEBVIEW2_COLOR{0,0,0,0});
            ComPtr<ICoreWebView2Settings> settings;e->web->get_Settings(&settings);settings->put_AreDefaultContextMenusEnabled(FALSE);settings->put_AreDevToolsEnabled(FALSE);settings->put_IsStatusBarEnabled(FALSE);settings->put_IsZoomControlEnabled(FALSE);settings->put_AreDefaultScriptDialogsEnabled(FALSE);
            EventRegistrationToken token{};
            e->web->add_WebMessageReceived(Callback<ICoreWebView2WebMessageReceivedEventHandler>([weak](ICoreWebView2*,ICoreWebView2WebMessageReceivedEventArgs* args)->HRESULT{auto e=weak.lock();if(!e||!e->window)return S_OK;LPWSTR raw=nullptr;if(SUCCEEDED(args->get_WebMessageAsJson(&raw))&&raw){std::wstring message(raw);CoTaskMemFree(raw);try{e->receive(message);}catch(const std::exception&error){e->showError(error.what());}}return S_OK;}).Get(),&token);
            e->web->add_NavigationStarting(Callback<ICoreWebView2NavigationStartingEventHandler>([](ICoreWebView2*,ICoreWebView2NavigationStartingEventArgs* args)->HRESULT{LPWSTR uri=nullptr;args->get_Uri(&uri);if(!uri||wcscmp(uri,L"about:blank")!=0)args->put_Cancel(TRUE);CoTaskMemFree(uri);return S_OK;}).Get(),&token);
            e->web->add_NewWindowRequested(Callback<ICoreWebView2NewWindowRequestedEventHandler>([](ICoreWebView2*,ICoreWebView2NewWindowRequestedEventArgs* args)->HRESULT{args->put_Handled(TRUE);return S_OK;}).Get(),&token);
            e->web->add_PermissionRequested(Callback<ICoreWebView2PermissionRequestedEventHandler>([](ICoreWebView2*,ICoreWebView2PermissionRequestedEventArgs* args)->HRESULT{args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY);return S_OK;}).Get(),&token);
            auto resource=FindResourceW(e->module,MAKEINTRESOURCEW(102),RT_RCDATA);if(!resource){e->showError("Embedded interface is missing");return S_OK;}auto data=LoadResource(e->module,resource);auto bytes=static_cast<const char*>(LockResource(data));const auto html=wide(std::string(bytes,SizeofResource(e->module,resource)));e->web->NavigateToString(html.c_str());return S_OK;
        }).Get());
    }).Get());
    if(FAILED(started))browserFailure(started);
}
void Editor::send(const json& message){if(web&&window)web->PostWebMessageAsJson(wide(message.dump()).c_str());}
void Editor::sendState(){send({{"type","state"},{"plugin",plugin},{"language",systemChinese()?"zh-Hans":"en"},{"preferences",preferences}});}
void Editor::restore(){const int n=jm_get_state(engine,nullptr,0);if(n>0&&n<=1048576){std::string data(n,'\0');if(jm_get_state(engine,data.data(),n)==n){auto saved=json::parse(data,nullptr,false);if(saved.is_object())preferences=saved;}}version=jm_state_version(engine);preferences["followTransport"]=jm_follow_transport(engine)!=0;}
void Editor::persist(){
    const std::string data=preferences.dump();if(data.size()>1048576)throw std::runtime_error("Layout data is too large");
    auto temporary=settingsPath;temporary+=L"."+std::to_wstring(GetCurrentProcessId())+L"."+std::to_wstring(reinterpret_cast<uintptr_t>(this))+L".tmp";
    {std::ofstream out(temporary,std::ios::binary|std::ios::trunc);out<<data;out.flush();if(!out)throw std::runtime_error("Unable to save preferences");}
    if(!MoveFileExW(temporary.c_str(),settingsPath.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))throw std::runtime_error("Unable to replace preferences");
    if(plugin){jm_set_state(engine,data.data(),int(data.size()));jm_set_follow_transport(engine,preference(preferences,"followTransport",true));version=jm_state_version(engine);}appearance();
}
void Editor::appearance(){if(!window)return;DWORD light=1,size=sizeof(light);RegGetValueW(HKEY_CURRENT_USER,L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",L"AppsUseLightTheme",RRF_RT_REG_DWORD,nullptr,&light,&size);const auto theme=preference(preferences,"theme",std::string("system"));BOOL dark=theme=="dark"||(theme=="system"&&!light);if(!plugin){DwmSetWindowAttribute(window,20,&dark,sizeof(dark));HIGHCONTRASTW contrast{sizeof(contrast)};SystemParametersInfoW(SPI_GETHIGHCONTRAST,sizeof(contrast),&contrast,0);const double transparency=preference(preferences,"transparency",35.0);int backdrop=transparency>0&&!(contrast.dwFlags&HCF_HIGHCONTRASTON)?3:1;DwmSetWindowAttribute(window,38,&backdrop,sizeof(backdrop));MARGINS margin=backdrop==3?MARGINS{-1,-1,-1,-1}:MARGINS{};DwmExtendFrameIntoClientArea(window,&margin);SetWindowPos(window,preference(preferences,"pinned",false)?HWND_TOPMOST:HWND_NOTOPMOST,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE);}}
void Editor::fileDialog(bool save){
    wchar_t path[32768]=L"Just Meter.csv";if(!save)path[0]=0;
    const bool chinese=preference(preferences,"interfaceLanguage",std::string(systemChinese()?"zh-Hans":"en"))=="zh-Hans";
    OPENFILENAMEW dialog{sizeof(dialog)};dialog.hwndOwner=window;dialog.lpstrFile=path;dialog.nMaxFile=32768;dialog.Flags=OFN_EXPLORER|OFN_NOCHANGEDIR|OFN_PATHMUSTEXIST|(save?OFN_OVERWRITEPROMPT:OFN_FILEMUSTEXIST);
    dialog.lpstrTitle=save?(chinese?L"导出 CSV":L"Export CSV"):(chinese?L"分析音频文件":L"Analyze Audio File");dialog.lpstrDefExt=save?L"csv":nullptr;
    dialog.lpstrFilter=save?L"CSV (*.csv)\0*.csv\0\0":L"Audio / 音频\0*.wav;*.aif;*.aiff;*.mp3;*.m4a;*.aac;*.flac;*.wma\0All files / 所有文件\0*.*\0\0";
    if(save){if(GetSaveFileNameW(&dialog)&&!jm_write_csv(engine,utf8(path).c_str()))showError(chinese?"无法写入日志文件。":"Unable to write the log file.");}else if(GetOpenFileNameW(&dialog)&&audio)audio->startFile(path);
}
void Editor::showError(const std::string& message){if(ready)send({{"type","error"},{"message",message}});else if(window)MessageBoxW(window,wide(message).c_str(),L"Just Meter",MB_OK|MB_ICONERROR);}
void Editor::analyze(const std::wstring& path){if(audio)audio->startFile(path);}
void Editor::receive(const std::wstring& raw){if(raw.size()>1048576)return;const auto message=json::parse(utf8(raw),nullptr,false);if(!message.is_object())return;const auto type=message.value("type",std::string());
    if(type=="ready"){ready=true;sendState();refresh();}
    else if(type=="preferences"&&message.contains("value")&&message["value"].is_object()){preferences=message["value"];persist();}
    else if(type=="pause"){JMSnapshot s{};jm_snapshot(engine,&s);jm_pause(engine,!s.paused);}
    else if(type=="reset")jm_reset(engine);
    else if(type=="clear-peak")jm_clear_peak(engine);
    else if(type=="export")fileDialog(true);
    else if(type=="file"&&!plugin)fileDialog(false);
    else if(type=="system"&&audio)audio->startSystem();
    else if(type=="input"&&audio)audio->startInput();
    else if(type=="disconnect"&&audio)audio->stop();
    else if(type=="email")ShellExecuteW(window,L"open",L"mailto:yeehuang2002@163.com",nullptr,nullptr,SW_SHOWNORMAL);
}
void Editor::refresh(){if(!ready||!web)return;try{
    if(plugin&&jm_state_version(engine)!=version){restore();appearance();sendState();}
    JMSnapshot s{};jm_snapshot(engine,&s);std::array<float,64>spectrum;std::array<float,256>vectors;jm_spectrum(engine,spectrum.data());jm_vectors(engine,vectors.data());
    if(ticks++%5==0){std::array<JMHistory,720> buffer;const int n=jm_history(engine,buffer.data(),int(buffer.size()));history=json::array();for(int i=0;i<n;++i){const auto&h=buffer[i];history.push_back({{"time",h.time},{"momentary",h.momentary},{"shortTerm",h.shortTerm},{"integrated",h.integrated},{"truePeak",h.truePeak}});}}
    json snapshot={{"integrated",s.integrated},{"momentary",s.momentary},{"shortTerm",s.shortTerm},{"range",s.range},{"maxMomentary",s.maxMomentary},{"truePeak",s.truePeak},{"samplePeak",s.samplePeak},{"seconds",s.seconds},{"correlation",s.correlation},{"balance",s.balance},{"sampleRate",s.sampleRate},{"channels",s.channels},{"active",s.active},{"paused",s.paused},{"droppedFrames",s.droppedFrames}};
    SourceStatus status;if(audio)status=audio->snapshot();
    send({{"type","meter"},{"snapshot",snapshot},{"spectrum",spectrum},{"vectors",vectors},{"history",history},{"source",{{"source",status.source},{"file",status.file},{"error",status.error},{"rate",status.rate},{"channels",status.channels},{"running",status.running},{"progress",status.progress}}}});
    if(!smokePath.empty()&&!smokeStarted&&ticks>30){smokeStarted=true;auto weak=weak_from_this();web->ExecuteScript(L"JSON.stringify({ready:!!document.querySelector('#grid'),widgets:document.querySelectorAll('.widget').length,title:document.title,source:document.querySelector('.source')?.textContent,errors:typeof JMModel==='undefined'})",Callback<ICoreWebView2ExecuteScriptCompletedHandler>([weak](HRESULT hr,LPCWSTR raw)->HRESULT{if(auto e=weak.lock()){json report={{"webview",SUCCEEDED(hr)},{"result",raw?utf8(raw):""}};std::ofstream(std::filesystem::path(e->smokePath))<<report.dump(2);PostMessageW(e->window,WM_CLOSE,0,0);}return S_OK;}).Get());}
    }catch(const std::exception&e){showError(e.what());}
}
}
extern "C" {
void* jm_create_editor(void* handle){try{return new std::shared_ptr<jm::Editor>(jm::Editor::create(handle,true));}catch(...){return nullptr;}}
void jm_destroy_editor(void* editor){delete static_cast<std::shared_ptr<jm::Editor>*>(editor);}
void jm_attach_editor(void* editor,void* parent){if(editor)try{(*static_cast<std::shared_ptr<jm::Editor>*>(editor))->attach(static_cast<HWND>(parent));}catch(const std::exception&e){MessageBoxW(static_cast<HWND>(parent),jm::wide(e.what()).c_str(),L"Just Meter",MB_OK|MB_ICONERROR);}}
void jm_resize_editor(void* editor,int32_t width,int32_t height){if(editor)(*static_cast<std::shared_ptr<jm::Editor>*>(editor))->resize(width,height);}
}
