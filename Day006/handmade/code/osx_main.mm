// Handmade Hero OSX
// By Ted Bendixson
//
// OSX Main

#import "handmade_types.h"
#import <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>

global_variable float globalRenderWidth = 1024;
global_variable float globalRenderHeight = 768;

global_variable uint8 *buffer;
global_variable int bitmapWidth;
global_variable int bitmapHeight;
global_variable int bytesPerPixel = 4;
global_variable int pitch;

global_variable int offsetX = 0;
global_variable int offsetY = 0;

global_variable bool running = true;

void macOSRefreshBuffer(NSWindow *window) {

    if (buffer) {
        free(buffer);
    }

    bitmapWidth = window.contentView.bounds.size.width;
    bitmapHeight = window.contentView.bounds.size.height;
    pitch = bitmapWidth * bytesPerPixel;
    buffer = (uint8 *)malloc(pitch * bitmapHeight);
}

void renderWeirdGradient() {

    int width = bitmapWidth;
    int height = bitmapHeight;

    uint8 *row = (uint8 *)buffer;

    for ( int y = 0; y < height; ++y) {

        uint8 *pixel = (uint8 *)row;

        for(int x = 0; x < width; ++x) {
            
            /*  Pixel in memory: RR GG BB AA */

            //Red            
            *pixel = 0; 
            ++pixel;  

            //Green
            *pixel = (uint8)y+(uint8)offsetY;
            ++pixel;

            //Blue
            *pixel = (uint8)x+(uint8)offsetX;
            ++pixel;

            //Alpha
            *pixel = 255;
            ++pixel;          
        }

        row += pitch;
    }

}

void macOSRedrawBuffer(NSWindow *window) {
    @autoreleasepool {
        NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &buffer 
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
}

@interface HandmadeMainWindowDelegate: NSObject<NSWindowDelegate>
@end

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

@interface HandmadeKeyIgnoringWindow: NSWindow
@end

@implementation HandmadeKeyIgnoringWindow
- (void)keyDown:(NSEvent *)theEvent { }
@end

@interface OSXHandmadeController: NSObject

//D-Pad
@property NSInteger dpadX;
@property NSInteger dpadY;

//ABXY
@property BOOL buttonAState;
@property BOOL buttonBState;
@property BOOL buttonXState;
@property BOOL buttonYState;

//Shoulder Buttons
@property BOOL buttonLeftShoulderState;
@property BOOL buttonRightShoulderState;

@end

global_variable IOHIDManagerRef HIDManager = NULL;
global_variable OSXHandmadeController *connectedController = nil;
global_variable OSXHandmadeController *keyboardController = nil; 

@implementation OSXHandmadeController {

    //D-Pad    
	CFIndex _dpadLUsageID;
	CFIndex _dpadRUsageID;
	CFIndex _dpadDUsageID;
	CFIndex _dpadUUsageID;

    //ABXY    
	CFIndex _buttonAUsageID;
	CFIndex _buttonBUsageID;
	CFIndex _buttonXUsageID;
	CFIndex _buttonYUsageID;
	
    //Shoulder Buttons  
    CFIndex _lShoulderUsageID;
	CFIndex _rShoulderUsageID;
}

static
void macOSInitGameControllers() {
    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    connectedController = [[OSXHandmadeController alloc] init];
    keyboardController = [[OSXHandmadeController alloc] init];

    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, controllerConnected, NULL);
    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
    ]);
  
	IOHIDManagerScheduleWithRunLoop(HIDManager, 
                                    CFRunLoopGetMain(), 
                                    kCFRunLoopDefaultMode);
	NSLog(@"OSXhandmade Controller initialized.");
}

const unsigned short leftArrowKeyCode = 0x7B;
const unsigned short rightArrowKeyCode = 0x7C;
const unsigned short downArrowKeyCode = 0x7D;
const unsigned short upArrowKeyCode = 0x7E;
const unsigned short aKeyCode = 0x00;
const unsigned short sKeyCode = 0x01;
const unsigned short dKeyCode = 0x02;
const unsigned short fKeyCode = 0x03;
const unsigned short qKeyCode = 0x0C;
const unsigned short rKeyCode = 0x0F;

