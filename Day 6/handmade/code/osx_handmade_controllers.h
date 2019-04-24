#include <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, ControllerInputSource) {
    ControllerInputSourceController,
    ControllerInputSourceKeyboard
};

@interface OSXHandmadeController: NSObject
+ (ControllerInputSource)controllerInputSource;
+ (void)setControllerInputSource:(ControllerInputSource)newSource;
+ (OSXHandmadeController *)connectedController;
+ (OSXHandmadeController *)keyboardController;
+ (void)updateKeyboardControllerWith:(NSEvent *)event;

//D-Pad
@property NSInteger dpadX;
@property NSInteger dpadY;

//ABXY
@property CFIndex buttonAState;
@property CFIndex buttonBState;
@property CFIndex buttonXState;
@property CFIndex buttonYState;

//Shoulder Buttons
@property CFIndex buttonLeftShoulderState;
@property CFIndex buttonRightShoulderState;

//Trigger Buttons
@property CFIndex buttonLeftTriggerState;
@property CFIndex buttonRightTriggerState;

@end

