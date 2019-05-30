#import "handmade_types.h"
#import "AppKit/Appkit.h"

struct MacOSSoundBuffer {
    int samplesPerSecond; 
    int sampleCount;
    int16* samples; 
    uint32 bufferSize;
    int16* coreAudioBuffer;
    int16* readCursor;
    int16* writeCursor;
};

extern bool running;
void macOSRefreshBuffer(NSWindow *window);
void renderWeirdGradient();
void macOSRedrawBuffer(NSWindow *window);
