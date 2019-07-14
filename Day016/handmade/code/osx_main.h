#include "../cpp/code/handmade.cpp"
#import <AppKit/AppKit.h>

struct MacOSSoundOutput {
    uint32 samplesPerSecond; 
    uint32 bytesPerSample;
    uint32 runningSampleIndex;
    uint32 bufferSize;
    uint32 writeCursor;
    uint32 playCursor;
    void *data;
};
