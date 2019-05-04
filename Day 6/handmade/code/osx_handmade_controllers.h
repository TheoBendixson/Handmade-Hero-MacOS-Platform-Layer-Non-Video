#import <AppKit/AppKit.h>

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
@property BOOL buttonAState;
@property BOOL buttonBState;
@property BOOL buttonXState;
@property BOOL buttonYState;

//Shoulder Buttons
@property BOOL buttonLeftShoulderState;
@property BOOL buttonRightShoulderState;

@end

