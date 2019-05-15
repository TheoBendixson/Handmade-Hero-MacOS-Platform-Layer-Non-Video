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

