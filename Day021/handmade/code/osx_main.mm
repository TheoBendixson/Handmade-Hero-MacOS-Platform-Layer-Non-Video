// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#import <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

#include "osx_main.h"

global_variable bool running = true;
global_variable bool isPaused = false;
global_variable mach_timebase_info_data_t globalPerfCountFrequency;

internal void
CatStrings(size_t SourceACount, char *SourceA,
           size_t SourceBCount, char *SourceB,
           size_t DestCount, char *Dest)
{
    // TODO(casey): Dest bounds checking!
    
    for(int Index = 0;
        Index < SourceACount;
        ++Index)
    {
        *Dest++ = *SourceA++;
    }

    for(int Index = 0;
        Index < SourceBCount;
        ++Index)
    {
        *Dest++ = *SourceB++;
    }

    *Dest++ = 0;
}

internal void
MacGetAppFileName(mac_state *State)
{
	uint32 buffsize = sizeof(State->AppFileName);
    if (_NSGetExecutablePath(State->AppFileName, &buffsize) == 0) {
		for(char *Scan = State->AppFileName;
			*Scan;
			++Scan)
		{
			if(*Scan == '/')
			{
				State->OnePastLastAppFileNameSlash = Scan + 1;
			}
		}
    }
}

internal int
StringLength(char *String)
{
    int Count = 0;
    while(*String++)
    {
        ++Count;
    }
    return(Count);
}

internal void
MacBuildAppPathFileName(mac_state *State, char *FileName,
						int DestCount, char *Dest)
{
	CatStrings(State->OnePastLastAppFileNameSlash - State->AppFileName, State->AppFileName,
			   StringLength(FileName), FileName,
			   DestCount, Dest);
}

#if HANDMADE_INTERNAL
DEBUG_PLATFORM_READ_ENTIRE_FILE(DEBUGPlatformReadEntireFile) 
{

    debug_read_file_result result = {};
    result.ContentsSize = 0;
    result.Contents = 0;  
 
    NSString *path = [NSString stringWithUTF8String: filename];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager isReadableFileAtPath: path]) { 
        NSData *fileData = [fileManager contentsAtPath: path];

        if (fileData == nil) {
            NSLog(@"Tried to load file. Contents are empty or otherwise unreadable.");
        } else {
            result.ContentsSize = (uint32)fileData.length;
            result.Contents = const_cast<void *>(fileData.bytes);
        }
        
    } else {
        NSLog(@"Tried to load file. No file at this path.");
    } 

    return result;
}

DEBUG_PLATFORM_FREE_FILE_MEMORY(DEBUGPlatformFreeFileMemory) 
{
    if (bitmapMemory) {
        free(bitmapMemory);
    }

    return bitmapMemory;
}

DEBUG_PLATFORM_WRITE_ENTIRE_FILE(DEBUGPlatformWriteEntireFile)
{
    bool32 result = false;

    NSString *path = [NSString stringWithUTF8String: filename];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSData *fileData = [NSData dataWithBytes: memory
                               length: fileSize];

    if (fileData != nil) {
        result = [fileManager createFileAtPath: path
                              contents: fileData
                              attributes: nil];
    } else {
        NSLog(@"No data to write to.");
    } 

    return result;
}

internal mac_game_code 
MacLoadGameCode(char *SourceDLLName)
{
    mac_game_code Result = {};

    Result.GameCodeDLL = dlopen(SourceDLLName, RTLD_NOW);
    if (Result.GameCodeDLL)
    {
        Result.UpdateAndRender = (game_update_and_render *)
            dlsym(Result.GameCodeDLL, "GameUpdateAndRender");
        
        Result.GetSoundSamples = (game_get_sound_samples *)
            dlsym(Result.GameCodeDLL, "GameGetSoundSamples");

        Result.IsValid = (Result.UpdateAndRender &&
                          Result.GetSoundSamples);
    }
    if(!Result.IsValid)
    {
        Result.UpdateAndRender = 0;
        Result.GetSoundSamples = 0;
    }

    return Result;
}

internal void
MacUnloadGameCode(mac_game_code *GameCode)
{
    if(GameCode->GameCodeDLL)
    {
    	dlclose(GameCode->GameCodeDLL);
        GameCode->GameCodeDLL = 0;
    }

    GameCode->IsValid = false;
    GameCode->UpdateAndRender = 0;
    GameCode->GetSoundSamples = 0;
}

