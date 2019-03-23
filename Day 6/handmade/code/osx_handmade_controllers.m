#include "osx_handmade_controllers.h"
#include <IOKit/hid/IOHIDLib.h>

static IOHIDManagerRef HIDManager = NULL;
static NSMutableArray *controllers = nil;

@implementation OSXHandmadeController

+ (void)initialize {

    HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    controllers = [NSMutableArray array];

    if (IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"Error Initializing OSX Handmade Controllers");
        return;
    }

    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, controllerConnected, NULL);
    IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
        @{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
    ]);
    
}

static void
controllerConnected(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {

}

@end
