// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include "osx_main.h"
#import <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>

global_variable float globalRenderWidth = 1024;
global_variable float globalRenderHeight = 768;

global_variable game_offscreen_buffer buffer = {};
global_variable int bytesPerPixel = 4;
global_variable int pitch;

global_variable int offsetX = 0;
global_variable int offsetY = 0;

global_variable bool running = true;

// TODO: (ted)  Investigate if we really need to refresh the display buffer.
//              It seems like it may only be necessary if the window size changed.
void macOSRefreshBuffer(NSWindow *window,
                        game_offscreen_buffer *buffer) {

    if (buffer->memory) {
        free(buffer->memory);
    }

    buffer->width = window.contentView.bounds.size.width;
    buffer->height = window.contentView.bounds.size.height;
    buffer->pitch = buffer->width * bytesPerPixel;
    buffer->memory = (uint8 *)malloc(buffer->pitch * buffer->height);
}

void macOSRedrawBuffer(NSWindow *window) {
    @autoreleasepool {
        uint8* plane = (uint8*)buffer.memory;
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &plane 
                                  pixelsWide: buffer.width
                                  pixelsHigh: buffer.height
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bytesPerRow: buffer.pitch
                                  bitsPerPixel: bytesPerPixel * 8] autorelease];

        NSSize imageSize = NSMakeSize(buffer.width, buffer.height);
        NSImage *image = [[[NSImage alloc] initWithSize: imageSize] autorelease];
        [image addRepresentation: rep];
        window.contentView.layer.contents = image;
    }
}

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 
- (void)windowWillClose:(id)sender {
    running = false;  
}
@end

@interface HandmadeKeyIgnoringWindow: NSWindow
@end

@implementation HandmadeKeyIgnoringWindow
- (void)keyDown:(NSEvent *)theEvent { }
@end

@interface OSXHandmadeController: NSObject

//  Analog Stick
@property double leftThumbstickX;
@property double leftThumbstickY;

//  D-Pad
@property NSInteger dpadX;
@property NSInteger dpadY;

//  ABXY
@property BOOL buttonAState;
@property BOOL buttonBState;
@property BOOL buttonXState;
@property BOOL buttonYState;

//  Shoulder Buttons
@property BOOL buttonLeftShoulderState;
@property BOOL buttonRightShoulderState;

@end

global_variable IOHIDManagerRef HIDManager = NULL;
global_variable OSXHandmadeController *connectedController = nil;
global_variable OSXHandmadeController *keyboardController = nil; 

@implementation OSXHandmadeController {

    bool _usesHatSwitch;

    //  Left Thumb Stick
    CFIndex _lThumbXUsageID;
    CFIndex _lThumbYUsageID;

    //  D-Pad    
	CFIndex _dpadLUsageID;
	CFIndex _dpadRUsageID;
	CFIndex _dpadDUsageID;
	CFIndex _dpadUUsageID;

    //  ABXY    
	CFIndex _buttonAUsageID;
	CFIndex _buttonBUsageID;
	CFIndex _buttonXUsageID;
	CFIndex _buttonYUsageID;
	
    //  Shoulder Buttons  
    CFIndex _lShoulderUsageID;
	CFIndex _rShoulderUsageID;
}

static
void macOSInitGameControllers() {
    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    connectedController = [[OSXHandmadeController alloc] init];
    keyboardController = [[OSXHandmadeController alloc] init];

    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, controllerConnected, NULL);
    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
    ]);
  
	IOHIDManagerScheduleWithRunLoop(HIDManager, 
                                    CFRunLoopGetMain(), 
                                    kCFRunLoopDefaultMode);
	NSLog(@"OSXhandmade Controller initialized.");
}

const unsigned short leftArrowKeyCode = 0x7B;
const unsigned short rightArrowKeyCode = 0x7C;
const unsigned short downArrowKeyCode = 0x7D;
const unsigned short upArrowKeyCode = 0x7E;
const unsigned short aKeyCode = 0x00;
const unsigned short sKeyCode = 0x01;
const unsigned short dKeyCode = 0x02;
const unsigned short fKeyCode = 0x03;
const unsigned short qKeyCode = 0x0C;
const unsigned short rKeyCode = 0x0F;

