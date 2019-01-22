// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>

#define internal static
#define local_persist static
#define global_variable static

global_variable float globalRenderWidth = 1024;
global_variable float globalRenderHeight = 768;
global_variable bool running = true;
global_variable uint8_t *buffer;

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 

- (void)windowWillClose:(id)sender {
  running = false;  
}

@end

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *mainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect screenRect = [[NSScreen mainScreen] frame];

    NSRect initialFrame = NSMakeRect((screenRect.size.width - globalRenderWidth) * 0.5,
                                     (screenRect.size.height - globalRenderHeight) * 0.5,
                                     globalRenderWidth,
                                     globalRenderHeight);
    
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

    while(running) {
       
        if(buffer) {
            free(buffer);
        }   
 
        int bitmapWidth = window.contentView.bounds.size.width;
        int bitmapHeight = window.contentView.bounds.size.height;
        int bytesPerPixel = 4;
        size_t pitch = bitmapWidth * bytesPerPixel;
        buffer = (uint8_t *)malloc(pitch * bitmapHeight);

        @autoreleasepool {
            NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc]                                                        
                                        initWithBitmapDataPlanes: &buffer
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
