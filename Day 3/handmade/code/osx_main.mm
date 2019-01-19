// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#include <stdio.h>
#include <AppKit/AppKit.h>

static float GlobalRenderWidth = 1024;
static float GlobalRenderHeight = 768;

static bool Running = true;
static uint8_t *buffer;
static int offsetX = 0;

typedef struct {
    uint8_t red;
    uint8_t green;
    uint8_t blue;
    uint8_t alpha;
} Pixel;

void renderGradient(NSWindow* window) {

    if(buffer) {
        free(buffer);
    }

    size_t width = window.contentView.bounds.size.width;
    size_t height = window.contentView.bounds.size.height;

    size_t pitch = width * sizeof(Pixel);
    buffer = (uint8_t *)malloc(pitch * height);

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&buffer
						      pixelsWide: width
						      pixelsHigh: height
						      bitsPerSample: 8
						      samplesPerPixel: 4
						      hasAlpha: YES
						      isPlanar: NO
						      colorSpaceName: NSDeviceRGBColorSpace
						      bytesPerRow: pitch
						      bitsPerPixel: sizeof(Pixel) * 8];

    NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(width, height)];
    [image addRepresentation: rep];

    window.contentView.wantsLayer = YES;
    window.contentView.layer.contents = image;

    for ( size_t y = 0; y < height; ++y) {
        Pixel *row = (Pixel *)(buffer + y * pitch);
        for(size_t x = 0; x < width; ++x) {
            Pixel color = { .red=0, .green=y, .blue=x+offsetX, .alpha=255 };
            row[x] = color;
        }
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

    [window setBackgroundColor: NSColor.redColor];
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
