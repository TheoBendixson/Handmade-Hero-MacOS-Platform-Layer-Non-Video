#include "osx_handmade_controllers.h"
#include <IOKit/hid/IOHIDLib.h>

static IOHIDManagerRef HIDManager = NULL;
static OSXHandmadeController *connectedController = nil;
static OSXHandmadeController *keyboardController = nil; 
static ControllerInputSource controllerInputSource = ControllerInputSourceController;

const float deadZonePercent = 0.2f;

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

@implementation OSXHandmadeController {

    CFIndex _lThumbXUsageID;
	CFIndex _lThumbYUsageID;
	CFIndex _rThumbXUsageID;
	CFIndex _rThumbYUsageID;
	CFIndex _lTriggerUsageID;
	CFIndex _rTriggerUsageID;
	
	BOOL _usesHatSwitch;
	CFIndex _dpadLUsageID;
	CFIndex _dpadRUsageID;
	CFIndex _dpadDUsageID;
	CFIndex _dpadUUsageID;
	
	CFIndex _buttonPauseUsageID;
	CFIndex _buttonAUsageID;
	CFIndex _buttonBUsageID;
	CFIndex _buttonXUsageID;
	CFIndex _buttonYUsageID;
	CFIndex _lShoulderUsageID;
	CFIndex _rShoulderUsageID;
}

+ (void)initialize {

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
   
	NSString *mode = @"CCControllerPollGamepads";
	IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetCurrent(), (__bridge CFStringRef)mode);
	
	while(CFRunLoopRunInMode((CFStringRef)mode, 0, TRUE) == kCFRunLoopRunHandledSource){}

	IOHIDManagerUnscheduleFromRunLoop(HIDManager, CFRunLoopGetCurrent(), (__bridge CFStringRef)mode);
	
	// Schedule the HID manager normally to get callbacks during runtime.
	IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
	
	NSLog(@"OSXhandmade Controller initialized.");

}

+ (ControllerInputSource)controllerInputSource {
    return controllerInputSource;
}

+ (void)setControllerInputSource:(ControllerInputSource)newSource {
   controllerInputSource = newSource; 
}

+ (OSXHandmadeController *)connectedController {
    return connectedController;
}

+ (OSXHandmadeController *)keyboardController {
    return keyboardController;
}

+ (void)updateKeyboardControllerWith:(NSEvent *)event {
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


static void
controllerConnected(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {

    if(result == kIOReturnSuccess) {

        OSXHandmadeController *controller = [[OSXHandmadeController alloc] init];
        NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
        NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];
        
        CFIndex axisMin = 0;
        CFIndex axisMax = 256;

        if(vendorID == 0x054C){ // Sony
		    if(productID == 0x5C4){ // DualShock 4
                NSLog(@"[CCController initWithDevice:] Sony Dualshock 4 detected.");
                
                controller->_lThumbXUsageID = kHIDUsage_GD_X;
                controller->_lThumbYUsageID = kHIDUsage_GD_Y;
                controller->_rThumbXUsageID = kHIDUsage_GD_Z;
                controller->_rThumbYUsageID = kHIDUsage_GD_Rz;
                controller->_lTriggerUsageID = kHIDUsage_GD_Rx;
                controller->_rTriggerUsageID = kHIDUsage_GD_Ry;
                
                controller->_usesHatSwitch = YES;
                
                controller->_buttonPauseUsageID = 0x0A;
                controller->_buttonAUsageID = 0x02;
                controller->_buttonBUsageID = 0x03;
                controller->_buttonXUsageID = 0x01;
                controller->_buttonYUsageID = 0x04;
                controller->_lShoulderUsageID = 0x05;
                controller->_rShoulderUsageID = 0x06;
			}
		}

        IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (__bridge void *)controller);  
        IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
			@{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
			@{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
        ]);

        connectedController = controller;
    }
}

static void ControllerInput(void *context, IOReturn result, void *sender, IOHIDValueRef value) {

    if(result != kIOReturnSuccess) return;

    @autoreleasepool {
        OSXHandmadeController *controller = (__bridge OSXHandmadeController *)context;
        
        IOHIDElementRef element = IOHIDValueGetElement(value);
        
        uint32_t usagePage = IOHIDElementGetUsagePage(element);
        uint32_t usage = IOHIDElementGetUsage(element);

        CFIndex state = (int)IOHIDValueGetIntegerValue(value);

        if(usagePage == kHIDPage_Button) {
            if(usage == controller->_buttonAUsageID) { controller->_buttonAState = state; }
            if(usage == controller->_buttonBUsageID) { controller->_buttonBState = state; }
            if(usage == controller->_buttonXUsageID) { controller->_buttonXState = state; }
            if(usage == controller->_buttonYUsageID) { controller->_buttonYState = state; }
            if(usage == controller->_lShoulderUsageID) { controller->_buttonLeftShoulderState = state; }
            if(usage == controller->_rShoulderUsageID) { controller->_buttonRightShoulderState = state; }
        }

        if(usagePage == kHIDPage_GenericDesktop) {
        
            if(controller->_usesHatSwitch && usage == kHIDUsage_GD_Hatswitch) {

                NSInteger dpadX = 0;
                NSInteger dpadY = 0;

                switch(state) {
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
    }

}

@end
