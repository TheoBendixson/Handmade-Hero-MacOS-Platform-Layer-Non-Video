#include "../cpp/code/handmade.cpp"
#import <AppKit/AppKit.h>

struct MacOSSoundOutput {
    int samplesPerSecond; 
    int bytesPerSample;
    uint32 runningSampleIndex;
    uint32 bufferSize;
    uint32 writeCursor;
    uint32 playCursor;
    void *data;
};
