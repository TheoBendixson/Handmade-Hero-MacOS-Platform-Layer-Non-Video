#include "../cpp/code/handmade.cpp"
#import <AppKit/AppKit.h>

struct MacOSSoundOutput {
    uint32 samplesPerSecond; 
    uint32 bytesPerSample;
    uint32 runningSampleIndex;
    uint32 bufferSize;
    uint32 safetyBytes;
    uint32 writeCursor;
    uint32 playCursor;
    void *data;
};

struct MacOSDebugTimeMarker {
    uint32 outputPlayCursor;
    uint32 outputWriteCursor;
    uint32 outputLocation;
    uint32 outputByteCount;
    uint32 expectedFlipPlayCursor;
    uint32 flipWriteCursor;
    uint32 flipPlayCursor;
};
