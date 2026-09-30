#include "AudioCapture.h"
#include "Common.h"
#include <cassert>
#include <cmath>
#include <iostream>
#include <chrono>
int wmain(int argc,wchar_t**argv){
    assert(argc==2);auto h=jm_create();
    {
        jm::AudioCapture audio(h);audio.startFile(argv[1]);
        const auto limit=std::chrono::steady_clock::now()+std::chrono::seconds(40);
        while(audio.snapshot().running&&std::chrono::steady_clock::now()<limit)Sleep(20);
        const auto source=audio.snapshot();if(!source.error.empty())std::cerr<<source.error<<std::endl;
        assert(source.error.empty()&&!source.running&&source.source=="complete");
        JMSnapshot s{};jm_snapshot(h,&s);assert(std::abs(s.integrated+20)<.15);assert(std::abs(s.truePeak+20)<.15);assert(s.seconds>5&&s.droppedFrames==0);
        auto path=std::filesystem::temp_directory_path()/L"Just Meter 中文测量.csv";
        assert(jm_write_csv(h,jm::utf8(path.wstring()).c_str())==1);assert(std::filesystem::file_size(path)>200);std::filesystem::remove(path);
        audio.startFile(L"Z:\\missing-Just-Meter-input.wav");
        for(int i=0;i<200&&audio.snapshot().running;++i)Sleep(20);
        assert(!audio.snapshot().error.empty());audio.stop();assert(audio.snapshot().source=="disconnected");
        audio.startFile(argv[1]);audio.stop();assert(!audio.snapshot().running);
        std::cout<<"PASS: Media Foundation, loudness, true peak, Unicode CSV, invalid file, cancellation\n";
    }
    jm_destroy(h);
}