static
void updateKeyboardControllerWith(NSEvent *event) {
    switch ([event type]) {
        case NSEventTypeKeyDown:
            if (event.keyCode == leftArrowKeyCode &&
                keyboardController.dpadX != 1) {
                keyboardController.dpadX = -1;
                break;
            }

            if (event.keyCode == rightArrowKeyCode &&
                keyboardController.dpadX != -1) {
                keyboardController.dpadX = 1;
                break;
            }

            if (event.keyCode == downArrowKeyCode &&
                keyboardController.dpadY != -1) {
                keyboardController.dpadY = 1;
                break;
            }

            if (event.keyCode == upArrowKeyCode &&
                keyboardController.dpadY != 1) {
                keyboardController.dpadY = -1;
                break;
            }

            if (event.keyCode == aKeyCode) {
                keyboardController.buttonAState = 1;
                break;
            }

            if (event.keyCode == sKeyCode) {
                keyboardController.buttonBState = 1;
                break;
            }

            if (event.keyCode == dKeyCode) {
                keyboardController.buttonXState = 1;
                break;
            }

            if (event.keyCode == fKeyCode) {
                keyboardController.buttonYState = 1;
                break;
            }

            if (event.keyCode == qKeyCode) {
                keyboardController.buttonLeftShoulderState = 1;
                break;
            }

            if (event.keyCode == rKeyCode) {
                keyboardController.buttonRightShoulderState = 1;
                break;
            }

        case NSEventTypeKeyUp:
            if (event.keyCode == leftArrowKeyCode &&
                keyboardController.dpadX == -1) {
                keyboardController.dpadX = 0;
                break;
            } 

            if (event.keyCode == rightArrowKeyCode &&
                keyboardController.dpadX == 1) {
                keyboardController.dpadX = 0;
                break;
            }

            if (event.keyCode == downArrowKeyCode &&
                keyboardController.dpadY == 1) {
                keyboardController.dpadY = 0;
                break;
            }

            if (event.keyCode == upArrowKeyCode &&
                keyboardController.dpadY == -1) {
                keyboardController.dpadY = 0;
                break;
            }

            if (event.keyCode == aKeyCode) {
                keyboardController.buttonAState = 0;
                break;
            }

            if (event.keyCode == sKeyCode) {
                keyboardController.buttonBState = 0;
                break;
            }

            if (event.keyCode == dKeyCode) {
                keyboardController.buttonXState = 0;
                break;
            }

            if (event.keyCode == fKeyCode) {
                keyboardController.buttonYState = 0;
                break;
            }

            if (event.keyCode == qKeyCode) {
                keyboardController.buttonLeftShoulderState = 0;
                break;
            }

            if (event.keyCode == rKeyCode) {
                keyboardController.buttonRightShoulderState = 0;
                break;
            }

        default:
        break;
    }
}

static void controllerConnected(void *context, 
                                IOReturn result, 
                                void *sender, 
                                IOHIDDeviceRef device) {

    if(result != kIOReturnSuccess) {
        return;
    }

    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                       CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                        CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];

    OSXHandmadeController *controller = [[OSXHandmadeController alloc] init];
    
    if(vendorID == 0x054C && productID == 0x5C4) {
        NSLog(@"Sony Dualshock 4 detected.");

        //  Left Thumb Stick       
        controller->_lThumbXUsageID = kHIDUsage_GD_X;
        controller->_lThumbYUsageID = kHIDUsage_GD_Y;

        controller->_usesHatSwitch = true;
 
        controller->_buttonAUsageID = 0x02;
        controller->_buttonBUsageID = 0x03;
        controller->_buttonXUsageID = 0x01;
        controller->_buttonYUsageID = 0x04;
        controller->_lShoulderUsageID = 0x05;
        controller->_rShoulderUsageID = 0x06;
    }

    IOHIDDeviceRegisterInputValueCallback(device, controllerInput, (__bridge void *)controller);  
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);

    connectedController = controller;
}

