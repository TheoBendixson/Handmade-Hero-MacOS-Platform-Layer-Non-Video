#Handmade Hero Mac OS Platform Layer, Day 7; Initializing Core Audio.
We are now seven days into building the Mac OS platform layer for Handmade Hero. Time really flies. I started this project back in the beginning of snowboarding season for me, and I've been chipping away it in my spare time. I've recently found some extra time to work on it, and that has been truly educational, but also tons of fun. So I'm happy there are others who can share the joy of programming with me.

At this point, we've got a basic graphics render buffer and the ability to control it with the system keyboard or the Sony Dual Shock 4 game controller. For most games, that's a solid 2/3 of the experience. You've got the eyes and the hands.

Of course, very few video games would be complete without audio. Sound adds an entirely different dimension to the experience, and it often defines what you remember most about games. To this day, both my spouse and I can instantly recognize the chiptune Mega Man themes from our childhoods. We can hear a song and immediately identify the robot boss and level it goes with.

This is actually kind of astonishing if you think about it. Of all the sounds we've heard throughout our lives, and subsequently thrown away, we decided to retain these. If audio weren't important, this just wouldn't be possible.

##What We Will Be Covering
We are synced back up with Casey again. On day 7, he tackles DirectSound on Windows. Today, we will tackle the basics of CoreAudio on the Mac (and technically iOS since it works in a very similar way).

The goal of this article is to get you to a point where you've got the ability to listen to a rudimentary square wave on your Mac. The output won't be perfect since we won't be using a circular buffer (yet), but we will get all of the basic setup taken care of so we can focus on the more advanced stuff in the next article.

##Acknowledgements
Matt Gallagher's [Cocoa With Love](http://www.cocoawithlove.com) has been incredibly helpful in putting this series together. [He has an excellent article on how to play a single tone](http://www.cocoawithlove.com/2010/10/ios-tone-generator-introduction-to.html), and I drew plenty of inspiration from it.

