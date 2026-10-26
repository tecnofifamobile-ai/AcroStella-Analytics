#import <UIKit/UIKit.h>
@interface StreamView:UIView<UIKeyInput,UIGestureRecognizerDelegate>
@property(nonatomic) BOOL connected,trackpad,scrollEnabled,rightClickEnabled,softwareKeyboardRequested;
@property(nonatomic) int remoteWidth,remoteHeight;
- (void)releaseInputs;
- (void)sendSpecialKey:(int)key toggle:(BOOL)toggle;
- (void)sendRightClick;
@end
