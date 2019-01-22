// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>

static float GlobalRenderWidth = 1024;
static float GlobalRenderHeight = 768;

static bool Running = true;

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 

- (void)windowWillClose:(id)sender {
  Running = false;  
}

@end

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *mainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect screenRect = [[NSScreen mainScreen] frame];

    NSRect initialFrame = NSMakeRect((screenRect.size.width - GlobalRenderWidth) * 0.5,
                                     (screenRect.size.height - GlobalRenderHeight) * 0.5,
                                     GlobalRenderWidth,
                                     GlobalRenderHeight);
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:initialFrame
					 styleMask: NSWindowStyleMaskTitled |
						    NSWindowStyleMaskClosable |
						    NSWindowStyleMaskMiniaturizable |
						    NSWindowStyleMaskResizable 
					 backing:NSBackingStoreBuffered
					 defer:NO];    

    [window setBackgroundColor: NSColor.redColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    [window setDelegate: mainWindowDelegate];

    while(Running) {
        NSEvent* Event;
        
        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
            
            switch ([Event type]) {
                default:
                    [NSApp sendEvent: Event];
            }
        } while (Event != nil);
    }
    
    printf("Handmade Finished Running");
}
