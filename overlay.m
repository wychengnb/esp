#import "Overlay.h"
static float sw,sh;
static CGPoint World2Screen(float x,float y,float z,float mat[16])
{
    float vx=mat[0]*x+mat[1]*y+mat[2]*z+mat[3];
    float vy=mat[4]*x+mat[5]*y+mat[6]*z+mat[7];
    float vz=mat[8]*x+mat[9]*y+mat[10]*z+mat[11];
    float w=mat[12]*x+mat[13]*y+mat[14]*z+mat[15];
    float px=mat[0]*vx+mat[1]*vy+mat[2]*vz+mat[3]*w;
    float py=mat[4]*vx+mat[5]*vy+mat[6]*vz+mat[7]*w;
    float pw=mat[12]*vx+mat[13]*vy+mat[14]*vz+mat[15]*w;
    if(pw<0.02f)return CGPointMake(-1,-1);
    float sx=(px/pw+1)*0.5*sw;
    float sy=(1-py/pw)*0.5*sh;
    return CGPointMake(sx,sy);
}

@interface PubgOverlay()
@property UIView *root;
@end
@implementation PubgOverlay
-(instancetype)init{
    self=[super init];
    sw=[UIScreen mainScreen].bounds.size.width;
    sh=[UIScreen mainScreen].bounds.size.height;
    self.frame=[UIScreen mainScreen].bounds;
    self.windowLevel=999999;
    self.backgroundColor=UIColor.clearColor;
    self.root=[UIView new];
    self.root.frame=self.bounds;
    self.root.backgroundColor=UIColor.clearColor;
    [self addSubview:self.root];
    return self;
}
-(void)renderSkeleton:(Skeleton)sk mat:(float*)m
{
    dispatch_async(dispatch_get_main_queue(),^{
        [self.root.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        CGPoint h=World2Screen(sk.head.x,sk.head.y,sk.head.z,m);
        CGPoint t=World2Screen(sk.torso.x,sk.torso.y,sk.torso.z,m);
        CGPoint lh=World2Screen(sk.lhand.x,sk.lhand.y,sk.lhand.z,m);
        CGPoint rh=World2Screen(sk.rhand.x,sk.rhand.y,sk.rhand.z,m);
        CGPoint lf=World2Screen(sk.lfoot.x,sk.lfoot.y,sk.lfoot.z,m);
        CGPoint rf=World2Screen(sk.rfoot.x,sk.rfoot.y,sk.rfoot.z,m);
        if(h.x<0||t.x<0)return;
        UIBezierPath*path=[UIBezierPath bezierPath];
        path.lineWidth=2;
        [path moveToPoint:h];[path addLineToPoint:t];
        [path moveToPoint:t];[path addLineToPoint:lh];
        [path moveToPoint:t];[path addLineToPoint:rh];
        [path moveToPoint:t];[path addLineToPoint:lf];
        [path moveToPoint:t];[path addLineToPoint:rf];
        CAShapeLayer*line=[CAShapeLayer layer];
        line.path=path.CGPath;
        line.strokeColor=UIColor.whiteColor.CGColor;
        line.fillColor=nil;
        [self.root.layer addSublayer:line];
        void(^dot)(CGPoint)=^(CGPoint p){
            if(p.x<0)return;
            UIView*d=[UIView new];
            d.frame=CGRectMake(p.x-4,p.y-4,8,8);
            d.backgroundColor=UIColor.redColor;
            d.layer.cornerRadius=4;
            [self.root addSubview:d];
        };
        dot(h);dot(t);dot(lh);dot(rh);dot(lf);dot(rf);
    });
}
-(void)clearAll{
    [self.root.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.root.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
}
@end