internal void
MacDebugDrawVertical(game_offscreen_buffer *buffer, int x,
                       int top, int bottom, uint32 color,
                       int bytesPerPixel) {

    if (top <= 0) {
        top = 0;
    }

    if (bottom > buffer->Height) {
        bottom = buffer->Height;
    }

    if ((x >= 0) && (x < buffer->Width)) {
        uint8 *pixel = ((uint8 *)buffer->Memory +
                        x*bytesPerPixel +
                        top*buffer->Pitch);

        for (int y = top; y < bottom; ++y) {
            *(uint32 *)pixel = color;
            pixel += buffer->Pitch; 
        }
    }
}

internal void
MacDrawSoundBufferMarker(game_offscreen_buffer *buffer, mac_sound_output *soundOutput,
                         real32 c, int padX, int top, int bottom, uint32 value, 
                         uint32 color, int bytesPerPixel) {
    real32 xReal32 = (c * (real32)value);
    int x = padX + (int)xReal32;
    MacDebugDrawVertical(buffer, x, top, bottom, color, bytesPerPixel);
}

internal void
MacDebugSyncDisplay(game_offscreen_buffer *buffer, mac_sound_output *soundOutput,
                      int timeMarkerCount, mac_debug_time_marker *timeMarkers, 
                      int currentMarkerIndex, real32 targetSecondsPerFrame, int bytesPerPixel) {
    int padX = 16;
    int padY = 16;
    int lineHeight = 64; 

    real32 c = (real32)(buffer->Width - 2*padX) / (real32)soundOutput->BufferSize;

    for(int markerIndex = 0; markerIndex < timeMarkerCount;
        ++markerIndex) {

        mac_debug_time_marker *thisMarker = &timeMarkers[markerIndex];
        Assert(thisMarker->OutputPlayCursor < soundOutput->BufferSize);
        Assert(thisMarker->OutputWriteCursor < soundOutput->BufferSize);
        Assert(thisMarker->OutputLocation < soundOutput->BufferSize);
        Assert(thisMarker->FlipPlayCursor < soundOutput->BufferSize);
        Assert(thisMarker->FlipWriteCursor < soundOutput->BufferSize);

        uint32 playColor = 0xFFFFFFFF;
        uint32 writeColor = 0xFF0000FF;
        uint32 expectedFlipColor = 0xFF00FFFF;

        int top = padY;
        int bottom = padY + lineHeight;

        if (markerIndex == currentMarkerIndex) {
            top += lineHeight+padY;
            bottom += lineHeight+padY;

            int firstTop = top;

            MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputPlayCursor, playColor, bytesPerPixel);
            MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputWriteCursor, writeColor, bytesPerPixel);

            top += lineHeight+padY;
            bottom += lineHeight+padY;

            MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputLocation, playColor, bytesPerPixel);
            MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputLocation + thisMarker->OutputByteCount, 
                                       writeColor, bytesPerPixel);

            top += lineHeight+padY;
            bottom += lineHeight+padY;

            MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, firstTop, bottom, 
                                       thisMarker->ExpectedFlipPlayCursor, expectedFlipColor, bytesPerPixel);
        }

        MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                   thisMarker->FlipPlayCursor, playColor, bytesPerPixel);
        MacDrawSoundBufferMarker(buffer, soundOutput, c, padX, top, bottom, 
                                   thisMarker->FlipWriteCursor, writeColor, bytesPerPixel);
    }
}
#endif

internal
void MacRefreshBuffer(NSWindow *window, game_offscreen_buffer *buffer,
                      int bytesPerPixel) {

    if (buffer->Memory) {
        free(buffer->Memory);
    }

    buffer->Width = (int)window.contentView.bounds.size.width;
    buffer->Height = (int)window.contentView.bounds.size.height;
    buffer->Pitch = buffer->Width * bytesPerPixel;
    buffer->Memory = (uint8 *)malloc((size_t)buffer->Pitch * (size_t)buffer->Height);
}

