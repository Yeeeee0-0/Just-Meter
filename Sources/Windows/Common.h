#pragma once
#include <windows.h>
#include <wrl.h>
#include <string>
#include <memory>
#include <stdexcept>
#include <filesystem>
#include <sstream>
namespace jm {
using Microsoft::WRL::ComPtr;
inline std::wstring wide(const std::string& s) {
    if(s.empty()) return {};
    int n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),int(s.size()),nullptr,0);
    if(!n) throw std::runtime_error("Invalid UTF-8");
    std::wstring r(n,L'\0');MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),int(s.size()),r.data(),n);return r;
}
inline std::string utf8(const std::wstring& s) {
    if(s.empty())return {};
    int n=WideCharToMultiByte(CP_UTF8,0,s.data(),int(s.size()),nullptr,0,nullptr,nullptr);
    std::string r(n,'\0');WideCharToMultiByte(CP_UTF8,0,s.data(),int(s.size()),r.data(),n,nullptr,nullptr);return r;
}
inline void check(HRESULT h,const char* operation) {
    if(FAILED(h)){std::ostringstream s;s<<operation<<" (0x"<<std::hex<<static_cast<unsigned long>(h)<<")";throw std::runtime_error(s.str());}
}
struct ComApartment {HRESULT result=CoInitializeEx(nullptr,COINIT_MULTITHREADED);~ComApartment(){if(SUCCEEDED(result))CoUninitialize();}};
}
