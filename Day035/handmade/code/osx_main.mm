// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>

#include "osx_main.h"

global_variable bool Running = true;
global_variable bool IsPaused = false;
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
DEBUG_PLATFORM_FREE_FILE_MEMORY(DEBUGPlatformFreeFileMemory) 
{
    if (Memory) {
        free(Memory);
    }
}

DEBUG_PLATFORM_READ_ENTIRE_FILE(DEBUGPlatformReadEntireFile) 
{
    debug_read_file_result Result = {};
	
    FILE *FileHandle = fopen(Filename, "r");
    if(FileHandle != NULL)
    {
		fseek(FileHandle, 0, SEEK_END);
		uint64 FileSize = ftell(FileHandle);
        if(FileSize)
        {
        	rewind(FileHandle);
        	Result.Contents = malloc(FileSize);
            if(Result.Contents)
            {
                uint64 BytesRead = fread(Result.Contents, 1, FileSize, FileHandle);
                if(FileSize == BytesRead)
                {
                    // NOTE(casey): File read successfully
                    Result.ContentsSize = FileSize;
                }
                else
                {                    
                    // TODO(casey): Logging
                    DEBUGPlatformFreeFileMemory(Thread, Result.Contents);
                    Result.Contents = 0;
                }
            }
            else
            {
                // TODO(casey): Logging
            }
        }
        else
        {
            // TODO(casey): Logging
        }

        fclose(FileHandle);
    }
    else
    {
        // TODO(casey): Logging
    }

    return(Result);
}

DEBUG_PLATFORM_WRITE_ENTIRE_FILE(DEBUGPlatformWriteEntireFile)
{
    bool32 Result = false;
    FILE *FileHandle = fopen(Filename, "w");
    if(FileHandle)
    {
        size_t BytesWritten = fwrite(Memory, 1, FileSize, FileHandle);
        if(BytesWritten)
        {
            // NOTE(casey): File read successfully
            Result = (BytesWritten == FileSize);
        }
        else
        {
            // TODO(casey): Logging
        }

        fclose(FileHandle);
    }
    else
    {
        // TODO(casey): Logging
    }

    return(Result);
}

inline time_t
MacGetLastWriteTime(char *Filename)
{
	time_t LastWriteTime = 0;
	
	struct stat StatData = {};

    if (stat(Filename, &StatData) == 0)
    {
        LastWriteTime = StatData.st_mtime;
    }

    return(LastWriteTime);
}

internal mac_replay_buffer *
MacGetReplayBuffer(mac_state *MacState, int unsigned Index)
{
    Assert(Index < ArrayCount(MacState->ReplayBuffers));
    mac_replay_buffer *ReplayBuffer = &MacState->ReplayBuffers[Index];
    return ReplayBuffer;
}

internal void
MacBeginRecordingInput(thread_context *Thread, mac_state *MacState, int InputRecordingIndex)
{
    mac_replay_buffer *ReplayBuffer = MacGetReplayBuffer(MacState, InputRecordingIndex);
    if (ReplayBuffer->MemoryBlock)
    {
        MacState->InputRecordingIndex = InputRecordingIndex;
        MacState->RecordingHandle = ReplayBuffer->FileHandle;
        fseek(MacState->RecordingHandle, MacState->PermanentStorageSize, SEEK_SET);
        memcpy(ReplayBuffer->MemoryBlock, MacState->GameMemoryBlock, MacState->PermanentStorageSize);
    }
}

internal void
MacEndRecordingInput(mac_state *MacState)
{
    MacState->InputRecordingIndex = 0;
}

internal void
MacBeginInputPlayback(thread_context *Thread, mac_state *MacState, int InputPlayingIndex)
{
    mac_replay_buffer *ReplayBuffer = MacGetReplayBuffer(MacState, InputPlayingIndex);
    if (ReplayBuffer->MemoryBlock)
    {
        MacState->InputPlayingIndex = InputPlayingIndex;
        MacState->PlaybackHandle = ReplayBuffer->FileHandle;
        fseek(MacState->PlaybackHandle, MacState->PermanentStorageSize, SEEK_SET);
        memcpy(MacState->GameMemoryBlock, ReplayBuffer->MemoryBlock, MacState->PermanentStorageSize);
    }
}

internal void
MacEndInputPlayback(mac_state *MacState)
{
    MacState->InputPlayingIndex = 0;
}

internal void
MacRecordInput(mac_state *MacState, game_input *NewInput)
{
    size_t BytesWritten = fwrite(NewInput, sizeof(char), sizeof(*NewInput), MacState->RecordingHandle);
    if (BytesWritten <= 0)
    {
        // TODO: (ted) Log Record Input Failure
    }
}

internal void
MacPlaybackInput(thread_context *Thread, mac_state *MacState, game_input *NewInput)
{
    uint64 BytesRead = fread(NewInput, sizeof(char), sizeof(*NewInput), MacState->PlaybackHandle);
    if (BytesRead <= 0) 
    {
        int PlayingIndex = MacState->InputPlayingIndex;
        MacEndInputPlayback(MacState); 
        MacBeginInputPlayback(Thread, MacState, PlayingIndex);
    }
}

