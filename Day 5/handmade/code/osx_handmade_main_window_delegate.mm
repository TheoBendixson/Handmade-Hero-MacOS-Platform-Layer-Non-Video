#include "osx_main.h"
#import "osx_handmade_main_window_delegate.h"

@implementation HandmadeMainWindowDelegate 

- (void)windowWillClose:(id)sender {
    running = false;  
}

- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *window = (NSWindow*)notification.object;
    macOSRefreshBuffer(window);
    renderWeirdGradient();
    macOSRedrawBuffer(window);
}

@end