static
void updateKeyboardControllerWith(NSEvent *event) {
    switch ([event type]) {
        case NSEventTypeKeyDown:
            if (event.keyCode == leftArrowKeyCode &&
                keyboardController.dpadX != 1) {
                keyboardController.dpadX = -1;
                break;
            }

            if (event.keyCode == rightArrowKeyCode &&
                keyboardController.dpadX != -1) {
                keyboardController.dpadX = 1;
                break;
            }

            if (event.keyCode == downArrowKeyCode &&
                keyboardController.dpadY != -1) {
                keyboardController.dpadY = 1;
                break;
            }

            if (event.keyCode == upArrowKeyCode &&
                keyboardController.dpadY != 1) {
                keyboardController.dpadY = -1;
                break;
            }

            if (event.keyCode == aKeyCode) {
                keyboardController.buttonAState = 1;
                break;
            }

            if (event.keyCode == sKeyCode) {
                keyboardController.buttonBState = 1;
                break;
            }

            if (event.keyCode == dKeyCode) {
                keyboardController.buttonXState = 1;
                break;
            }

            if (event.keyCode == fKeyCode) {
                keyboardController.buttonYState = 1;
                break;
            }

            if (event.keyCode == qKeyCode) {
                keyboardController.buttonLeftShoulderState = 1;
                break;
            }

            if (event.keyCode == rKeyCode) {
                keyboardController.buttonRightShoulderState = 1;
                break;
            }

        case NSEventTypeKeyUp:
            if (event.keyCode == leftArrowKeyCode &&
                keyboardController.dpadX == -1) {
                keyboardController.dpadX = 0;
                break;
            } 

            if (event.keyCode == rightArrowKeyCode &&
                keyboardController.dpadX == 1) {
                keyboardController.dpadX = 0;
                break;
            }

            if (event.keyCode == downArrowKeyCode &&
                keyboardController.dpadY == 1) {
                keyboardController.dpadY = 0;
                break;
            }

            if (event.keyCode == upArrowKeyCode &&
                keyboardController.dpadY == -1) {
                keyboardController.dpadY = 0;
                break;
            }

            if (event.keyCode == aKeyCode) {
                keyboardController.buttonAState = 0;
                break;
            }

            if (event.keyCode == sKeyCode) {
                keyboardController.buttonBState = 0;
                break;
            }

            if (event.keyCode == dKeyCode) {
                keyboardController.buttonXState = 0;
                break;
            }

            if (event.keyCode == fKeyCode) {
                keyboardController.buttonYState = 0;
                break;
            }

            if (event.keyCode == qKeyCode) {
                keyboardController.buttonLeftShoulderState = 0;
                break;
            }

            if (event.keyCode == rKeyCode) {
                keyboardController.buttonRightShoulderState = 0;
                break;
            }

        default:
        break;
    }
}

static void controllerConnected(void *context, 
                                IOReturn result, 
                                void *sender, 
                                IOHIDDeviceRef device) {

    if(result != kIOReturnSuccess) {
        return;
    }

    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                       CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, 
                                                                        CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];

    OSXHandmadeController *controller = [[OSXHandmadeController alloc] init];
    
    if(vendorID == 0x054C && productID == 0x5C4) {
        NSLog(@"Sony Dualshock 4 detected.");
        controller->_buttonAUsageID = 0x02;
        controller->_buttonBUsageID = 0x03;
        controller->_buttonXUsageID = 0x01;
        controller->_buttonYUsageID = 0x04;
        controller->_lShoulderUsageID = 0x05;
        controller->_rShoulderUsageID = 0x06;
    }

    IOHIDDeviceRegisterInputValueCallback(device, controllerInput, (__bridge void *)controller);  
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
        @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);

    connectedController = controller;
}