internal mac_game_code 
MacLoadGameCode(char *SourceDLLName)
{
    mac_game_code Result = {};

    Result.DLLLastWriteTime = MacGetLastWriteTime(SourceDLLName);

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
        printf("Dynamic Library Load Error: %s", dlerror());
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
MacDebugDrawVertical(game_offscreen_buffer *Buffer, int x,
                       int top, int bottom, uint32 color) {

    if (top <= 0) {
        top = 0;
    }

    if (bottom > Buffer->Height) {
        bottom = Buffer->Height;
    }

    if ((x >= 0) && (x < Buffer->Width)) {
        uint8 *pixel = ((uint8 *)Buffer->Memory +
                        x*Buffer->BytesPerPixel +
                        top*Buffer->Pitch);

        for (int y = top; y < bottom; ++y) {
            *(uint32 *)pixel = color;
            pixel += Buffer->Pitch; 
        }
    }
}

internal void
MacDrawSoundBufferMarker(game_offscreen_buffer *Buffer, mac_sound_output *SoundOutput,
                         real32 c, int padX, int top, int bottom, uint32 value, 
                         uint32 color) {
    real32 xReal32 = (c * (real32)value);
    int x = padX + (int)xReal32;
    MacDebugDrawVertical(Buffer, x, top, bottom, color);
}

internal void
MacDebugSyncDisplay(game_offscreen_buffer *Buffer, mac_sound_output *SoundOutput,
                      int timeMarkerCount, mac_debug_time_marker *timeMarkers, 
                      int currentMarkerIndex, real32 TargetSecondsPerFrame) {
    int padX = 16;
    int padY = 16;
    int lineHeight = 64; 

    real32 c = (real32)(Buffer->Width - 2*padX) / (real32)SoundOutput->BufferSize;

    for(int markerIndex = 0; markerIndex < timeMarkerCount;
        ++markerIndex) {

        mac_debug_time_marker *thisMarker = &timeMarkers[markerIndex];
        Assert(thisMarker->OutputPlayCursor < SoundOutput->BufferSize);
        Assert(thisMarker->OutputWriteCursor < SoundOutput->BufferSize);
        Assert(thisMarker->OutputLocation < SoundOutput->BufferSize);
        Assert(thisMarker->FlipPlayCursor < SoundOutput->BufferSize);
        Assert(thisMarker->FlipWriteCursor < SoundOutput->BufferSize);

        uint32 playColor = 0xFFFFFFFF;
        uint32 writeColor = 0xFF0000FF;
        uint32 expectedFlipColor = 0xFF00FFFF;

        int top = padY;
        int bottom = padY + lineHeight;

        if (markerIndex == currentMarkerIndex) {
            top += lineHeight+padY;
            bottom += lineHeight+padY;

            int firstTop = top;

            MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputPlayCursor, playColor);
            MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputWriteCursor, writeColor);

            top += lineHeight+padY;
            bottom += lineHeight+padY;

            MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputLocation, playColor);
            MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                       thisMarker->OutputLocation + thisMarker->OutputByteCount, 
                                       writeColor);

            top += lineHeight+padY;
            bottom += lineHeight+padY;

            MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, firstTop, bottom, 
                                       thisMarker->ExpectedFlipPlayCursor, expectedFlipColor);
        }

        MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                   thisMarker->FlipPlayCursor, playColor);
        MacDrawSoundBufferMarker(Buffer, SoundOutput, c, padX, top, bottom, 
                                   thisMarker->FlipWriteCursor, writeColor);
    }
}
#endif

internal
void MacRefreshBuffer(NSWindow *window, game_offscreen_buffer *Buffer) {

    if (Buffer->Memory) {
        free(Buffer->Memory);
    }

    Buffer->Width = (int)window.contentView.bounds.size.width;
    Buffer->Height = (int)window.contentView.bounds.size.height;
    Buffer->Pitch = Buffer->Width * Buffer->BytesPerPixel;
    Buffer->Memory = (uint8 *)malloc((size_t)Buffer->Pitch * (size_t)Buffer->Height);
}

// TODO(ted):   Someone at Apple told me this is really inefficient. Speed up how this is done.
internal
void MacRedrawBuffer(NSWindow *window, game_offscreen_buffer *Buffer) {
    @autoreleasepool {
        uint8* plane = (uint8*)Buffer->Memory;
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &plane 
                                  pixelsWide: Buffer->Width
                                  pixelsHigh: Buffer->Height
                                  bitsPerSample: 8
                                  samplesPerPixel: 4
                                  hasAlpha: YES
                                  isPlanar: NO
                                  colorSpaceName: NSDeviceRGBColorSpace
                                  bitmapFormat: NSBitmapFormatThirtyTwoBitLittleEndian
                                  bytesPerRow: Buffer->Pitch
                                  bitsPerPixel: Buffer->BytesPerPixel * 8] autorelease];

        NSSize imageSize = NSMakeSize(Buffer->Width, Buffer->Height);
        NSImage *image = [[[NSImage alloc] initWithSize: imageSize] autorelease];
        [image addRepresentation: rep];
        window.contentView.layer.contents = image;
    }
}

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 
- (void)windowWillClose:(id)sender {
    Running = false;  
}
@end

@interface HandmadeKeyIgnoringWindow: NSWindow
@end

@implementation HandmadeKeyIgnoringWindow
- (void)keyDown:(NSEvent *)theEvent { }
@end


const unsigned short LeftArrowKeyCode = 0x7B;
const unsigned short RightArrowKeyCode = 0x7C;
const unsigned short DownArrowKeyCode = 0x7D;
const unsigned short UpArrowKeyCode = 0x7E;
const unsigned short AKeyCode = 0x00;
const unsigned short SKeyCode = 0x01;
const unsigned short DKeyCode = 0x02;
const unsigned short FKeyCode = 0x03;
const unsigned short QKeyCode = 0x0C;
const unsigned short RKeyCode = 0x0F;
const unsigned short LKeyCode = 0x25;