static void controllerInput(void *context, 
                            IOReturn result, 
                            void *sender, 
                            IOHIDValueRef value) {

    if(result != kIOReturnSuccess) {
        return;
    }

    OSXHandmadeController *controller = (__bridge OSXHandmadeController *)context;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);    
    uint32 usagePage = IOHIDElementGetUsagePage(element);
    uint32 usage = IOHIDElementGetUsage(element);

    //Buttons
    if(usagePage == kHIDPage_Button) {
        BOOL buttonState = (BOOL)IOHIDValueGetIntegerValue(value);
        if(usage == controller->_buttonAUsageID) { controller->_buttonAState = buttonState; }
        if(usage == controller->_buttonBUsageID) { controller->_buttonBState = buttonState; }
        if(usage == controller->_buttonXUsageID) { controller->_buttonXState = buttonState; }
        if(usage == controller->_buttonYUsageID) { controller->_buttonYState = buttonState; }
        if(usage == controller->_lShoulderUsageID) { controller->_buttonLeftShoulderState = buttonState; }
        if(usage == controller->_rShoulderUsageID) { controller->_buttonRightShoulderState = buttonState; }
    }

    //dPad
    else if(usagePage == kHIDPage_GenericDesktop) {

        double_t analog = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated);
        
        if (usage == controller->_lThumbXUsageID) {
            controller->_leftThumbstickX = analog;
        }

        if (usage == controller->_lThumbYUsageID) {
            controller->_leftThumbstickY = analog;
        }

        if(usage == kHIDUsage_GD_Hatswitch) { 
            int dpadState = (int)IOHIDValueGetIntegerValue(value);
            NSInteger dpadX = 0;
            NSInteger dpadY = 0;

            switch(dpadState) {
                case 0: dpadX = 0; dpadY = 1; break;
                case 1: dpadX = 1; dpadY = 1; break;
                case 2: dpadX = 1; dpadY = 0; break;
                case 3: dpadX = 1; dpadY = -1; break;
                case 4: dpadX = 0; dpadY = -1; break;
                case 5: dpadX = -1; dpadY = -1; break;
                case 6: dpadX = -1; dpadY = 0; break;
                case 7: dpadX = -1; dpadY = 1; break;
                default: dpadX = 0; dpadY = 0; break;

            }

            controller->_dpadX = dpadX;
            controller->_dpadY = dpadY; 
        }
    }
}

@end

global_variable MacOSSoundOutput soundOutput = {};

OSStatus circularBufferRenderCallback(void *inRefCon,
                                      AudioUnitRenderActionFlags *ioActionFlags,
                                      const AudioTimeStamp *inTimeStamp,
                                      uint32 inBusNumber,
                                      uint32 inNumberFrames,
                                      AudioBufferList *ioData) {
  
    int length = inNumberFrames * soundOutput.bytesPerSample; 
    uint32 region1Size = length;
    uint32 region2Size = 0;

    if (soundOutput.playCursor + length > soundOutput.bufferSize) {
        region1Size = soundOutput.bufferSize - soundOutput.playCursor;
        region2Size = length - region1Size;
    } 
   
    uint8* channel = (uint8*)ioData->mBuffers[0].mData;

    memcpy(channel, 
           (uint8*)soundOutput.data + soundOutput.playCursor, 
           region1Size);

    memcpy(&channel[region1Size],
           soundOutput.data,
           region2Size);

    soundOutput.playCursor = (soundOutput.playCursor + length) % soundOutput.bufferSize;
    soundOutput.writeCursor = (soundOutput.playCursor + length) % soundOutput.bufferSize;

    return noErr;
}

global_variable AudioComponentInstance audioUnit;

internal_usage
void macOSInitSound() {
  
    //Create a two second circular buffer 
    soundOutput.samplesPerSecond = 48000; 
    soundOutput.runningSampleIndex = 0;
    int audioFrameSize = sizeof(int16) * 2;
    int numberOfSeconds = 2; 
    soundOutput.bytesPerSample = audioFrameSize; 
    soundOutput.bufferSize = soundOutput.samplesPerSecond * audioFrameSize * numberOfSeconds;
    soundOutput.data = malloc(soundOutput.bufferSize);
    soundOutput.playCursor = soundOutput.writeCursor = 0;

    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_DefaultOutput;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;

    AudioComponent outputComponent = AudioComponentFindNext(NULL, 
                                                            &acd);
    OSStatus status = AudioComponentInstanceNew(outputComponent, 
                                                &audioUnit);
   
    //TODO: (ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up sound");
        return;
    }

    AudioStreamBasicDescription audioDescriptor;
    audioDescriptor.mSampleRate = soundOutput.samplesPerSecond;
    audioDescriptor.mFormatID = kAudioFormatLinearPCM;
    audioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                                   kAudioFormatFlagIsPacked; 

    int framesPerPacket = 1;
    int bytesPerFrame = sizeof(int16) * 2;
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

    //TODO: (ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AURenderCallbackStruct renderCallback;
    renderCallback.inputProc = circularBufferRenderCallback;

    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &renderCallback,
                                  sizeof(renderCallback));

    //TODO: (ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