// TODO(ted):   Someone at Apple told me this is really inefficient. Speed up how this is done.
internal
void MacRedrawBuffer(NSWindow *window, game_offscreen_buffer *buffer, int bytesPerPixel) {
    @autoreleasepool {
        uint8* plane = (uint8*)buffer->Memory;
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &plane 
                                  pixelsWide: buffer->Width
                                  pixelsHigh: buffer->Height
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bytesPerRow: buffer->Pitch
                                  bitsPerPixel: bytesPerPixel * 8] autorelease];

        NSSize imageSize = NSMakeSize(buffer->Width, buffer->Height);
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
@property float leftThumbstickX;
@property float leftThumbstickY;
@property BOOL usesHatSwitch;

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
global_variable NSMutableArray *macOSControllers;

@implementation OSXHandmadeController {

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

internal
void MacInitGameControllers() {
    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    OSXHandmadeController *gamePad = [[OSXHandmadeController alloc] init];
    OSXHandmadeController *keyboardController = [[OSXHandmadeController alloc] init];
    [keyboardController setUsesHatSwitch: false];

    macOSControllers = [[NSMutableArray alloc] init];
    [macOSControllers addObject: keyboardController];
    [macOSControllers addObject: gamePad];

    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    // TODO (ted):  Figure out how to match multiple game controllers to the different
    //              HID callbacks
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, ControllerConnected, NULL);
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

internal
void UpdateKeyboardControllerWith(NSEvent *event) {

    OSXHandmadeController *keyboardController = [macOSControllers objectAtIndex: 0];    

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

#if HANDMADE_INTERNAL
            if (event.keyCode == dKeyCode) {
                isPaused = !isPaused;
                break;
            }
#endif
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

internal 
void ControllerConnected(void *context, IOReturn result, 
                         void *sender, IOHIDDeviceRef device)
{

    if(result != kIOReturnSuccess) {
        return;
    }

    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                       CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                        CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];

    OSXHandmadeController *controller = [macOSControllers objectAtIndex: 1];    

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

    // TODO (ted):  Have this register multiple times for multiple controllers.
    IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (__bridge void *)controller);  
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);
}

internal 
void ControllerInput(void *context, IOReturn result, 
                     void *sender, IOHIDValueRef value)
{
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
            controller->_leftThumbstickX = (real32)analog;
        }

        if (usage == controller->_lThumbYUsageID) {
            controller->_leftThumbstickY = (real32)analog;
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

OSStatus 
CircularBufferRenderCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             uint32 inBusNumber,
                             uint32 inNumberFrames,
                             AudioBufferList *ioData) 
{
    mac_sound_output *soundOutput = (mac_sound_output*)inRefCon;

    uint32 length = inNumberFrames * soundOutput->BytesPerSample; 
    uint32 region1Size = length;
    uint32 region2Size = 0;

    if (soundOutput->PlayCursor + length > soundOutput->BufferSize) {
        region1Size = soundOutput->BufferSize - soundOutput->PlayCursor;
        region2Size = length - region1Size;
    } 
   
    uint8* channel = (uint8*)ioData->mBuffers[0].mData;

    memcpy(channel, 
           (uint8*)soundOutput->Data + soundOutput->PlayCursor, 
           region1Size);

    memcpy(&channel[region1Size],
           soundOutput->Data,
           region2Size);

    soundOutput->PlayCursor = (soundOutput->PlayCursor + length) % soundOutput->BufferSize;
    soundOutput->WriteCursor = (soundOutput->PlayCursor + length) % soundOutput->BufferSize;

    return noErr;
}