internal
void UpdateKeyboardControllerWith(thread_context *Thread, mac_game_controller *MacKeyboardController, 
                                  NSEvent *Event, mac_state *MacState) {

    switch ([Event type]) {
        case NSEventTypeKeyDown:
            if (Event.keyCode == LeftArrowKeyCode &&
                MacKeyboardController->DPadX != 1)
            {
                MacKeyboardController->DPadX = -1;
                break;
            }
            else if (Event.keyCode == RightArrowKeyCode &&
                     MacKeyboardController->DPadX != -1)
            {
                MacKeyboardController->DPadX = 1;
                break;
            }
            else if (Event.keyCode == DownArrowKeyCode &&
                     MacKeyboardController->DPadY != 1)
            {
                MacKeyboardController->DPadY = -1;
                break;
            }
            else if (Event.keyCode == UpArrowKeyCode &&
                     MacKeyboardController->DPadY != -1)
            {
                MacKeyboardController->DPadY = 1;
                break;
            }
            else if (Event.keyCode == AKeyCode)
            {
                MacKeyboardController->ButtonAState = 1;
                break;
            }
            else if (Event.keyCode == SKeyCode)
            {
                MacKeyboardController->ButtonBState = 1;
                break;
            }
            else if (Event.keyCode == DKeyCode)
            {
                MacKeyboardController->ButtonXState = 1;
                break;
            }
            else if (Event.keyCode == FKeyCode)
            {
                MacKeyboardController->ButtonYState = 1;
                break;
            }
            else if (Event.keyCode == QKeyCode)
            {
                MacKeyboardController->ButtonLeftShoulderState = 1;
                break;
            }
            else if (Event.keyCode == RKeyCode)
            {
                MacKeyboardController->ButtonRightShoulderState = 1;
                break;
            }
            else if (Event.keyCode == LKeyCode)
            {
                if (MacState->InputPlayingIndex == 0)
                {
                    if (MacState->InputRecordingIndex == 0)
                    {
                        MacBeginRecordingInput(Thread, MacState, 1);
                        MacState->InputRecordingIndex = 1;
                    } else 
                    {
                        MacEndRecordingInput(MacState);
                        MacBeginInputPlayback(Thread, MacState, 1);
                        MacState->InputRecordingIndex = 0;
                        MacState->InputPlayingIndex = 1;
                    }
                } else {
                    MacEndInputPlayback(MacState);
                }
                break;
            }

        case NSEventTypeKeyUp:
            if (Event.keyCode == LeftArrowKeyCode &&
                MacKeyboardController->DPadX == -1)
            {
                MacKeyboardController->DPadX = 0;
                break;
            } 
            else if (Event.keyCode == RightArrowKeyCode &&
                     MacKeyboardController->DPadX == 1)
            {
                MacKeyboardController->DPadX = 0;
                break;
            }
            else if (Event.keyCode == DownArrowKeyCode &&
                     MacKeyboardController->DPadY == -1)
            {
                MacKeyboardController->DPadY = 0;
                break;
            }
            else if (Event.keyCode == UpArrowKeyCode &&
                     MacKeyboardController->DPadY == 1)
            {
                MacKeyboardController->DPadY = 0;
                break;
            }
            else if (Event.keyCode == AKeyCode)
            {
                MacKeyboardController->ButtonAState = 0;
                break;
            }
            else if (Event.keyCode == SKeyCode)
            {
                MacKeyboardController->ButtonBState = 0;
                break;
            }
#if HANDMADE_INTERNAL
            else if (Event.keyCode == DKeyCode)
            {
                IsPaused = !IsPaused;
                break;
            }
#endif
            else if (Event.keyCode == DKeyCode)
            {
                MacKeyboardController->ButtonXState = 0;
                break;
            }
            else if (Event.keyCode == FKeyCode)
            {
                MacKeyboardController->ButtonYState = 0;
                break;
            }
            else if (Event.keyCode == QKeyCode)
            {
                MacKeyboardController->ButtonLeftShoulderState = 0;
                break;
            }
            else if (Event.keyCode == RKeyCode) 
            {
                MacKeyboardController->ButtonRightShoulderState = 0;
                break;
            }
            else if (Event.keyCode == LKeyCode) 
            {
                break;
            }
        default:
        break;
    }
}

