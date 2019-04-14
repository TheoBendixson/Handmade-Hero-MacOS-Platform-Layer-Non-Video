#include <AppKit/AppKit.h>

@interface OSXHandmadeController: NSObject
+ (NSArray *)controllers;

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

