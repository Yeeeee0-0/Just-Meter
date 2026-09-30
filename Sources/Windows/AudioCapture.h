#pragma once
#include "MeterCore.h"
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
namespace jm {
struct SourceStatus {std::string source="idle",file,error;double progress=-1,rate=0;int channels=0;bool running=false;};
class AudioCapture {
    JMHandle engine;
    std::atomic<bool> cancelled{false};
    std::thread worker;
    std::mutex mutex;
    SourceStatus status;
    void prepare(const char* source);
    void capture(bool loopback);
    void analyze(const std::wstring& path);
    void failure(const std::exception& e);
public:
    explicit AudioCapture(JMHandle handle):engine(handle){}
    ~AudioCapture(){stop();}
    void startSystem();
    void startInput();
    void startFile(const std::wstring& path);
    void stop();
    SourceStatus snapshot();
};
}