static void
macOSFillSoundBuffer(int byteToLock,
                     int bytesToWrite,
                     game_sound_output_buffer *soundBuffer) {

    int16_t *samples = soundBuffer->samples;
    void *region1 = (uint8*)soundOutput.data + byteToLock;
    int region1Size = bytesToWrite;
    if (region1Size + byteToLock > soundOutput.bufferSize)
    {
        region1Size = soundOutput.bufferSize - byteToLock;
    }
    void *region2 = soundOutput.data;
    int region2Size = bytesToWrite - region1Size;
    int region1SampleCount = region1Size/soundOutput.bytesPerSample;
    int16 *sampleOut = (int16 *)region1;
    for(int sampleIndex = 0;
        sampleIndex < region1SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *samples++;
        *sampleOut++ = *samples++;

        ++soundOutput.runningSampleIndex;
    }

    int region2SampleCount = region2Size/soundOutput.bytesPerSample;
    sampleOut = (int16 *)region2;
    for(int sampleIndex = 0;
        sampleIndex < region2SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *samples++;
        *sampleOut++ = *samples++;
        ++soundOutput.runningSampleIndex;
    }
} 

static void
macOSProcessGameControllerButton(game_button_state *oldState,
                                 game_button_state *newState,
                                 bool32 isDown) {
    newState->endedDown = isDown;
    newState->halfTransitionCount += ((newState->endedDown == oldState->endedDown)?0:1);
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
                                    NSWindowStyleMaskClosable
                         backing: NSBackingStoreBuffered
                         defer: NO];    

    [window setBackgroundColor: NSColor.blackColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    [window setDelegate: mainWindowDelegate];
    window.contentView.wantsLayer = YES;
 
    macOSRefreshBuffer(window, &buffer);

#if HANDMADE_INTERNAL
    // TODO: (ted)  Investigate base-address for Apple platforms.
    char* baseAddress = (char*)Gigabytes(8);
    uint32 allocationFlags = MAP_PRIVATE | MAP_ANON | MAP_FIXED;
#else
    void* baseAddress = 0;
    uint32 allocationFlags = MAP_PRIVATE | MAP_ANON;
#endif

    game_memory gameMemory = {};
    gameMemory.permanentStorageSize = Megabytes(64);
    gameMemory.transientStorageSize = Gigabytes(4);

    uint64 totalSize = gameMemory.permanentStorageSize + gameMemory.transientStorageSize;

    gameMemory.permanentStorage = mmap(baseAddress,
                                       gameMemory.permanentStorageSize,
                                       PROT_READ | PROT_WRITE,
                                       allocationFlags, -1, 0); 

    if (gameMemory.permanentStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate permanent storage"];
    }
   
    uint8* transientStorageAddress = ((uint8*)gameMemory.permanentStorage + gameMemory.permanentStorageSize);
    gameMemory.transientStorage = mmap(transientStorageAddress,
                                       gameMemory.transientStorageSize,
                                       PROT_READ | PROT_WRITE,
                                       allocationFlags, -1, 0); 

    if (gameMemory.transientStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate transient storage"];
    }

    macOSInitGameControllers(); 
    macOSInitSound();

    game_input input[2] = {};
    game_input *newInput = &input[0];
    game_input *oldInput = &input[1];

    int16 *samples = (int16*)calloc(soundOutput.samplesPerSecond,
                                    soundOutput.bytesPerSample); 

    int latencySampleCount = soundOutput.samplesPerSecond / 15;
    int targetQueueBytes = latencySampleCount * soundOutput.bytesPerSample;

    uint64 currentTime = mach_absolute_time();
    uint64 lastCounter = currentTime;
    real32 frameTime = 0.0f; 

    while(running) {

        int targetCursor = ((soundOutput.playCursor +
                    (latencySampleCount*soundOutput.bytesPerSample)) %
                soundOutput.bufferSize);

        int byteToLock = (soundOutput.runningSampleIndex*soundOutput.bytesPerSample) % soundOutput.bufferSize; 
        int bytesToWrite;

         if (byteToLock > targetCursor) {
            bytesToWrite = (soundOutput.bufferSize - byteToLock);
            bytesToWrite += targetCursor;
        } else {
            bytesToWrite = targetCursor - byteToLock;
        }

        game_sound_output_buffer soundBuffer = {};
        soundBuffer.samplesPerSecond = soundOutput.samplesPerSecond;
        soundBuffer.sampleCount = bytesToWrite / soundOutput.bytesPerSample;
        soundBuffer.samples = samples;

        gameUpdateAndRender(&gameMemory, newInput, &buffer, &soundBuffer); 
        macOSFillSoundBuffer(byteToLock, bytesToWrite, &soundBuffer);
        macOSRedrawBuffer(window); 

        game_input *temp = newInput;
        newInput = oldInput;
        oldInput = temp;

        OSXHandmadeController *controller = connectedController;
        
        if(controller != nil){

            game_controller_input *oldController = &oldInput->controllers[0];
            game_controller_input *newController = &newInput->controllers[0];

            macOSProcessGameControllerButton(&(oldController->a),
                                             &(newController->a),
                                             controller.buttonAState); 

            macOSProcessGameControllerButton(&(oldController->b),
                                             &(newController->b),
                                             controller.buttonBState); 

            macOSProcessGameControllerButton(&(oldController->x),
                                             &(newController->x),
                                             controller.buttonXState); 

            macOSProcessGameControllerButton(&(oldController->y),
                                             &(newController->y),
                                             controller.buttonYState); 

            macOSProcessGameControllerButton(&(oldController->leftShoulder),
                                             &(newController->leftShoulder),
                                             controller.buttonLeftShoulderState); 
           
            macOSProcessGameControllerButton(&(oldController->rightShoulder),
                                             &(newController->rightShoulder),
                                             controller.buttonRightShoulderState); 
 
            if (controller.dpadX == 1) {
                macOSProcessGameControllerButton(&(oldController->right),
                                                 &(newController->right),
                                                 true); 
                macOSProcessGameControllerButton(&(oldController->left),
                                                 &(newController->left),
                                                 false); 
            }

            if (controller.dpadX == -1) {
                macOSProcessGameControllerButton(&(oldController->right),
                                                 &(newController->right),
                                                 false); 
                macOSProcessGameControllerButton(&(oldController->left),
                                                 &(newController->left),
                                                 true); 
            }

            if (controller.dpadY == 1) {
                macOSProcessGameControllerButton(&(oldController->up),
                                                 &(newController->up),
                                                 true); 
                macOSProcessGameControllerButton(&(oldController->down),
                                                 &(newController->down),
                                                 false); 
            }

            if (controller.dpadY == -1) {
                macOSProcessGameControllerButton(&(oldController->up),
                                                 &(newController->up),
                                                 false); 
                macOSProcessGameControllerButton(&(oldController->down),
                                                 &(newController->down),
                                                 true); 
            }

            newController->isAnalog = true;
            newController->startX = oldController->endX;
            newController->startY = oldController->endY;

            // TODO: (ted)  The analog value returned has a range of zero to 255.
            //              Zero to 127 means negative, and 128 to 255 means positive.
            //
            //              How to normalize and produce a real32 with a range of -1 to +1?
            //              
            //              If less than 127, subtract 127, and divide by 127.
            //              If greater than 127, subtract from 255, divide by 127, and make positive.
            //
            //              Take another pass at this later and see if we could get something more
            //              accurate.
            newController->endX = (controller.leftThumbstickX - 127.5)/127.5;
            newController->endY = (controller.leftThumbstickY - 127.5)/127.5;
            newController->minX = newController->maxX = newController->endX;            
            newController->minY = newController->maxY = newController->endY;            
        }

        NSEvent* event;
        
        do {
            event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (event != nil &&
                controller == keyboardController &&
                (event.type == NSEventTypeKeyDown ||
                event.type == NSEventTypeKeyUp)) {
                updateKeyboardControllerWith(event);
            }
 
            switch ([event type]) {
                default:
                    [NSApp sendEvent: event];
            }
        } while (event != nil);

        uint64 endCounter = mach_absolute_time();
    
        mach_timebase_info_data_t tb;

        uint64 elapsed = endCounter - lastCounter;

        if (tb.denom == 0)
        {
            // First time we need to get the timebase
            mach_timebase_info(&tb);
        }

        uint64 nanoseconds = elapsed * tb.numer / tb.denom;
        real32 measuredSecondsPerFrame = (real32)nanoseconds * 1.0E-9;
        real32 measuredFramesPerSecond = 1 / measuredSecondsPerFrame;
       
        frameTime += measuredSecondsPerFrame;
        lastCounter = endCounter;
 
        NSLog(@"Frames Per Second %f", measuredFramesPerSecond); 
    }
 
    printf("Handmade Finished Running");
}