internal 
void ControllerInput(void *context, IOReturn result, 
                     void *sender, IOHIDValueRef value)
{
    if(result != kIOReturnSuccess) {
        return;
    }

    mac_game_controller *MacGameController = (mac_game_controller *)context;
    
    IOHIDElementRef Element = IOHIDValueGetElement(value);    
    uint32 UsagePage = IOHIDElementGetUsagePage(Element);
    uint32 Usage = IOHIDElementGetUsage(Element);

    //Buttons
    if(UsagePage == kHIDPage_Button) {
        // TODO: (ted)  Use our own Boolean type here?
        BOOL ButtonState = (BOOL)IOHIDValueGetIntegerValue(value);

        if (Usage == MacGameController->ButtonAUsageID) 
        { 
            MacGameController->ButtonAState = ButtonState; 
        } else if (Usage == MacGameController->ButtonBUsageID)
        { 
            MacGameController->ButtonBState = ButtonState; 
        } else if(Usage == MacGameController->ButtonXUsageID) 
        { 
            MacGameController->ButtonXState = ButtonState; 
        } else if(Usage == MacGameController->ButtonYUsageID) 
        { 
            MacGameController->ButtonYState = ButtonState; 
        } else if(Usage == MacGameController->ButtonLeftShoulderUsageID) 
        { 
            MacGameController->ButtonLeftShoulderState = ButtonState; 
        } else if(Usage == MacGameController->ButtonRightShoulderUsageID) 
        { 
            MacGameController->ButtonRightShoulderState = ButtonState; 
        }
    }

    //dPad
    else if(UsagePage == kHIDPage_GenericDesktop) {

        double_t Analog = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated);
        
        if (Usage == MacGameController->LeftThumbXUsageID) {
            MacGameController->LeftThumbstickX = (real32)Analog;
        }

        if (Usage == MacGameController->LeftThumbYUsageID) {
            MacGameController->LeftThumbstickY = (real32)Analog;
        }

        if(Usage == kHIDUsage_GD_Hatswitch) { 
            int DPadState = (int)IOHIDValueGetIntegerValue(value);
            int32 DPadX = 0;
            int32 DPadY = 0;

            switch(DPadState) {
                case 0: DPadX = 0; DPadY = 1; break;
                case 1: DPadX = 1; DPadY = 1; break;
                case 2: DPadX = 1; DPadY = 0; break;
                case 3: DPadX = 1; DPadY = -1; break;
                case 4: DPadX = 0; DPadY = -1; break;
                case 5: DPadX = -1; DPadY = -1; break;
                case 6: DPadX = -1; DPadY = 0; break;
                case 7: DPadX = -1; DPadY = 1; break;
                default: DPadX = 0; DPadY = 0; break;
            }

            MacGameController->DPadX = DPadX;
            MacGameController->DPadY = DPadY;
        }
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

    mac_game_controller *MacGameController = (mac_game_controller *)context;

    if(vendorID == 0x054C && productID == 0x5C4) {
        NSLog(@"Sony Dualshock 4 detected.");

        //  Left Thumb Stick       
        MacGameController->LeftThumbXUsageID = kHIDUsage_GD_X;
        MacGameController->LeftThumbYUsageID = kHIDUsage_GD_Y;
        MacGameController->UsesHatSwitch = true;
 
        MacGameController->ButtonAUsageID = 0x02;
        MacGameController->ButtonBUsageID = 0x03;
        MacGameController->ButtonXUsageID = 0x01;
        MacGameController->ButtonYUsageID = 0x04;
        MacGameController->ButtonLeftShoulderUsageID = 0x05;
        MacGameController->ButtonRightShoulderUsageID = 0x06;
    }
    
    MacGameController->LeftThumbstickX = 128.0f;
    MacGameController->LeftThumbstickY = 128.0f;

    // TODO (ted):  Have this register multiple times for multiple controllers.
    IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (void *)MacGameController);  
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);
}


internal
void MacInitGameControllers(mac_game_controller *MacGameController) {
    IOHIDManagerRef HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);

    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    // TODO (ted):  Figure out how to match multiple game controllers to the different
    //              HID callbacks
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, ControllerConnected, (void *)MacGameController);

    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
    ]);
  
	IOHIDManagerScheduleWithRunLoop(HIDManager, 
                                    CFRunLoopGetMain(), 
                                    kCFRunLoopDefaultMode);
}

OSStatus 
CircularBufferRenderCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             uint32 inBusNumber,
                             uint32 inNumberFrames,
                             AudioBufferList *ioData) 
{
    mac_sound_output *SoundOutput = (mac_sound_output*)inRefCon;

    uint32 length = inNumberFrames * SoundOutput->BytesPerSample; 
    uint32 region1Size = length;
    uint32 region2Size = 0;

    if (SoundOutput->PlayCursor + length > SoundOutput->BufferSize) {
        region1Size = SoundOutput->BufferSize - SoundOutput->PlayCursor;
        region2Size = length - region1Size;
    } 
   
    uint8* channel = (uint8*)ioData->mBuffers[0].mData;

    memcpy(channel, 
           (uint8*)SoundOutput->Data + SoundOutput->PlayCursor, 
           region1Size);

    memcpy(&channel[region1Size],
           SoundOutput->Data,
           region2Size);

    SoundOutput->PlayCursor = (SoundOutput->PlayCursor + length) % SoundOutput->BufferSize;
    SoundOutput->WriteCursor = (SoundOutput->PlayCursor + length) % SoundOutput->BufferSize;

    return noErr;
}

