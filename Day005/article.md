## Handmade Hero Mac OS Platform Layer Day 005. Debugging in Xcode (and some cleanup).
Casey spends day five answering various questions about graphics on Windows. I wanted to do something a little different. We’ve already got a great start with graphics on the Mac, but I think we could take care of another pet project of mine, getting the debugger to work inside of Xcode.

Before we start, I must apologize for the slight difference in code between the articles and the videos. When recording Youtube videos, I sometimes realize later on that I may have bitten off more than I can chew for a given session. Last time, I didn’t include some bits of cleanup that were in the articles, and I even changed some of the function names.

None of it is a big deal, but I’d just like to get back to a more standard way of doing things, and I am hoping this article will accomplish that. If you prefer to follow by article, just start with the day four repo on Github and you should be good to go.

### The goal
I want to show you how to use the debugger inside of Xcode even if you never build the project from Xcode. This won't take very long, and it will be a huge boon to your productivity. It's really nice to have the option to load in files, graphically place breakpoints, and see what your code is doing when it hits those breakpoints.

I also want to take care of some cleanup, moving our custom types out of the macOS platform layer code and into a simple header file. We'll take care of that part first.

### Moving the custom types
If you look at the top of osx_main.mm, you will notice quite a few defines and type definitions. Following the original Handmade Hero, we have done this intentionally.

I (like Casey) wanted to be more explicit about that various uses of the term ‘static,’ calling attention to when we use it to declare global variables, internal variables, or variables that have a locally persisting characteristic (something we haven’t touched on yet).

We also defined a number of easier to read integer and unsigned integer types. We will include those in the handmade_types.h file, which we are about to create, as well.

You can use whatever text editor you like to create the handmade_types.h file. I’m using vim for that purpose.

From the code directory, type the following:
vim handmade_types.h

In vim, this will open up a new file with the name you’ve specified. You can also open osx_main.mm with vim and use the following command to open a new tab with the new file.

:tabe handmade_types.h

Then, to navigate to the next tab you type :tabn. To navigate to the previous tab, type :tabp. You can also do fancy things like typing “3gt” which will navigate you to the third tab, if it’s open.

Copy the #define statements and the various integer typedefs, and then paste them into the handmade_types.h file so it looks like so.

```c
#include <stdint.h>
#define internal_variable static
#define local_persist static
#define global_variable static
typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;
typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;
```

Take note of the fact that we included the stdint library. That’s because it is required in order for us to create custom integer types that are based on existing integer types in c/c++.

Now go back to the top of the osx_main.mm file and add the following include statement.

```objc
#include "handmade_types.h"
```

Also be sure you delete the lines you just copied from osx_main.mm.

At this point, you should be able to run the build command and notice that the project builds just as before. You can also go ahead and run the app to make sure you are still at feature parity.

### Using the debugger in Xcode
You didn’t really think we were going to be that hardcore and stick with the debugger (lldb) in the command line the whole time, did you? Although cool in principle, it could end up being more work in the long run. Plus if you’ve got this really nice IDE, why not use it for a few things here and there?

Open Xcode and create a new project. Click on the Cross-platform tab, then select Empty in the Other section.

Call it HandmadeHero (or really anything you like), and save it to the handmade directory. We might move that later but for now it’s fine since we won’t use Xcode to build the game.
Now, with your project selected, go to File -> New -> Target

Again, you will have several options. Click on the Cross-platform tab (it should already be selected for you), and then click Aggregate.

I’m not really sure what Aggregate is supposed to mean, but it’s the only truly-cross platform option related to code, so that’s what we’re going with.
Again, they will ask you for a name. Just call it HandmadeHero.

At this point, you should have a target called HandmadeHero in your project as well as build scheme to build it. Xcode should look like this.

We won’t ever use the build scheme to build the project, but we will use the scheme to tell Xcode which executable we are interested in debugging. Note that you will need to reset this for every new day of the project. That's because Xcode will point to the build from the previous day and use it instead.

### Hooking up the executable
Since our clang build command already generates debug symbols for us (the handmade.dsym file you’ve seen), we need only tell Xcode which executable we want to look at when debugging. To do that, you want to edit the HandmadeHero scheme.
Click on the HandmadeHero target icon in the top bar to the right of the play button and select Edit Scheme.

In Xcode, schemes are used to manage the various actions you could do with your project. For example, you might Build, Run, Test, Debug, Profile, Analyze, or Archive a project you are working on.

For the purposes of attaching the debugger, we are only interested in the Run portion of the scheme we’ve setup.

Click on the Run menu option. Next, click on the Executable menu option and select “other”

This will prompt you to select a file. Navigate to the build directory and select the handmade executable.

If you’ve done this properly, you should see handmade as the executable in the scheme editor window.

Great! Your executable is all hooked up and ready to go.

### Adding files to debug and running the debugger
It’s really important to pay attention here because it’s totally possible to screw this up. I did and it cost me like half and hour of yelling ‘wtf’ at my computer.

If you want to use the debugger in Xcode, you have to add the files you want to debug to your project.

That’s all well and good, but Xcode has some funky behaviors you definitely want to steer clear of. One of them is the “Copy items if needed” option.

This option will royally screw you because it will copy the file and then put it under your Xcode project directory (not the code direcotry) meaning Xcode will never hit the breakpoints because the copied file Xcode is looking at isn’t what the compiler builds to make the game’s executable.

Open the code directory and drag the osx_main.mm file into the project. You should see the following dialog box.

Do not, I repeat, do not select anything. Just click Finish. This will tell Xcode to treat the file as a reference and not to do anything silly like copying the file into a separate project directory that has nothing to do with our custom build system.

Place a breakpoint in the main function in osx_main.mm, and then select Product -> Run

Xcode will tell you the product built successfully (funny I know), the game will launch, and the debugger will hit the breakpoint.

Cool! We no longer need to use the command line to debug the app. We can simply reference the files we want to look at in Xcode, put in some breakpoints, and debug in a more natural way.

Whenever there’s a file you want to debug, just click and drag it into the Xcode project and remember don’t click on any of the fancy options!

### Support this content
If you found this content valuable, and you would like to see more of it, you can support it on Patreon.

Any amount helps.

Maybe you are trying to break into the game industry, or maybe you just want to become a better programmer. What would it cost you to enroll in an advanced programming course at your local college? What would you pay for a Unity license to ship a cross-platform game?

Pretty much every tutorial you will see out there starts out in a swamp of mystery. You don’t know how the build system works. You just have to use it. You don’t know how this or that framework solves your problem. You just have to use them.

We’re doing something totally different here. Instead of taking the existing systems at face value, we are questioning what we see and building something better from scratch. If we don’t understand it, we poke and prod at it until we do.

I am doing this 100% in my spare time at no charge. Every contribution helps nudge me ever-so-slightly towards doing it full-time. Were I able to support myself with this work, it would unlock a blizzard of content that, I think, would make all of us better at the craft.

So here’s that link again. Support this content on Patreon. Thanks for reading, and comment below if you’ve learned something valuable.

### What’s Next?
I feel a lot better knowing we can debug the game from Xcode. Not only do we have a way of moving code out of the osx_main.mm file, we’re also debugging in Xcode. That’s going to make it a lot easier to work with this project in the future.

If you want to check your work with me, take a look at the Github repo for Day 5 of this series.

In the next installment, we’re going to take a look at gamepad and keyboard input (just as Casey does). We will hook up a game controller and get it to modify what gets drawn to the screen.

If you find this work valuable, give it some claps and share it with your friends. Also, be sure to support Handmade Hero. None of this would be possible without it.

Thanks and see you next time!
