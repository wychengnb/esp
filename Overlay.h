#import <UIKit/UIKit.h>
#import "Common.h"
@interface PubgOverlay : UIWindow
-(void)renderEnemies:(Enemy*)enemies count:(int)cnt matrix:(float*)m;
-(void)clearAll;
@end