// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>

#define internal static
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

global_variable float GlobalRenderWidth = 1024;
global_variable float GlobalRenderHeight = 768;

global_variable bool Running = true;
global_variable uint8 *buffer;
global_variable int offsetX = 0;

void renderGradient(NSWindow* window) {

    if(buffer) {
        free(buffer);
    }

    size_t width = window.contentView.bounds.size.width;
    size_t height = window.contentView.bounds.size.height;

    int bytesPerPixel = 4;

    size_t pitch = width * bytesPerPixel;
    buffer = (uint8 *)malloc(pitch * height);

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&buffer
						      pixelsWide: width
						      pixelsHigh: height
						      bitsPerSample: 8
						      samplesPerPixel: 4
						      hasAlpha: YES
						      isPlanar: NO
						      colorSpaceName: NSDeviceRGBColorSpace
						      bytesPerRow: pitch
						      bitsPerPixel: bytesPerPixel * 8];

    NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(width, height)];
    [image addRepresentation: rep];

    window.contentView.wantsLayer = YES;
    window.contentView.layer.contents = image;

    uint8 *row = (uint8 *)buffer;

    for ( int y = 0; y < height; ++y) {

        uint8 *pixel = (uint8 *)row;

        for(int x = 0; x < width; ++x) {
            
            /*
                Pixel in memory: RR GG BB AA
                

            */

            //Red            
            *pixel = 0; 
            ++pixel;  

            //Green
            *pixel = y;
            ++pixel;

            //Blue
            *pixel = x+offsetX;
            ++pixel;

            //Alpha
            *pixel = 255;
            ++pixel;          
        }

        row+= pitch;
    }

    [rep release];
    [image release];
}

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation HandmadeMainWindowDelegate 

- (void)windowWillClose:(id)sender {
    Running = false;  
}

- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *window = (NSWindow*)notification.object;
    renderGradient(window);
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

    [window setBackgroundColor: NSColor.blackColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    [window setDelegate: mainWindowDelegate];
    window.contentView.wantsLayer = YES;
    
    while(Running) {
    
	    renderGradient(window);

        offsetX++;
        
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
