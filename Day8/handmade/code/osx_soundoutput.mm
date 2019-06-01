global_variable MacOSSoundOutput soundOutput = {};


OSStatus circularBufferRenderCallback(void *inRefCon,
                                      AudioUnitRenderActionFlags *ioActionFlags,
                                      const AudioTimeStamp *inTimeStamp,
                                      uint32 inBusNumber,
                                      uint32 inNumberFrames,
                                      AudioBufferList *ioData) {
    
    int16* channel = (int16*)ioData->mBuffers[0].mData;

    for (uint32 i = 0; i < inNumberFrames; ++i) {
        *channel++ = *soundOutput.readCursor++;
        *channel++ = *soundOutput.readCursor++;

        if ((char *)soundOutput.readCursor >= (char *)((char *)soundOutput.coreAudioBuffer + soundOutput.bufferSize)) {
            soundOutput.readCursor = soundOutput.coreAudioBuffer;
        }
    }

    return noErr;
}

internal_usage
void macOSInitSound() {
  
    //Create a two second circular buffer 
    soundOutput.samplesPerSecond = 48000; 
    int audioFrameSize = sizeof(int16) * 2;
    int numberOfSeconds = 2; 
    soundOutput.bufferSize = soundOutput.samplesPerSecond * audioFrameSize * numberOfSeconds;

    soundOutput.coreAudioBuffer = (int16*)mmap(0,
                                               soundOutput.bufferSize,
                                               PROT_READ|PROT_WRITE,
                                               MAP_PRIVATE|MAP_ANON,
                                               -1,
                                               0);
 
    //todo: (ted) better error handling 
    if (soundOutput.coreAudioBuffer == MAP_FAILED) {
        NSLog(@"Core Audio Buffer mmap error");
        return;
    }

    memset(soundOutput.coreAudioBuffer,
           0,
           soundOutput.bufferSize);

    soundOutput.readCursor = soundOutput.coreAudioBuffer;
    soundOutput.writeCursor = soundOutput.coreAudioBuffer;

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
   
    //todo: (ted) - Better error handling 
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

    //todo: (ted) - Better error handling 
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

    //todo: (ted) - Better error handling 
    if (status != noErr) {
        NSLog(@"There was an error setting up the audio unit");
        return;
    }

    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

internal_usage
void updateSoundBuffer() {
  
    int sampleCount = 1600;
 
    //note: (ted) - This is where we would usually get sound samples
    uint32 frequency = 256;
    uint32 period = soundOutput.samplesPerSecond/frequency; 
    uint32 halfPeriod = period/2;
    local_persist uint32 runningSampleIndex = 0;
 
    for (int i = 0; i < sampleCount; ++i) {

        //Write cursor wrapped. Start at the beginning of the Core Audio Buffer.
        if ((char *)soundOutput.writeCursor >= ((char *)soundOutput.coreAudioBuffer + soundOutput.bufferSize)) {
            
            if (soundOutput.readCursor == soundOutput.coreAudioBuffer) {
                break;
            }

            soundOutput.writeCursor = soundOutput.coreAudioBuffer;
        }

        if ((char *)soundOutput.writeCursor == ((char *)soundOutput.readCursor - (2 * sizeof(int16)))) {
            break;
        }

        int16 sampleValue;

        if((runningSampleIndex%period) > halfPeriod) {
            sampleValue = 5000;
        } else {
            sampleValue = -5000;
        }

        *soundOutput.writeCursor++ = sampleValue;
        *soundOutput.writeCursor++ = sampleValue;
        runningSampleIndex++; 
    }
}