static void controllerInput(void *context, 
                            IOReturn result, 
                            void *sender, 
                            IOHIDValueRef value) {

    if(result != kIOReturnSuccess) {
        return;
    }

    OSXHandmadeController *controller = (__bridge OSXHandmadeController *)context;
    
    IOHIDElementRef element = IOHIDValueGetElement(value);    
    uint32 usagePage = IOHIDElementGetUsagePage(element);
    uint32 usage = IOHIDElementGetUsage(element);

    //Buttons
    if(usagePage == kHIDPage_Button) {
        BOOL buttonState = (BOOL)IOHIDValueGetIntegerValue(value);
        if(usage == controller->_buttonAUsageID) { controller->_buttonAState = buttonState; }
        if(usage == controller->_buttonBUsageID) { controller->_buttonBState = buttonState; }
        if(usage == controller->_buttonXUsageID) { controller->_buttonXState = buttonState; }
        if(usage == controller->_buttonYUsageID) { controller->_buttonYState = buttonState; }
        if(usage == controller->_lShoulderUsageID) { controller->_buttonLeftShoulderState = buttonState; }
        if(usage == controller->_rShoulderUsageID) { controller->_buttonRightShoulderState = buttonState; }
    }

    //dPad
    else if(usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Hatswitch) {
        int dpadState = (int)IOHIDValueGetIntegerValue(value);
        NSInteger dpadX = 0;
        NSInteger dpadY = 0;

        switch(dpadState) {
            case 0: dpadX = 0; dpadY = 1; break;
            case 1: dpadX = 1; dpadY = 1; break;
            case 2: dpadX = 1; dpadY = 0; break;
            case 3: dpadX = 1; dpadY = -1; break;
            case 4: dpadX = 0; dpadY = -1; break;
            case 5: dpadX = -1; dpadY = -1; break;
            case 6: dpadX = -1; dpadY = 0; break;
            case 7: dpadX = -1; dpadY = 1; break;
            default: dpadX = 0; dpadY = 0; break;

        }

        controller->_dpadX = dpadX;
        controller->_dpadY = dpadY; 
    }
}

@end

int main(int argc, const char * argv[]) {

    HandmadeMainWindowDelegate *mainWindowDelegate = [[HandmadeMainWindowDelegate alloc] init];

    NSRect screenRect = [[NSScreen mainScreen] frame];

    NSRect initialFrame = NSMakeRect((screenRect.size.width - globalRenderWidth) * 0.5,
                                     (screenRect.size.height - globalRenderHeight) * 0.5,
                                     globalRenderWidth,
                                     globalRenderHeight);
  
    NSWindow *window = [[HandmadeKeyIgnoringWindow alloc] 
                         initWithContentRect: initialFrame
                         styleMask: NSWindowStyleMaskTitled |
                                    NSWindowStyleMaskClosable |
                                    NSWindowStyleMaskMiniaturizable |
                                    NSWindowStyleMaskResizable 
                         backing: NSBackingStoreBuffered
                         defer: NO];    

    [window setBackgroundColor: NSColor.blackColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    [window setDelegate: mainWindowDelegate];
    window.contentView.wantsLayer = YES;
 
    macOSRefreshBuffer(window);
    macOSInitGameControllers(); 
 
    while(running) {
   
        renderWeirdGradient();
        macOSRedrawBuffer(window); 

        OSXHandmadeController *controller = keyboardController;
        
        if(controller != nil){
            if(controller.buttonAState == true) {
                offsetX++;       
            }

            if(controller.buttonLeftShoulderState == true) {
                offsetX--;
            }
           
            if(controller.buttonRightShoulderState == true) {
                offsetX++;
            }
 
            if (controller.dpadX == 1) {
                offsetX++;
            }

            if (controller.dpadX == -1) {
                offsetX--;
            }

            if (controller.dpadY == 1) {
                offsetY++;
            }

            if (controller.dpadY == -1) {
                offsetY--;
            }
        }

        NSEvent* event;
        
        do {
            event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                       untilDate: nil
                                          inMode: NSDefaultRunLoopMode
                                         dequeue: YES];
           
            if (event != nil &&
                controller == keyboardController &&
                (event.type == NSEventTypeKeyDown ||
                event.type == NSEventTypeKeyUp)) {
                updateKeyboardControllerWith(event);
            }
 
            switch ([event type]) {
                default:
                    [NSApp sendEvent: event];
            }
        } while (event != nil);
    }
 
    printf("Handmade Finished Running");
}
