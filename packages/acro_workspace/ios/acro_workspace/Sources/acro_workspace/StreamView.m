#import "AcroPrefix.h"
#import "StreamView.h"
#import "KeyboardSupport.h"
#include <Limelight.h>
@implementation StreamView {
  NSMutableSet<NSNumber*> *_keys;
  NSMutableSet<UIPress*> *_physicalPresses;
  UIView* _silentInput;
  BOOL _dragging,_stylus;
}
- (instancetype)initWithFrame:(CGRect)frame {
  if((self=[super initWithFrame:frame])){
    self.backgroundColor=UIColor.blackColor; self.multipleTouchEnabled=YES;
    _trackpad=YES;_rightClickEnabled=YES;_scrollEnabled=YES;_keys=[NSMutableSet set];_physicalPresses=[NSMutableSet set];_silentInput=[[UIView alloc]initWithFrame:CGRectZero];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)];
    tap.delegate=self;[self addGestureRecognizer:tap];
    UITapGestureRecognizer *right=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(right:)];
    right.numberOfTouchesRequired=2;right.delegate=self;[self addGestureRecognizer:right];
    [tap requireGestureRecognizerToFail:right];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
    pan.maximumNumberOfTouches=1;pan.delegate=self;[self addGestureRecognizer:pan];
    UIPanGestureRecognizer *scroll=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(scroll:)];
    scroll.minimumNumberOfTouches=2;scroll.maximumNumberOfTouches=2;scroll.delegate=self;[self addGestureRecognizer:scroll];
    UILongPressGestureRecognizer *drag=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(drag:)];
    drag.minimumPressDuration=.4;drag.delegate=self;[self addGestureRecognizer:drag];
    UIHoverGestureRecognizer *hover=[[UIHoverGestureRecognizer alloc]initWithTarget:self action:@selector(hover:)];[self addGestureRecognizer:hover];
  }return self;
}
- (void)layoutSubviews {[super layoutSubviews];if(self.viewportChanged)self.viewportChanged();}
- (CGRect)videoRect {
  if(self.remoteWidth<=0||self.remoteHeight<=0)return CGRectZero;
  CGFloat scale=MIN(self.bounds.size.width/self.remoteWidth,self.bounds.size.height/self.remoteHeight);
  CGSize size=CGSizeMake(self.remoteWidth*scale,self.remoteHeight*scale);
  return CGRectMake((self.bounds.size.width-size.width)/2,(self.bounds.size.height-size.height)/2,size.width,size.height);
}
- (BOOL)point:(CGPoint)p {
  CGRect rect=[self videoRect];if(!self.connected||CGRectIsEmpty(rect)||!CGRectContainsPoint(rect,p))return NO;
  int x=MIN(self.remoteWidth-1,MAX(0,(p.x-rect.origin.x)/rect.size.width*self.remoteWidth));
  int y=MIN(self.remoteHeight-1,MAX(0,(p.y-rect.origin.y)/rect.size.height*self.remoteHeight));
  LiSendMousePositionEvent(x,y,self.remoteWidth,self.remoteHeight);return YES;
}
- (void)click:(int)button {
  if(!self.connected)return;LiSendMouseButtonEvent(BUTTON_ACTION_PRESS,button);LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE,button);
}
- (void)tap:(UITapGestureRecognizer*)gesture {
  if((self.trackpad&&!_stylus)||[self point:[gesture locationInView:self]])[self click:BUTTON_LEFT];
}
- (void)right:(UITapGestureRecognizer*)gesture { if(self.rightClickEnabled)[self sendRightClick]; }
- (void)sendRightClick { [self click:BUTTON_RIGHT]; }
- (void)pan:(UIPanGestureRecognizer*)gesture {
  if(!self.connected)return;
  CGPoint delta=[gesture translationInView:self];
  if(self.trackpad&&!_stylus)LiSendMouseMoveEvent((short)delta.x,(short)delta.y);
  else {
    if(gesture.state==UIGestureRecognizerStateBegan&&[self point:[gesture locationInView:self]]){_dragging=YES;LiSendMouseButtonEvent(BUTTON_ACTION_PRESS,BUTTON_LEFT);}
    [self point:[gesture locationInView:self]];
  }
  [gesture setTranslation:CGPointZero inView:self];
  if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled){if(_dragging)LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE,BUTTON_LEFT);_dragging=NO;}
}
- (void)scroll:(UIPanGestureRecognizer*)gesture {
  if(!self.connected||!self.scrollEnabled)return;CGPoint delta=[gesture translationInView:self];
  LiSendHighResScrollEvent((short)(delta.y*3));LiSendHighResHScrollEvent((short)(delta.x*3));[gesture setTranslation:CGPointZero inView:self];
}
- (void)drag:(UILongPressGestureRecognizer*)gesture {
  if(!self.connected)return;
  if(gesture.state==UIGestureRecognizerStateBegan){if(!self.trackpad||_stylus)[self point:[gesture locationInView:self]];_dragging=YES;LiSendMouseButtonEvent(BUTTON_ACTION_PRESS,BUTTON_LEFT);}
  else if(gesture.state==UIGestureRecognizerStateChanged){[self point:[gesture locationInView:self]];}
  else if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled){if(_dragging)LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE,BUTTON_LEFT);_dragging=NO;}
}
- (void)hover:(UIHoverGestureRecognizer*)gesture { [self point:[gesture locationInView:self]]; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gesture shouldReceiveTouch:(UITouch*)touch {_stylus=touch.type==UITouchTypeStylus;return self.connected;}
- (UIView*)inputView{return self.softwareKeyboardRequested?nil:_silentInput;}
- (BOOL)canBecomeFirstResponder {return YES;}
- (BOOL)hasText{return YES;}
- (UIKeyboardType)keyboardType{return UIKeyboardTypeDefault;}
- (UITextAutocorrectionType)autocorrectionType{return UITextAutocorrectionTypeNo;}
- (UITextSpellCheckingType)spellCheckingType{return UITextSpellCheckingTypeNo;}
- (void)insertText:(NSString*)text {if(self.connected)LiSendUtf8TextEvent(text.UTF8String,(unsigned int)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);}
- (void)deleteBackward { [self sendSpecialKey:0x08 toggle:NO]; }
- (void)sendSpecialKey:(int)key toggle:(BOOL)toggle {
  if(!self.connected||key<1||key>255)return;
  if(toggle){if([_keys containsObject:@(key)]){LiSendKeyboardEvent(0x8000|key,KEY_ACTION_UP,0);[_keys removeObject:@(key)];}
    else{LiSendKeyboardEvent(0x8000|key,KEY_ACTION_DOWN,0);[_keys addObject:@(key)];}}
  else {LiSendKeyboardEvent(0x8000|key,KEY_ACTION_DOWN,0);LiSendKeyboardEvent(0x8000|key,KEY_ACTION_UP,0);}
}
- (void)pressesBegan:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {for(UIPress *p in presses)if(self.connected){[_physicalPresses addObject:p];[KeyboardSupport sendKeyEventForPress:p down:YES];}}
- (void)pressesEnded:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {for(UIPress *p in presses){if(self.connected)[KeyboardSupport sendKeyEventForPress:p down:NO];[_physicalPresses removeObject:p];}}
- (void)pressesCancelled:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {[self pressesEnded:presses withEvent:event];}
- (void)releaseInputs {
  if(self.connected){LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE,BUTTON_LEFT);LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE,BUTTON_RIGHT);
    for(NSNumber *key in _keys)LiSendKeyboardEvent(0x8000|key.intValue,KEY_ACTION_UP,0);}
  if(self.connected)for(UIPress *press in _physicalPresses)[KeyboardSupport sendKeyEventForPress:press down:NO];
  [_physicalPresses removeAllObjects];[_keys removeAllObjects];self.softwareKeyboardRequested=NO;_dragging=NO;[self resignFirstResponder];self.connected=NO;
}
@end
