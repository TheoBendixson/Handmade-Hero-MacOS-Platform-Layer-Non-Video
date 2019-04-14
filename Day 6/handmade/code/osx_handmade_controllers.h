#include <AppKit/AppKit.h>

@interface OSXHandmadeController: NSObject
+ (NSArray *)controllers;

@property CFIndex buttonAState;
@property CFIndex buttonBState;
@property CFIndex buttonXState;
@property CFIndex buttonYState;
@property CFIndex buttonLeftShoulderState;
@property CFIndex buttonRightShoulderState;

@end

