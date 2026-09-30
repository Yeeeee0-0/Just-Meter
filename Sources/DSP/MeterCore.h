#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef void* JMHandle;
typedef struct {
    double integrated, momentary, shortTerm, range, maxMomentary;
    double truePeak, samplePeak, seconds, correlation, balance;
    double leftPeak, rightPeak, sampleRate;
    uint64_t droppedFrames;
    int channels, active, paused;
} JMSnapshot;
typedef struct { double time, momentary, shortTerm, integrated, truePeak; } JMHistory;
JMHandle jm_create(void);
void jm_destroy(JMHandle);
// One producer per engine. The audio callback only copies into a bounded SPSC queue.
int jm_feed(JMHandle, const float* const* channels, int count, int frames, double rate);
int jm_feed_interleaved(JMHandle, const float*, int channels, int frames, double rate);
int jm_queue_available(JMHandle);
void jm_wait_idle(JMHandle);
void jm_reset(JMHandle);
void jm_pause(JMHandle, int);
void jm_clear_peak(JMHandle);
void jm_snapshot(JMHandle, JMSnapshot*);
void jm_spectrum(JMHandle, float* output64);
void jm_vectors(JMHandle, float* output256);
int jm_history(JMHandle, JMHistory*, int capacity);
int jm_write_csv(JMHandle, const char* path);
int jm_get_state(JMHandle, char* output, int capacity);
void jm_set_state(JMHandle, const char* input, int length);
uint64_t jm_state_version(JMHandle);
void jm_set_follow_transport(JMHandle, int);
int jm_follow_transport(JMHandle);
#ifdef __cplusplus
}
#endif
