#import "handmade_types.h"
#import <AppKit/AppKit.h>

struct MacOSSoundOutput {
    int samplesPerSecond; 
    int bytesPerSample;
    int toneHz;
    int wavePeriod;
    real32 tSine;
    uint32 bufferSize;
    uint32 writeCursor;
    uint32 playCursor;
    void *data;
};