Of course, I keep coming back to [Jeff Buck's Handmade Hero Mac OS github repository](https://github.com/itfrombit/osx_handmade). Many of the ideas you see presented here come from the work he's done. As I like to say, there's nothing all that special about what I'm doing. I am simply taking much of what Jeff has done and presenting it in a more digestible way so you can follow Casey's series. 

##Core Audio and Sound on The Mac
When you start writing code that interfaces with speakers and audio equipment for the Mac, you're sort of walking into this labyrinth of different libraries and tools, all occupying various levels of abstraction. Some of those tools are meant to be used at the highest level so you don't have to think about how to load a wave or mp3 file into a sound buffer, while others are so low-level they don't hold your hand at all (but you can do anything).

Core Audio and AudioToolbox represent the lowest-level of sound processing you can do on the Mac. They're just a collection of different structs and functions with extremely sparse documentation on how to use them. If it weren't for Matt Gallagher's excellent post, I simply would not have known where to get started with this.

##Including The Libraries
First things first, let's add the appropriate library to the build script. Open up the build.sh script, and add AudioToolBox to the OSX_LDFlags variable so it looks like so.

'''sh script
OSX_LD_FLAGS="-framework AppKit 
              -framework IOKit
              -framework AudioToolbox"
'''

Now, navigate to the top of the osx_main.mm file. Paste the following line directly below the line where you import AppKit.

'''Objective-C++
#import <AudioToolbox/AudioToolbox.h>
''' 

That's all we need in terms of new libraries, so let's dig into the audio setup code.

##Core Audio Setup
Declare a function meant for internal usage, called macOSInitSound(). Here's the code I used for that.

'''Objective-C++
internal_usage
void macOSInitSound() {

}
'''

This is the function we will call right before the beginning of the main run loop to setup the sound buffer and start receiving sound callbacks from the system.

You will also want to setup a global reference (for the time being) to the audioUnit that will play the sound. 

Just above the macOSInitSound function, add the following line:

'''Objective-C++
global_variable AudioComponentInstance audioUnit;
'''

Core Audio will initialize this thing later. We just want to have the variable ready for that moment.

###Creating an AudioComponentDescription
An AudioComponentDescription, to the best of my rudimentary knowledge, is simply a way to tell the system how you plan to work with sound. You can input sound through a microphone or output sound through the speakers. There are other various options you can also pick, but we aren't really interested in those. We want the most basic audio output on the Mac, so we are going to pick the defaults and set everything else to zero.

Copy/Paste this code inside of the MacOSInitSound function, right at the top:

'''Objective-C++
AudioComponentDescription acd;
acd.componentType = kAudioUnitType_Output;
acd.componentSubType = kAudioUnitSubType_DefaultOutput;
acd.componentManufacturer = kAudioUnitManufacturer_Apple;
acd.componentFlags = 0;
acd.componentFlagsMask = 0;
'''

###Setting up an AudioComponent for Output
Now that the system has a way to understand what kind of audio component we want to create, let's create one. The AudioComponentFindNext function searches through the available system audio components for an audio component that matches the description above. In many ways, the api is similar to what we saw earlier when we hooked up a Sony Dual Shock 4 game controller, using IOHID.

Add the following lines of code, right below the lines setting up the AudioComponentDescription:

'''Objective-C++
AudioComponent outputComponent = AudioComponentFindNext(NULL, &acd);
OSStatus status = AudioComponentInstanceNew(outputComponent, &audioUnit);

//Todo: (Ted) - Better error handling 
if (status != noErr) {
    NSLog(@"There was an error setting up sound");
    return;
}
'''

The second line takes the address of the AudioComponentInstance (which you have defined above this function), and it uses the AudioComponent to initialize it. This function also returns an OSStatus, which is basically a wrapper around possible error codes. So long as the status is this this special noErr condition, the sound has been setup properly. I took the liberty of adding a todo to come back and make sure I put in better error handling when shipping the final MacOS platform layer.

##Audio Stream Setup
Now that we've made a basic audio output component, we can focus on the actual audio that will play. For that, we use what's called an AudioStreamBasicDescription. This thing tells the system what kind of audio it can expect to play.

We're going to do something very similar to what Casey does, but our audio (at least on the Mac side) won't be interleaved. All that means is we're going to do 48khz linear PCM with two channels instead of one channel where the left and right speakers switch off.

Add the following lines next:

'''Objective-C++
AudioStreamBasicDescription audioDescriptor;
audioDescriptor.mSampleRate = 48000.0;
audioDescriptor.mFormatID = kAudioFormatLinearPCM;
audioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                               kAudioFormatFlagIsNonInterleaved | 
                               kAudioFormatFlagIsPacked; 
'''

###Audio Frames
Audio streams can have different levels of compression. That is to say, the stream can be read as packets of varying size, each containing some variable number of frames in them. Linear PCM is not a compressed format, so it only contains a single frame per packet. As a result, the number of bytes in a given frame is simply the size of a signed 16-bit integer since that is how each sound frame is represented in memory.

Add the following four lines to set those properties:

'''Objective-C++
int framesPerPacket = 1;
int bytesPerFrame = sizeof(int16);
audioDescriptor.mFramesPerPacket = framesPerPacket;
audioDescriptor.mChannelsPerFrame = 2; // Stereo sound
audioDescriptor.mBitsPerChannel = sizeof(int16) * 8;
audioDescriptor.mBytesPerFrame = bytesPerFrame;
audioDescriptor.mBytesPerPacket = framesPerPacket * bytesPerFrame; 
'''

All stereo sound contains two channels in a frame. There are eight bits in a byte, so the number of bits in a channel is just the bytes in a single frame times eight. Finally, the number of bytes in a packet is effectively the same as bytes per frame, since there is only one frame in a packet.

###Setting the Stream Format
Now we're going to set the stream format on the AudioComponentInstance so the system knows what sort of audio it can expect to play.

Copy/Paste the following lines of code next:

'''Objective-C++
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
'''

[AudioUnitSetProperty](https://developer.apple.com/documentation/audiotoolbox/1440371-audiounitsetproperty?changes=_4&language=objc) can be used to set the stream format. The first parameter is the audio component instance itself, the second is the type of property we want to set. In this case, it's the stream format as expected.

The third parameter is the audio unit scope, which we have defined as kAudioUnitScope_Input since we will be providing a stream (a.k.a. the values of our square wave) to the system audio processor that it will then output to the speakers. So the scope of the stream is input taken from the program that is then output to the speakers. Hope that makes sense.

The fourth parameter is the [AudioUnitElement](https://developer.apple.com/documentation/audiotoolbox/audiounitelement?changes=_4&language=objc), which we've set to zero. We want the global audio unit element, so no physical signal bus in particular.

The last two parameters (which could actually just be one) simply take the audioDescriptor we just defined above. It's kinda silly that you have to pass the size of the thing, as if they couldn't figure that out from inside of the function itself. But hey that's just how it is.

###Creating an Audio Render Callback
If you did the [tutorial where we setup a Sony Dual Shock 4 Game Controller](https://medium.com/@theobendixson/handmade-hero-mac-os-platform-layer-day-6-controller-and-keyboard-input-part-1-b06c2e303d30), much of this will be familiar. We will define an AURenderCallback function, pass it to another function, and the system will call us when that event occurs. In this case, our callback function is something AudioToolbox calls in order to get audio samples for its render buffer.

Copy the following function stub into the osx_main.mm file, directly above the macOSInitSound function:

'''Objective-C++
OSStatus squareWaveRenderCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  uint32 inBusNumber,
                                  uint32 inNumberFrames,
                                  AudioBufferList *ioData) {

} 
'''

This function has the signature of an [AURenderCallback, as defined in the documentation](https://developer.apple.com/documentation/audiotoolbox/aurendercallback?language=objc). When all is said and done, it will render a square wave to the audio buffer. Let's step through the meaning of some of those parameters.

inRefCon is just a pointer to some custom piece of data you can pass into the function. Later on, we will probably pass in a pointer to the game's circular buffer. For now, we aren't going to pass anything in.

ioActionFlags have to do with pre and post audi processing. We're not really interested in doing that for a basic square wave, so we can leave that out too.

The timestamp and bus number also won't be used. The bus number is the same audio bus number from AudioUnitSetProperty, which is the global one for our use case.

We actually care about inNumberFrames and ioData. inNumberFrames tells us how many frames of audio the system expects us to provide the buffer. ioData is just a pointer to the two buffers representing the stereo audio channels.

###Creating an AURendercallbackStruct
Now that we have a square wave rendering function defined, we need a way to associate it with our AudioComponentInstance. We do that by creating an AURenderCallbackStruct.

Copy/Paste the following two lines of code, right after the lines where you set the kAudioUnitProperty_StreamFormat:

'''Objective-C++
AURenderCallbackStruct renderCallback;
renderCallback.inputProc = squareWaveRenderCallback;

AudioUnitSetProperty(audioUnit,
                     kAudioUnitProperty_SetRenderCallback,
                     kAudioUnitScope_Global,
                     0,
                     &renderCallback,
                     sizeof(renderCallback));
'''

There isn't much new here. It's the same AudioUnitSetProperty function we used earlier to set the stream format. This just registers the render callback so the system will call the square wave function when rendering.

Add the following two lines and we're done with basic CoreAudio setup on the Mac.

'''Objective-C++
AudioUnitInitialize(audioUnit);
AudioOutputUnitStart(audioUnit);
'''

##Rendering a Square Wave
It goes without saying that no sound will play unless we put some code in the squareWaveRenderCallback function we defined above. Let's get started with that.

First, we want to get a handle to the left and right channels. 