internal
void MacInitSound(mac_sound_output *SoundOutput)
{
    //Create a two second circular buffer 
    SoundOutput->SamplesPerSecond = 48000; 
    SoundOutput->RunningSampleIndex = 0;
    uint32 audioFrameSize = sizeof(int16) * 2;
    uint32 numberOfSeconds = 2; 
    SoundOutput->BytesPerSample = audioFrameSize; 
    SoundOutput->BufferSize = SoundOutput->SamplesPerSecond * audioFrameSize * numberOfSeconds;
    SoundOutput->Data = malloc(SoundOutput->BufferSize);
    SoundOutput->PlayCursor = SoundOutput->WriteCursor = 0;

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
    audioDescriptor.mSampleRate = SoundOutput->SamplesPerSecond;
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
    renderCallback.inputProcRefCon = SoundOutput;

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
MacFillSoundBuffer(int ByteToLock, int BytesToWrite,
                   game_sound_output_buffer *SoundBuffer, mac_sound_output *SoundOutput) 
{
    int16_t *Samples = SoundBuffer->Samples;
    void *region1 = (uint8*)SoundOutput->Data + ByteToLock;
    int region1Size = BytesToWrite;
    if (region1Size + ByteToLock > SoundOutput->BufferSize)
    {
        region1Size = SoundOutput->BufferSize - ByteToLock;
    }
    void *region2 = SoundOutput->Data;
    int region2Size = BytesToWrite - region1Size;
    int region1SampleCount = region1Size/SoundOutput->BytesPerSample;
    int16 *sampleOut = (int16 *)region1;
    for(int sampleIndex = 0;
        sampleIndex < region1SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *Samples++;
        *sampleOut++ = *Samples++;

        ++SoundOutput->RunningSampleIndex;
    }

    int region2SampleCount = region2Size/SoundOutput->BytesPerSample;
    sampleOut = (int16 *)region2;
    for(int sampleIndex = 0;
        sampleIndex < region2SampleCount;
        ++sampleIndex)
    {
        *sampleOut++ = *Samples++;
        *sampleOut++ = *Samples++;
        ++SoundOutput->RunningSampleIndex;
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

    HandmadeMainWindowDelegate *MainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

    float GlobalRenderWidth = 960;
    float GlobalRenderHeight = 540;

    NSRect InitialFrame = NSMakeRect((ScreenRect.size.width - GlobalRenderWidth) * 0.5,
                                     (ScreenRect.size.height - GlobalRenderHeight) * 0.5,
                                     GlobalRenderWidth,
                                     GlobalRenderHeight);
  
    NSWindow *Window = [[HandmadeKeyIgnoringWindow alloc] 
                         initWithContentRect: InitialFrame
                         styleMask: NSWindowStyleMaskTitled |
                                    NSWindowStyleMaskClosable |
                                    NSWindowStyleMaskResizable
                                    backing: NSBackingStoreBuffered
                         defer: NO];    

    [Window setBackgroundColor: NSColor.blackColor];
    [Window setTitle: @"Handmade Hero"];
    [Window makeKeyAndOrderFront: nil];
    [Window setDelegate: MainWindowDelegate];
    Window.contentView.layerContentsPlacement = NSViewLayerContentsPlacementCenter;
    Window.contentView.layer.contentsGravity = kCAGravityCenter;
    Window.contentView.wantsLayer = YES;

    thread_context Thread = {};

    game_offscreen_buffer Buffer = {};
    Buffer.BytesPerPixel = 4;

    MacRefreshBuffer(Window, &Buffer);

#if HANDMADE_INTERNAL
    char* BaseAddress = (char*)Gigabytes(8);
    uint32 AllocationFlags = MAP_PRIVATE | MAP_ANON | MAP_FIXED;
#else
    void* BaseAddress = 0;
    uint32 AllocationFlags = MAP_PRIVATE | MAP_ANON;
#endif

    mac_state MacState = {};
    MacGetAppFileName(&MacState);

	char SourceGameCodeDLLFullPath[MAC_MAX_FILENAME_SIZE];
    MacBuildAppPathFileName(&MacState, "Contents/Resources/GameCode.dylib",
                               sizeof(SourceGameCodeDLLFullPath), SourceGameCodeDLLFullPath);

	MacBuildAppPathFileName(&MacState, "../Resources/",
							sizeof(MacState.ResourcesDirectory), MacState.ResourcesDirectory);
	MacState.ResourcesDirectorySize = StringLength(MacState.ResourcesDirectory);

    game_memory GameMemory = {};
    GameMemory.PermanentStorageSize = Megabytes(64);
    GameMemory.TransientStorageSize = Gigabytes(4);
    MacState.PermanentStorageSize = GameMemory.PermanentStorageSize;
    GameMemory.DEBUGPlatformReadEntireFile = DEBUGPlatformReadEntireFile;
    GameMemory.DEBUGPlatformFreeFileMemory = DEBUGPlatformFreeFileMemory;
    GameMemory.DEBUGPlatformWriteEntireFile = DEBUGPlatformWriteEntireFile;

    // TODO: (ted)  Transient storage needs to be broken up into game transient and cache transient.
    //              and only the former need be saved for state playback.
    MacState.GameMemoryBlock = mmap(BaseAddress,
                                    GameMemory.PermanentStorageSize,
                                    PROT_READ | PROT_WRITE,
                                    AllocationFlags, -1, 0); 

    GameMemory.PermanentStorage = MacState.GameMemoryBlock; 

    if (GameMemory.PermanentStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate permanent storage"];
    }
   
    uint8* TransientStorageAddress = ((uint8*)GameMemory.PermanentStorage + GameMemory.PermanentStorageSize);
    GameMemory.TransientStorage = mmap(TransientStorageAddress,
                                       GameMemory.TransientStorageSize,
                                       PROT_READ | PROT_WRITE,
                                       AllocationFlags, -1, 0); 

    if (GameMemory.TransientStorage == MAP_FAILED) {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Game Memory Not Allocated"
                     format: @"Failed to allocate transient storage"];
    }

    // TODO: (ted)  Make this use the full storage when the game starts using it.
    for(int ReplayIndex = 0;
        ReplayIndex < ArrayCount(MacState.ReplayBuffers);
        ++ReplayIndex)
    {
        mac_replay_buffer *ReplayBuffer = &MacState.ReplayBuffers[ReplayIndex];
        int FileDescriptor;
        mode_t Mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
        char Filename[MAC_MAX_FILENAME_SIZE];
        char LocalFilename[MAC_MAX_FILENAME_SIZE];
        sprintf(LocalFilename, "Contents/Resources/ReplayBuffer%d", ReplayIndex);
        MacBuildAppPathFileName(&MacState, LocalFilename,
                                sizeof(Filename), Filename);
        FileDescriptor = open(Filename, O_CREAT | O_RDWR, Mode);
        int Result = truncate(Filename, GameMemory.PermanentStorageSize);

        if (Result < 0)
        {
            // TODO: (ted)  Log This
        }

        ReplayBuffer->MemoryBlock = mmap(0, GameMemory.PermanentStorageSize,
                                         PROT_READ | PROT_WRITE,
                                         MAP_PRIVATE, FileDescriptor, 0);
        ReplayBuffer->FileHandle = fopen(Filename, "r+");
        fseek(ReplayBuffer->FileHandle, MacState.PermanentStorageSize, SEEK_SET);
        if (ReplayBuffer->MemoryBlock)
        {
        } else {
            // TODO: (casey)    Diagnostic
        }
    }

    mac_game_controller MacGameControllers[2] = {};

    mac_game_controller *MacGameController = &MacGameControllers[1]; 
    MacInitGameControllers(MacGameController); 

    mac_game_controller *MacKeyboardController = &MacGameControllers[0]; 
    MacKeyboardController->UsesHatSwitch = false;

    mac_sound_output SoundOutput = {};
    MacInitSound(&SoundOutput);

    int MonitorRefreshHz = 60;
    uint32 GameUpdateHzInt = MonitorRefreshHz/2;
    real32 GameUpdateHz = (MonitorRefreshHz / 2.0f);
    real32 TargetSecondsPerFrame = 1.0f / (real32)GameUpdateHz;

    game_input Input[2] = {};
    game_input *NewInput = &Input[0];
    game_input *OldInput = &Input[1];
    
    int16 *Samples = (int16*)calloc(SoundOutput.SamplesPerSecond,
                                    SoundOutput.BytesPerSample); 

    // TODO: (ted)  Compute this variance and see what the lowest reasonable value is
    SoundOutput.SafetyBytes = ((SoundOutput.SamplesPerSecond*SoundOutput.BytesPerSample)/GameUpdateHzInt)/3;

    uint64 CurrentTime = mach_absolute_time();
    uint64 LastCounter = CurrentTime;
    real32 FrameTime = 0.0f; 
    
    uint64 FlipWallClock = mach_absolute_time();

    bool32 SoundIsValid = false;

#if HANDMADE_INTERNAL
    int DebugTimeMarkerIndex = 0;
    mac_debug_time_marker DebugTimeMarkers[15] = {};
#endif

    mac_game_code Game = MacLoadGameCode(SourceGameCodeDLLFullPath);

    while(Running) {

        // TODO(ted):   Figure out why this Event loop code was interfering with
        //              the buffer refresh
        NSEvent* Event;
        
        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (Event != nil &&
                (Event.type == NSEventTypeKeyDown ||
                Event.type == NSEventTypeKeyUp)) {
                UpdateKeyboardControllerWith(&Thread, MacKeyboardController, Event, &MacState);
            }
 
            switch ([Event type]) {
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);
    
        NewInput->dtForFrame = TargetSecondsPerFrame;

        NSPoint MouseP = Window.mouseLocationOutsideOfEventStream;
        NewInput->MouseX = (int32)MouseP.x;
        NewInput->MouseY = (int32)(GlobalRenderHeight - MouseP.y);
        NewInput->MouseZ = 0;
        bool32 MouseDown0 = (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 0));
        MacProcessGameControllerButton(&OldInput->MouseButtons[0],
                                       &NewInput->MouseButtons[0],
                                       MouseDown0); 

        bool32 MouseDown1 = (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 1));
        MacProcessGameControllerButton(&OldInput->MouseButtons[1],
                                       &NewInput->MouseButtons[1],
                                       MouseDown1); 

        bool32 MouseDown2 = (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, 2));
        MacProcessGameControllerButton(&OldInput->MouseButtons[2],
                                       &NewInput->MouseButtons[2],
                                       MouseDown2); 

        for (int ControllerIndex = 0; ControllerIndex < 2; ControllerIndex++) {

            mac_game_controller Controller = MacGameControllers[ControllerIndex];

            game_controller_input *OldController = &OldInput->Controllers[ControllerIndex];
            game_controller_input *NewController = &NewInput->Controllers[ControllerIndex];

            MacProcessGameControllerButton(&(OldController->A),
                                             &(NewController->A),
                                             Controller.ButtonAState); 

            MacProcessGameControllerButton(&(OldController->B),
                                             &(NewController->B),
                                             Controller.ButtonBState); 

            MacProcessGameControllerButton(&(OldController->X),
                                             &(NewController->X),
                                             Controller.ButtonXState); 

            MacProcessGameControllerButton(&(OldController->Y),
                                             &(NewController->Y),
                                             Controller.ButtonYState); 

            MacProcessGameControllerButton(&(OldController->LeftShoulder),
                                             &(NewController->LeftShoulder),
                                             Controller.ButtonLeftShoulderState); 
           
            MacProcessGameControllerButton(&(OldController->RightShoulder),
                                             &(NewController->RightShoulder),
                                             Controller.ButtonRightShoulderState); 
 
            if (Controller.DPadX == 1) {
                MacProcessGameControllerButton(&(OldController->Right),
                                                 &(NewController->Right),
                                                 true); 
                MacProcessGameControllerButton(&(OldController->Left),
                                                 &(NewController->Left),
                                                 false); 
            } else if (Controller.DPadX == -1) {
                MacProcessGameControllerButton(&(OldController->Right),
                                                 &(NewController->Right),
                                                 false); 
                MacProcessGameControllerButton(&(OldController->Left),
                                                 &(NewController->Left),
                                                 true); 
            } else if (Controller.DPadX == 0) {
                MacProcessGameControllerButton(&(OldController->Right),
                                                 &(NewController->Right),
                                                 false); 
                MacProcessGameControllerButton(&(OldController->Left),
                                                 &(NewController->Left),
                                                 false); 
            }

            if (Controller.DPadY == 1) {
                MacProcessGameControllerButton(&(OldController->Up),
                                                 &(NewController->Up),
                                                 true); 
                MacProcessGameControllerButton(&(OldController->Down),
                                                 &(NewController->Down),
                                                 false); 
            } else if (Controller.DPadY == -1) {
                MacProcessGameControllerButton(&(OldController->Up),
                                                 &(NewController->Up),
                                                 false); 
                MacProcessGameControllerButton(&(OldController->Down),
                                                 &(NewController->Down),
                                                 true); 
            } else if (Controller.DPadY == 0) {
                MacProcessGameControllerButton(&(OldController->Up),
                                                 &(NewController->Up),
                                                 false); 
                MacProcessGameControllerButton(&(OldController->Down),
                                                 &(NewController->Down),
                                                 false); 
            }

            NewController->IsAnalog = Controller.UsesHatSwitch;
            NewController->StartX = OldController->EndX;
            NewController->StartY = OldController->EndY;

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
            NewController->EndX = (real32)(Controller.LeftThumbstickX - 127.5f)/127.5f;
            NewController->EndY = (real32)(Controller.LeftThumbstickY - 127.5f)/127.5f;

            NewController->MinX = NewController->MaxX = NewController->EndX;            
            NewController->MinY = NewController->MaxY = NewController->EndY;            

            real32 DeadZone = 0.15f;
            real32 ScalarEndX = abs(NewController->EndX);
            real32 ScalarEndY = abs(NewController->EndY);

            if (ScalarEndX < DeadZone)
            {
                NewController->EndX = 0.0f;
            }

            if (ScalarEndY < DeadZone)
            {
                NewController->EndY = 0.0f;
            }

            NewController->IsAnalog = OldController->IsAnalog;
    
            if (ScalarEndX > DeadZone || ScalarEndY > DeadZone)
            {
                NewController->IsAnalog = true;
            } else 
            {
                NewController->IsAnalog = false;
            }
        }
        
        
        time_t NewDLLWriteTime = MacGetLastWriteTime(SourceGameCodeDLLFullPath);
        if(NewDLLWriteTime > Game.DLLLastWriteTime)
        {
            MacUnloadGameCode(&Game);
            Game = MacLoadGameCode(SourceGameCodeDLLFullPath);
        }

        if (!IsPaused) {

            if (MacState.InputRecordingIndex)
            {
                MacRecordInput(&MacState, NewInput); 
            }

            if (MacState.InputPlayingIndex)
            {
                MacPlaybackInput(&Thread, &MacState, NewInput); 
            }

            GameMemory.PermanentStorage = MacState.GameMemoryBlock; 

            if (Game.UpdateAndRender)
            {
                Game.UpdateAndRender(&Thread, &GameMemory, NewInput, &Buffer); 
            }

//            uint64 audioWallClock = mach_absolute_time();
//            real32 fromBeginToAudioSeconds = MacGetSecondsElapsed(FlipWallClock, audioWallClock);

            uint32 PlayCursor = SoundOutput.PlayCursor;
            uint32 WriteCursor = SoundOutput.WriteCursor;

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
            if (!SoundIsValid) {
                SoundOutput.RunningSampleIndex = WriteCursor / SoundOutput.BytesPerSample;
                SoundIsValid = true;
            }

            int ByteToLock = 0;
            int BytesToWrite = 0;

            ByteToLock = (SoundOutput.RunningSampleIndex*SoundOutput.BytesPerSample) % SoundOutput.BufferSize; 

            uint32 ExpectedSoundBytesPerFrame = 
                (SoundOutput.SamplesPerSecond*SoundOutput.BytesPerSample)/GameUpdateHzInt;

//            real32 secondsLeftUntilFlip = (TargetSecondsPerFrame - fromBeginToAudioSeconds);
//            uint32 expectedBytesUntilFlip = 
//                (uint32)((secondsLeftUntilFlip/TargetSecondsPerFrame)*(real32)ExpectedSoundBytesPerFrame);

            uint32 ExpectedFrameBoundaryByte = PlayCursor + ExpectedSoundBytesPerFrame;

            uint32 SafeWriteCursor = WriteCursor;
            if (SafeWriteCursor < PlayCursor) {
                SafeWriteCursor += SoundOutput.BufferSize;
            }
            Assert(SafeWriteCursor >= PlayCursor);
            SafeWriteCursor += SoundOutput.SafetyBytes;

            bool32 AudioCardIsLowLatency = (SafeWriteCursor < ExpectedFrameBoundaryByte);

            int TargetCursor;
        
            if (AudioCardIsLowLatency) {
                TargetCursor = (ExpectedFrameBoundaryByte + ExpectedSoundBytesPerFrame);
            } else {
                TargetCursor = (WriteCursor + ExpectedSoundBytesPerFrame + SoundOutput.SafetyBytes);
            }

            TargetCursor = TargetCursor % SoundOutput.BufferSize;

             if (ByteToLock > TargetCursor) {
                BytesToWrite = (SoundOutput.BufferSize - ByteToLock);
                BytesToWrite += TargetCursor;
            } else {
                BytesToWrite = TargetCursor - ByteToLock;
            }

            game_sound_output_buffer SoundBuffer = {};
            SoundBuffer.SamplesPerSecond = SoundOutput.SamplesPerSecond;
            SoundBuffer.SampleCount = BytesToWrite / SoundOutput.BytesPerSample;
            SoundBuffer.Samples = Samples;
            
            if (Game.GetSoundSamples)
            {
                Game.GetSoundSamples(&Thread, &GameMemory, &SoundBuffer);
            }

#if HANDMADE_INTERNAL
            mac_debug_time_marker *Marker = &DebugTimeMarkers[DebugTimeMarkerIndex];
            Marker->OutputPlayCursor = PlayCursor;
            Marker->OutputWriteCursor = WriteCursor;
            Marker->OutputLocation = ByteToLock;
            Marker->OutputByteCount = BytesToWrite;
            Marker->ExpectedFlipPlayCursor = ExpectedFrameBoundaryByte;
#endif
            MacFillSoundBuffer(ByteToLock, BytesToWrite, &SoundBuffer, &SoundOutput);

            game_input *Temp = NewInput;
            NewInput = OldInput;
            OldInput = Temp;

            uint64 WorkCounter = mach_absolute_time();
            real32 WorkSecondsElapsed = MacGetSecondsElapsed(LastCounter, WorkCounter);

            real32 SecondsElapsedForFrame = WorkSecondsElapsed;
            if(SecondsElapsedForFrame < TargetSecondsPerFrame) {
                // NOTE(ted):   Using an under offset to get slighlty under the target, then spin up to it.
                real32 UnderOffset = 3.0f / 1000.0f;
                useconds_t SleepMS;

                if ((TargetSecondsPerFrame - SecondsElapsedForFrame - UnderOffset < 0)) {
                    // NOTE(ted):   This happens when the under offset subtraction gives integer
                    //              underflow. Don't apply an offset in this case.
                    UnderOffset = 0;
                } 

                SleepMS = (useconds_t)(1000.0f * 1000.0f * (TargetSecondsPerFrame -
                           SecondsElapsedForFrame - UnderOffset));

                if(SleepMS > 0)
                {
                    usleep(SleepMS);
                }

                real32 TestSecondsElapsedForFrame = MacGetSecondsElapsed(LastCounter,
                        mach_absolute_time());
                if(TestSecondsElapsedForFrame < TargetSecondsPerFrame)
                {
                    // TODO(casey): LOG MISSED SLEEP HERE
                }

                while(SecondsElapsedForFrame < TargetSecondsPerFrame)
                {
                    SecondsElapsedForFrame = MacGetSecondsElapsed(LastCounter, mach_absolute_time());
                }
            }
            else
            {
                // TODO(casey): MISSED FRAME RATE!
                // TODO(casey): Logging
            }

            uint64 EndOfFrame = mach_absolute_time();
            uint64 FrameElapsed = EndOfFrame - LastCounter;
            uint64 FrameNanoseconds = FrameElapsed * globalPerfCountFrequency.numer / globalPerfCountFrequency.denom;

            real32 MeasuredSecondsPerFrame = (real32)FrameNanoseconds * 1.0E-9f;
#if 0
            real32 MeasuredMillsecondsPerFrame = (real32)FrameNanoseconds * 1.0E-6f;
            real32 MeasuredFramesPerSecond = 1.0f / MeasuredSecondsPerFrame;

            NSLog(@"Frames Per Second %f", MeasuredFramesPerSecond); 
            NSLog(@"Millseconds Per Frame %f", MeasuredMillsecondsPerFrame); 
#endif

            FrameTime += MeasuredSecondsPerFrame;
            LastCounter = EndOfFrame;

#if HANDMADE_INTERNAL
            // TODO (casey):    Current is wrong on the zeroeth index
            /* MacDebugSyncDisplay(&Buffer, &SoundOutput, DebugTimeMarkerIndex, DebugTimeMarkers, */ 
            /*                     (DebugTimeMarkerIndex - 1), TargetSecondsPerFrame); */
#endif
            MacRedrawBuffer(Window, &Buffer); 
            FlipWallClock = mach_absolute_time();
#if HANDMADE_INTERNAL
            // NOTE(ted):   This is debug code
            {
                Marker->FlipWriteCursor = WriteCursor;
                Marker->FlipPlayCursor = PlayCursor;
                ++DebugTimeMarkerIndex;
                if(DebugTimeMarkerIndex >= ArrayCount(DebugTimeMarkers)) {
                    DebugTimeMarkerIndex = 0;
                }
            }   
#endif
        }
    }
 
    printf("Handmade Finished Running");
}
