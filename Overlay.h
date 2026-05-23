#import <UIKit/UIKit.h>
#import "Common.h"
@interface PubgOverlay : UIWindow
-(void)renderSkeleton:(Skeleton)sk mat:(float*)m;
-(void)clearAll;
@end