## Handmade Hero Mac OS Platform Layer, Day 8 Rendering Audio from a Circular Buffer
At the end of day seven, we finished the basic core audio setup. We also had the speakers output a square wave just confirm that it is indeed producing real sounds that we can hear. 

Of course, that is only the start of the effort. A fully shippable cross-platform video game will need to do much more than that. It needs to not only output sound but update which sounds will play every time there is a new frame to draw. To do that properly, we need a way to place sound output right into the present moment, again and again for as long as the game is playing.

This is done with a circular sound buffer, which is what we will be focusing on today.

### What is a Circular Buffer?
Circular buffers are just like any other buffer. They represent some series of addresses in memory. They store one kind of data representation that is traversed along the bounds of that piece of data's size (unsigned 8 bit integer, 16 bit signed integer, for example). They have a start and end in physical memory.

But with circular buffers, there is one key difference. As you read or write data to them, you go back to the beginning once you hit the end. 

This has a certain value to it. You can imagine the circular buffer representing the present moment. At any given moment, you have maybe a single second or two of sounds to hear. Those sounds keep refreshing, over and over again. As soon as one sound exits your consciousness, another immediately replaces it. Sometimes you can't hear any sound, but that's extremely rare. There's almost always some tiny creaking, the sound of your own breath, or the refrigerator buzzing in the background. And these sounds keep invading your mental space, whether you want them to be there or not.

With a circular buffer, we are holding onto this tiny slice we call the present moment, and we are playing sounds from it almost as quickly as we write sounds to it. This happens every time the game produces a single frame. 

We want the sounds in the game to match up with the picture drawn to the screen, to the best extent that they can. This creates a feeling of synesthesia, or a kind of conncectedness between the sensation of hearing, the sensation of seeing, and even the sensation of touch.

Think of your favorite 2D platformer game. One my favorites is Axiom Verge. Think of the footstep sounds the character makes as he walks and how those footsteps create a sort of tactile feeling while you are controlling him. Now imagine how you might feel about the game if those footstep sounds didn't quite match up with the game character's walking pace on the screen. You might not be able to put words to it, but something just wouldn't feel right. The game would be less immersive. You would feel less in-control of the game character. You might even lose interest in the game or stop playing altogether.

A circular sound buffer gives us direct control over the sounds playing in the present moment, and we use this control to create better more immersive games.

### Creating a Sound Output Buffer
To get started, we will make a sound output buffer. This is just a struct that will hold all of the things we need to read and write sound. 

Open the osx_main.h file and add the following lines of code toward the top, just underneath the import statements.

'''Objective-C 
struct MacOSSoundOutput {
    int samplesPerSecond; 
    uint32 bufferSize;
    int16* coreAudioBuffer;
    int16* readCursor;
    int16* writeCursor;
};
'''

The sound output struct tells us where we can find the circular buffer in memory, how big it is, where it was last written to, and where it was last read from.

With circular sound buffers, you have a read cursor and a write cursor. On every frame, the game writes sound output to the coreAudioBuffer, advancing to the end of that buffer, then wrapping around to the beginning. Once the write cursor hits the space behind the read cursor, it stops until it is asked to write again.

The read cursor works in a similar way, but it only reads from the buffer during the Core Audio render callback we provide.

### Differences between MacOS and Windows
On Casey's series, DirectSound gives him two regions to write sound output to. If the write cursor is ahead of the read cursor in the buffer, it's the region from the write cursor to the end of the buffer plus a separate region from the start of the sound buffer to the read cursor. Windows has taken care of the problem of having the write cursor stop once it hits the read cursor.

The MacOS Core Audio api works differently. Instead of being given the two regions, you simply provide a sound output render callback that the system calls into with a given set of audio frames it intends to render. Core Audio doesn't care if you've setup a circular buffer, nor does it care where your read or write cursors happen to be. You have to handle all of that yourself.

### Setting up the Core Audio Sound Output Buffer
Go to the top of the osx_main.mm file and paste the following code near the other global variables to initialize the Sound Output Buffer. 

'''Objective-C++
global_variable MacOSSoundOutput soundOutput = {};
'''

Now go to the top of the macOSInitSound function. We're going to setup the circular audio buffer along with its read and write cursors.

First, you want to set the samples per second. Earlier, this was a global const varible, but now we're going to move it to the SoundOutput object.

Paste the following code at the top of macOSInitSound()

'''Objective-C++
soundOutput.samplesPerSecond = 48000; 
'''

Now change the audioDescriptor so it uses the samplesPerSecond from the soundOutput struct instead of the previous global constant. Here is what the change looks like.

'''Objective-C++
AudioStreamBasicDescription audioDescriptor;
audioDescriptor.mSampleRate = soundOutput.samplesPerSecond;
audioDescriptor.mFormatID = kAudioFormatLinearPCM;
audioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | 
                               kAudioFormatFlagIsPacked; 
'''  

#### Calculating the sound buffer size
We are going to create a two second sound buffer with interleaved linear PCM sound data, just as Casey does in his stream. So the size of the sound buffer is the number of samples per second times the size of a single sample (two 16 bit signed integers representing the left and right audio channels) times the number of seconds (2).

Paste the following lines of code right after the place where you set the soundOutput's samplesPerSecond property.

'''Objective-C++
int audioFrameSize = sizeof(int16) * 2;
int numberOfSeconds = 2; 
soundOutput.bufferSize = soundOutput.samplesPerSecond * audioFrameSize * numberOfSeconds;
'''
