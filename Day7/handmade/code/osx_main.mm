// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#import "handmade_types.h"
#import "osx_main.h"
#import "osx_handmade_windows.h"
#import "osx_handmade_controllers.h"

#import <AppKit/AppKit.h>
#import <AudioToolbox/AudioToolbox.h>

global_variable float globalRenderWidth = 1024;
global_variable float globalRenderHeight = 768;

global_variable uint8 *buffer;
global_variable int bitmapWidth;
global_variable int bitmapHeight;
global_variable int bytesPerPixel = 4;
global_variable int pitch;

global_variable int offsetX = 0;
global_variable int offsetY = 0;

bool running = true;

void macOSRefreshBuffer(NSWindow *window) {

    if (buffer) {
        free(buffer);
    }

    bitmapWidth = window.contentView.bounds.size.width;
    bitmapHeight = window.contentView.bounds.size.height;
    pitch = bitmapWidth * bytesPerPixel;
    buffer = (uint8 *)malloc(pitch * bitmapHeight);
}

void renderWeirdGradient() {

    int width = bitmapWidth;
    int height = bitmapHeight;

    uint8 *row = (uint8 *)buffer;

    for ( int y = 0; y < height; ++y) {

        uint8 *pixel = (uint8 *)row;

        for(int x = 0; x < width; ++x) {
            
            /*  Pixel in memory: RR GG BB AA */

            //Red            
            *pixel = 0; 
            ++pixel;  

            //Green
            *pixel = (uint8)y+(uint8)offsetY;
            ++pixel;

            //Blue
            *pixel = (uint8)x+(uint8)offsetX;
            ++pixel;

            //Alpha
            *pixel = 255;
            ++pixel;          
        }

        row += pitch;
    }

}

void macOSRedrawBuffer(NSWindow *window) {
    @autoreleasepool {
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &buffer 
                                  pixelsWide: bitmapWidth
                                  pixelsHigh: bitmapHeight
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bytesPerRow: pitch
                                  bitsPerPixel: bytesPerPixel * 8] autorelease];

        NSSize imageSize = NSMakeSize(bitmapWidth, bitmapHeight);
        NSImage *image = [[[NSImage alloc] initWithSize: imageSize] autorelease];
        [image addRepresentation: rep];
        window.contentView.layer.contents = image;
    }
}

const int samplesPerSecond = 48000;

OSStatus squareWaveRenderCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  uint32 inBusNumber,
                                  uint32 inNumberFrames,
                                  AudioBufferList *ioData) {
    #pragma unused(ioActionFlags)
    #pragma unused(inTimeStamp)
    #pragma unused(inBusNumber)
    #pragma unused(inRefCon)

    int16* outputBuffer = (int16*)ioData->mBuffers[0].mData;

    uint32 frequency = 256;
    uint32 halfFrequency = frequency/2;

    for (uint32 i = 0; i < inNumberFrames; i++) {
        if((i%frequency) > halfFrequency) {
            outputBuffer[i] = 5000;
        } else {
            outputBuffer[i] = -5000;
        } 
    }
    
    for(uint32 i = 1; i < ioData->mNumberBuffers; i++) {
        memcpy(ioData->mBuffers[i].mData, 
               outputBuffer, 
               ioData->mBuffers[i].mDataByteSize);
    }

    return noErr;
}

global_variable AudioComponentInstance audioUnit;

internal_usage
void macOSInitSound() {
    
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_DefaultOutput;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;

    AudioComponent outputComponent = AudioComponentFindNext(NULL, &acd);
    OSStatus status = AudioComponentInstanceNew(outputComponent, &audioUnit);
   
    //todo: (Ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up sound");
        return;
    }

    AudioStreamBasicDescription audioDescriptor;
    audioDescriptor.mSampleRate = 48000.0;
    audioDescriptor.mFormatID = kAudioFormatLinearPCM;
    audioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                                   kAudioFormatFlagIsNonInterleaved | 
                                   kAudioFormatFlagIsPacked; 
    int framesPerPacket = 1;
    int bytesPerFrame = sizeof(int16);
    audioDescriptor.mFramesPerPacket = framesPerPacket;
    audioDescriptor.mChannelsPerFrame = 2; // Stereo sound
    audioDescriptor.mBitsPerChannel = sizeof(int16) * 8;
    audioDescriptor.mBytesPerFrame = bytesPerFrame;
    audioDescriptor.mBytesPerPacket = framesPerPacket * bytesPerFrame; 

    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &audioDescriptor,
                                  sizeof(audioDescriptor));

    //todo: (Ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = squareWaveRenderCallback;

    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         0,
                         &renderCallback,
                         sizeof(renderCallback));

    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *mainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect screenRect = [[NSScreen mainScreen] frame];

    NSRect initialFrame = NSMakeRect((screenRect.size.width - globalRenderWidth) * 0.5,
                                     (screenRect.size.height - globalRenderHeight) * 0.5,
                                     globalRenderWidth,
                                     globalRenderHeight);
  
    NSWindow *window = [[HandmadeKeyIgnoringWindow alloc] 
                         initWithContentRect: initialFrame
                         styleMask: NSWindowStyleMaskTitled |
                                    NSWindowStyleMaskClosable |
                                    NSWindowStyleMaskMiniaturizable |
                                    NSWindowStyleMaskResizable 
                         backing: NSBackingStoreBuffered
                         defer: NO];    

    [window setBackgroundColor: NSColor.blackColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    [window setDelegate: mainWindowDelegate];
    window.contentView.wantsLayer = YES;
 
    macOSRefreshBuffer(window);

    ControllerInputSource inputSource = ControllerInputSourceKeyboard;
    [OSXHandmadeController setControllerInputSource: inputSource];
    [OSXHandmadeController initialize];

    macOSInitSound();
 
    while(running) {
   
        renderWeirdGradient();
        macOSRedrawBuffer(window); 

        OSXHandmadeController *controller = [OSXHandmadeController selectedController];
        
        if(controller != nil){
            if(controller.buttonAState == true) {
                offsetX++;       
            }

            if(controller.buttonLeftShoulderState == true) {
                offsetX--;
            }
           
            if(controller.buttonRightShoulderState == true) {
                offsetX++;
            }
 
            if (controller.dpadX == 1) {
                offsetX++;
            }

            if (controller.dpadX == -1) {
                offsetX--;
            }

            if (controller.dpadY == 1) {
                offsetY++;
            }

            if (controller.dpadY == -1) {
                offsetY--;
            }
        }

        NSEvent* event;
        
        do {
            event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (event != nil &&
                inputSource == ControllerInputSourceKeyboard &&
                (event.type == NSEventTypeKeyDown ||
                event.type == NSEventTypeKeyUp)) {
                [OSXHandmadeController updateKeyboardControllerWith: event];
            }
 
            switch ([event type]) {
                default:
                    [NSApp sendEvent: event];
            }
        } while (event != nil);
    }
 
    printf("Handmade Finished Running");
}
