#include "osx_main.h"
#include "osx_handmade_windows.h"

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

@implementation HandmadeKeyIgnoringWindow
- (void)keyDown:(NSEvent *)theEvent { }
@end
