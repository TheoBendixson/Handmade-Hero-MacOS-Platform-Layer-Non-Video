#import "handmade_types.h"
#import <AppKit/AppKit.h>

struct MacOSSoundOutput {
    int samplesPerSecond; 
    uint32 bufferSize;
    uint32 tonehz;
    int bytesPerSample;
    int16* coreAudioBuffer;
    int16* readCursor;
    int16* writeCursor;
};
