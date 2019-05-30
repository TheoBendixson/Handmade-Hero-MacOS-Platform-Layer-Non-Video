#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, ControllerInputSource) {
    ControllerInputSourceController,
    ControllerInputSourceKeyboard
};

@interface OSXHandmadeController: NSObject
+ (void)setControllerInputSource:(ControllerInputSource)newSource;
+ (OSXHandmadeController *)selectedController;
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

