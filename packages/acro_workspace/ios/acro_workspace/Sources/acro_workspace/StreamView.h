#import <UIKit/UIKit.h>
@interface StreamView:UIView<UIKeyInput,UIGestureRecognizerDelegate>
@property(nonatomic) BOOL connected,trackpad,scrollEnabled,rightClickEnabled,softwareKeyboardRequested;
@property(nonatomic) int remoteWidth,remoteHeight;
@property(nonatomic,copy) void (^viewportChanged)(void);
- (void)releaseInputs;
- (void)sendSpecialKey:(int)key toggle:(BOOL)toggle;
- (void)sendRightClick;
@end