internal
void MacInitSound(mac_sound_output *soundOutput)
{
    //Create a two second circular buffer 
    soundOutput->SamplesPerSecond = 48000; 
    soundOutput->RunningSampleIndex = 0;
    uint32 audioFrameSize = sizeof(int16) * 2;
    uint32 numberOfSeconds = 2; 
    soundOutput->BytesPerSample = audioFrameSize; 
    soundOutput->BufferSize = soundOutput->SamplesPerSecond * audioFrameSize * numberOfSeconds;
    soundOutput->Data = malloc(soundOutput->BufferSize);
    soundOutput->PlayCursor = soundOutput->WriteCursor = 0;

    AudioComponentInstance audioUnit;
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
    audioDescriptor.mSampleRate = soundOutput->SamplesPerSecond;
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
    renderCallback.inputProc = CircularBufferRenderCallback;
    renderCallback.inputProcRefCon = soundOutput;

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

internal void
MacFillSoundBuffer(int byteToLock, int bytesToWrite,
                   game_sound_output_buffer *soundBuffer, mac_sound_output *soundOutput) 
{
    int16_t *Samples = soundBuffer->Samples;
    void *region1 = (uint8*)soundOutput->Data + byteToLock;
    int region1Size = bytesToWrite;
    if (region1Size + byteToLock > soundOutput->BufferSize)
    {
        region1Size = soundOutput->BufferSize - byteToLock;
    }
    void *region2 = soundOutput->Data;
    int region2Size = bytesToWrite - region1Size;
    int region1SampleCount = region1Size/soundOutput->BytesPerSample;
    int16 *sampleOut = (int16 *)region1;
    for(int sampleIndex = 0;
        sampleIndex < region1SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *Samples++;
        *sampleOut++ = *Samples++;

        ++soundOutput->RunningSampleIndex;
    }

    int region2SampleCount = region2Size/soundOutput->BytesPerSample;
    sampleOut = (int16 *)region2;
    for(int sampleIndex = 0;
        sampleIndex < region2SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *Samples++;
        *sampleOut++ = *Samples++;
        ++soundOutput->RunningSampleIndex;
    }
} 

internal void
MacProcessGameControllerButton(game_button_state *oldState, game_button_state *newState,
                               bool32 isDown) 
{
    newState->EndedDown = isDown;
    newState->HalfTransitionCount += ((newState->EndedDown == oldState->EndedDown)?0:1);
}

internal real32
MacGetSecondsElapsed(uint64 start, uint64 end)
{
	uint64 elapsed = (end - start);
    real32 result = (real32)(elapsed * (globalPerfCountFrequency.numer / globalPerfCountFrequency.denom)) / 1000.f / 1000.f / 1000.f;
    return(result);
}

int main(int argc, const char * argv[]) 
{
    mach_timebase_info(&globalPerfCountFrequency);

    HandmadeMainWindowDelegate *mainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect screenRect = [[NSScreen mainScreen] frame];

    float globalRenderWidth = 1024;
    float globalRenderHeight = 768;

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

    int bytesPerPixel = 4;
    game_offscreen_buffer buffer = {};

    MacRefreshBuffer(window, &buffer, bytesPerPixel);

#if HANDMADE_INTERNAL
    char* baseAddress = (char*)Gigabytes(8);
    uint32 allocationFlags = MAP_PRIVATE | MAP_ANON | MAP_FIXED;
#else
    void* baseAddress = 0;
    uint32 allocationFlags = MAP_PRIVATE | MAP_ANON;
#endif

    game_memory gameMemory = {};
    gameMemory.PermanentStorageSize = Megabytes(64);
    gameMemory.TransientStorageSize = Gigabytes(4);
    gameMemory.DEBUGPlatformReadEntireFile = DEBUGPlatformReadEntireFile;
    gameMemory.DEBUGPlatformFreeFileMemory = DEBUGPlatformFreeFileMemory;
    gameMemory.DEBUGPlatformWriteEntireFile = DEBUGPlatformWriteEntireFile;

    gameMemory.PermanentStorage = mmap(baseAddress,
                                       gameMemory.PermanentStorageSize,
                                       PROT_READ | PROT_WRITE,
                                       allocationFlags, -1, 0); 

    if (gameMemory.PermanentStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate permanent storage"];
    }
   
    uint8* TransientStorageAddress = ((uint8*)gameMemory.PermanentStorage + gameMemory.PermanentStorageSize);
    gameMemory.TransientStorage = mmap(TransientStorageAddress,
                                       gameMemory.TransientStorageSize,
                                       PROT_READ | PROT_WRITE,
                                       allocationFlags, -1, 0); 

    if (gameMemory.TransientStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate transient storage"];
    }

    MacInitGameControllers(); 

    mac_sound_output soundOutput = {};
    MacInitSound(&soundOutput);

    game_input input[2] = {};
    game_input *newInput = &input[0];
    game_input *oldInput = &input[1];

    int16 *Samples = (int16*)calloc(soundOutput.SamplesPerSecond,
                                    soundOutput.BytesPerSample); 

    int monitorRefreshHz = 60;
    uint32 gameUpdateHzInt = monitorRefreshHz/2;
    real32 gameUpdateHz = (monitorRefreshHz / 2.0f);
    real32 targetSecondsPerFrame = 1.0f / (real32)gameUpdateHz;

    // TODO: (ted)  Compute this variance and see what the lowest reasonable value is
    soundOutput.SafetyBytes = ((soundOutput.SamplesPerSecond*soundOutput.BytesPerSample)/gameUpdateHzInt)/3;

    uint64 currentTime = mach_absolute_time();
    uint64 lastCounter = currentTime;
    real32 frameTime = 0.0f; 
    
    uint64 flipWallClock = mach_absolute_time();

    bool32 soundIsValid = false;

#if HANDMADE_INTERNAL
    int debugTimeMarkerIndex = 0;
    mac_debug_time_marker debugTimeMarkers[15] = {};
#endif

    mac_state MacState = {};

    MacGetAppFileName(&MacState);

    // TODO: (ted) Figure out how to load the game code from a file name.
	char SourceGameCodeDLLFullPath[MAC_MAX_FILENAME_SIZE];
    MacBuildAppPathFileName(&MacState, "Contents/Resources/GameCode.dylib",
                               sizeof(SourceGameCodeDLLFullPath), SourceGameCodeDLLFullPath);

    mac_game_code Game = MacLoadGameCode(SourceGameCodeDLLFullPath);

    while(running) {

        // TODO(ted):   Figure out why this event loop code was interfering with
        //              the buffer refresh
        NSEvent* event;
        
        do {
            event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (event != nil &&
                (event.type == NSEventTypeKeyDown ||
                event.type == NSEventTypeKeyUp)) {
                UpdateKeyboardControllerWith(event);
            }
 
            switch ([event type]) {
                default:
                    [NSApp sendEvent: event];
            }
        } while (event != nil);

        if (!isPaused) {

            Game.UpdateAndRender(&gameMemory, newInput, &buffer); 

//          TODO (ted): This wasn't used in the original stream. Figure out how it can be used.
//            uint64 audioWallClock = mach_absolute_time();
//            real32 fromBeginToAudioSeconds = macOSGetSecondsElapsed(flipWallClock, audioWallClock);

            uint32 PlayCursor = soundOutput.PlayCursor;
            uint32 WriteCursor = soundOutput.WriteCursor;

            // NOTE(casey):  Here is how sound output computation works.
            //
            //               We define a safety value that is the number of Samples 
            //               we think our game update loop may vary by. (let's say up to 2ms).
            //
            //               When we wake up to write audio, we will look and see
            //               what the play cursor position is. And we will forecast ahead
            //               where we think the play cursor will be on the next frame boundary.
            //
            //               We will then look to see if the write cursor is before that by at least our
            //               safety value. If it is, the target fill position is that frame boundary plus one
            //               frame.
            //
            //               This gives us perfect audio sync on a card with low enough latency.
            //
            //               If the write cursor is after that safety margin, then we assume
            //               we can never sync the audio perfectly, so we will write one frame's
            //               worth of audio plus the safety margin's worth of guard Samples. 
            //               (1ms or whatever is determined to be safe). Whatever we think the variability
            //               of our frame computation is.
            if (!soundIsValid) {
                soundOutput.RunningSampleIndex = WriteCursor / soundOutput.BytesPerSample;
                soundIsValid = true;
            }

            int byteToLock = 0;
            int bytesToWrite = 0;

            byteToLock = (soundOutput.RunningSampleIndex*soundOutput.BytesPerSample) % soundOutput.BufferSize; 

            uint32 expectedSoundBytesPerFrame = 
                (soundOutput.SamplesPerSecond*soundOutput.BytesPerSample)/gameUpdateHzInt;

            //TODO: (ted)   Commented this out. It wasn't used in the original stream.
//            real32 secondsLeftUntilFlip = (targetSecondsPerFrame - fromBeginToAudioSeconds);
//            uint32 expectedBytesUntilFlip = 
//                (uint32)((secondsLeftUntilFlip/targetSecondsPerFrame)*(real32)expectedSoundBytesPerFrame);

            uint32 expectedFrameBoundaryByte = PlayCursor + expectedSoundBytesPerFrame;

            uint32 safeWriteCursor = WriteCursor;
            if (safeWriteCursor < PlayCursor) {
                safeWriteCursor += soundOutput.BufferSize;
            }
            Assert(safeWriteCursor >= PlayCursor);
            safeWriteCursor += soundOutput.SafetyBytes;

            bool32 audioCardIsLowLatency = (safeWriteCursor < expectedFrameBoundaryByte);

            int targetCursor;
        
            if (audioCardIsLowLatency) {
                targetCursor = (expectedFrameBoundaryByte + expectedSoundBytesPerFrame);
            } else {
                targetCursor = (WriteCursor + expectedSoundBytesPerFrame + soundOutput.SafetyBytes);
            }

            targetCursor = targetCursor % soundOutput.BufferSize;

             if (byteToLock > targetCursor) {
                bytesToWrite = (soundOutput.BufferSize - byteToLock);
                bytesToWrite += targetCursor;
            } else {
                bytesToWrite = targetCursor - byteToLock;
            }

            game_sound_output_buffer soundBuffer = {};
            soundBuffer.SamplesPerSecond = soundOutput.SamplesPerSecond;
            soundBuffer.SampleCount = bytesToWrite / soundOutput.BytesPerSample;
            soundBuffer.Samples = Samples;
            Game.GetSoundSamples(&gameMemory, &soundBuffer);

#if HANDMADE_INTERNAL
            mac_debug_time_marker *marker = &debugTimeMarkers[debugTimeMarkerIndex];
            marker->OutputPlayCursor = PlayCursor;
            marker->OutputWriteCursor = WriteCursor;
            marker->OutputLocation = byteToLock;
            marker->OutputByteCount = bytesToWrite;
            marker->ExpectedFlipPlayCursor = expectedFrameBoundaryByte;
#endif

            MacFillSoundBuffer(byteToLock, bytesToWrite, &soundBuffer, &soundOutput);

            game_input *temp = newInput;
            newInput = oldInput;
            oldInput = temp;

            for (int controllerIndex = 0; controllerIndex < 2; controllerIndex++) {
                OSXHandmadeController *controller = [macOSControllers objectAtIndex: controllerIndex];

                game_controller_input *oldController = &oldInput->Controllers[controllerIndex];
                game_controller_input *newController = &newInput->Controllers[controllerIndex];

                MacProcessGameControllerButton(&(oldController->A),
                                                 &(newController->A),
                                                 controller.buttonAState); 

                MacProcessGameControllerButton(&(oldController->B),
                                                 &(newController->B),
                                                 controller.buttonBState); 

                MacProcessGameControllerButton(&(oldController->X),
                                                 &(newController->X),
                                                 controller.buttonXState); 

                MacProcessGameControllerButton(&(oldController->Y),
                                                 &(newController->Y),
                                                 controller.buttonYState); 

                MacProcessGameControllerButton(&(oldController->LeftShoulder),
                                                 &(newController->LeftShoulder),
                                                 controller.buttonLeftShoulderState); 
               
                MacProcessGameControllerButton(&(oldController->RightShoulder),
                                                 &(newController->RightShoulder),
                                                 controller.buttonRightShoulderState); 
     
                if (controller.dpadX == 1) {
                    MacProcessGameControllerButton(&(oldController->Right),
                                                     &(newController->Right),
                                                     true); 
                    MacProcessGameControllerButton(&(oldController->Left),
                                                     &(newController->Left),
                                                     false); 
                } else if (controller.dpadX == -1) {
                    MacProcessGameControllerButton(&(oldController->Right),
                                                     &(newController->Right),
                                                     false); 
                    MacProcessGameControllerButton(&(oldController->Left),
                                                     &(newController->Left),
                                                     true); 
                } else if (controller.dpadX == 0) {
                    MacProcessGameControllerButton(&(oldController->Right),
                                                     &(newController->Right),
                                                     false); 
                    MacProcessGameControllerButton(&(oldController->Left),
                                                     &(newController->Left),
                                                     false); 
                }

                if (controller.dpadY == 1) {
                    MacProcessGameControllerButton(&(oldController->Up),
                                                     &(newController->Up),
                                                     true); 
                    MacProcessGameControllerButton(&(oldController->Down),
                                                     &(newController->Down),
                                                     false); 
                } else if (controller.dpadY == -1) {
                    MacProcessGameControllerButton(&(oldController->Up),
                                                     &(newController->Up),
                                                     false); 
                    MacProcessGameControllerButton(&(oldController->Down),
                                                     &(newController->Down),
                                                     true); 
                } else if (controller.dpadY == 0) {
                    MacProcessGameControllerButton(&(oldController->Up),
                                                     &(newController->Up),
                                                     false); 
                    MacProcessGameControllerButton(&(oldController->Down),
                                                     &(newController->Down),
                                                     false); 
                }

                newController->IsAnalog = controller.usesHatSwitch;
                newController->StartX = oldController->EndX;
                newController->StartY = oldController->EndY;

                if (newController->IsAnalog) {
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
                    newController->EndX = (real32)(controller.leftThumbstickX - 127.5f)/127.5f;
                    newController->EndY = (real32)(controller.leftThumbstickY - 127.5f)/127.5f;
                    newController->MinX = newController->MaxX = newController->EndX;            
                    newController->MinY = newController->MaxY = newController->EndY;            
                }
            }

            uint64 workCounter = mach_absolute_time();
            real32 workSecondsElapsed = MacGetSecondsElapsed(lastCounter, workCounter);

            real32 secondsElapsedForFrame = workSecondsElapsed;
            if(secondsElapsedForFrame < targetSecondsPerFrame) {
                
                // NOTE(ted):   Using an under offset to get slighlty under the target, then spin up to it.
                real32 underOffset = 3.0f / 1000.0f;
                useconds_t sleepMS;

                if ((targetSecondsPerFrame - secondsElapsedForFrame - underOffset < 0)) {
                    // NOTE(ted):   This happens when the under offset subtraction gives integer
                    //              underflow. Don't apply an offset in this case.
                    underOffset = 0;
                } 

                sleepMS = (useconds_t)(1000.0f * 1000.0f * (targetSecondsPerFrame -
                           secondsElapsedForFrame - underOffset));

                if(sleepMS > 0)
                {
                    usleep(sleepMS);
                }

                real32 testSecondsElapsedForFrame = MacGetSecondsElapsed(lastCounter,
                        mach_absolute_time());
                if(testSecondsElapsedForFrame < targetSecondsPerFrame)
                {
                    // TODO(casey): LOG MISSED SLEEP HERE
                }

                while(secondsElapsedForFrame < targetSecondsPerFrame)
                {
                    secondsElapsedForFrame = MacGetSecondsElapsed(lastCounter,
                            mach_absolute_time());
                }
            }
            else
            {
                // TODO(casey): MISSED FRAME RATE!
                // TODO(casey): Logging
            }

            uint64 endOfFrame = mach_absolute_time();
            uint64 frameElapsed = endOfFrame - lastCounter;
            uint64 frameNanoseconds = frameElapsed * globalPerfCountFrequency.numer / globalPerfCountFrequency.denom;

            real32 measuredMillsecondsPerFrame = (real32)frameNanoseconds * 1.0E-6f;
            real32 measuredSecondsPerFrame = (real32)frameNanoseconds * 1.0E-9f;
            real32 measuredFramesPerSecond = 1.0f / measuredSecondsPerFrame;

            NSLog(@"Frames Per Second %f", measuredFramesPerSecond); 
            NSLog(@"Millseconds Per Frame %f", measuredMillsecondsPerFrame); 

            frameTime += measuredSecondsPerFrame;
            lastCounter = endOfFrame;

#if HANDMADE_INTERNAL
            // TODO (casey):    Current is wrong on the zeroeth index
            MacDebugSyncDisplay(&buffer, &soundOutput, debugTimeMarkerIndex, debugTimeMarkers, 
                                (debugTimeMarkerIndex - 1), targetSecondsPerFrame, bytesPerPixel);
#endif
            MacRedrawBuffer(window, &buffer, bytesPerPixel); 
            flipWallClock = mach_absolute_time();
#if HANDMADE_INTERNAL
            // NOTE(ted):   This is debug code
            {
                marker->FlipWriteCursor = WriteCursor;
                marker->FlipPlayCursor = PlayCursor;
                ++debugTimeMarkerIndex;
                if(debugTimeMarkerIndex >= ArrayCount(debugTimeMarkers)) {
                    debugTimeMarkerIndex = 0;
                }
            }   
#endif
        }
    }
 
    printf("Handmade Finished Running");
}
