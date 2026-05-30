#import "Overlay.h"
static float sw,sh;

static CGPoint World2Screen(float x,float y,float z,float mat[16]){
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
    self.windowLevel=UIWindowLevelAlert+10;
    self.backgroundColor=UIColor.clearColor;
    self.root=[[UIView alloc]initWithFrame:self.bounds];
    self.root.backgroundColor=UIColor.clearColor;
    [self addSubview:self.root];
    return self;
}

-(void)renderEnemies:(Enemy*)enemies count:(int)cnt matrix:(float*)m{
    dispatch_async(dispatch_get_main_queue(),^{
        [self.root.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self.root.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
        
        for(int i=0;i<cnt;i++){
            Enemy e=enemies[i];
            
            CGPoint h=World2Screen(e.sk.head.x,e.sk.head.y,e.sk.head.z,m);
            CGPoint t=World2Screen(e.sk.torso.x,e.sk.torso.y,e.sk.torso.z,m);
            CGPoint lh=World2Screen(e.sk.lhand.x,e.sk.lhand.y,e.sk.lhand.z,m);
            CGPoint rh=World2Screen(e.sk.rhand.x,e.sk.rhand.y,e.sk.rhand.z,m);
            CGPoint lf=World2Screen(e.sk.lfoot.x,e.sk.lfoot.y,e.sk.lfoot.z,m);
            CGPoint rf=World2Screen(e.sk.rfoot.x,e.sk.rfoot.y,e.sk.rfoot.z,m);
            
            if(h.x<0||t.x<0)continue;
            
            // 颜色区分：可见=红色，隔墙=绿色
            UIColor *mainColor = e.is_visible ? [UIColor redColor] : [UIColor greenColor];
            
            // 绘制敌人方框
            float boxHeight=fabs(h.y-t.y)*2.5;
            float boxWidth=boxHeight*0.6;
            CGRect boxRect=CGRectMake(t.x-boxWidth/2, t.y-boxHeight/2, boxWidth, boxHeight);
            
            UIBezierPath*boxPath=[UIBezierPath bezierPathWithRect:boxRect];
            boxPath.lineWidth=1.5;
            CAShapeLayer*boxLayer=[CAShapeLayer layer];
            boxLayer.path=boxPath.CGPath;
            boxLayer.strokeColor=mainColor.CGColor;
            boxLayer.fillColor=nil;
            [self.root.layer addSublayer:boxLayer];
            
            // 绘制骨骼
            UIBezierPath*bonePath=[UIBezierPath bezierPath];
            bonePath.lineWidth=1.8 + (arc4random()%10)/10.0;
            [bonePath moveToPoint:h];[bonePath addLineToPoint:t];
            [bonePath moveToPoint:t];[bonePath addLineToPoint:lh];
            [bonePath moveToPoint:t];[bonePath addLineToPoint:rh];
            [bonePath moveToPoint:t];[bonePath addLineToPoint:lf];
            [bonePath moveToPoint:t];[bonePath addLineToPoint:rf];
            
            CAShapeLayer*boneLayer=[CAShapeLayer layer];
            boneLayer.path=bonePath.CGPath;
            boneLayer.strokeColor=mainColor.CGColor;
            boneLayer.fillColor=nil;
            [self.root.layer addSublayer:boneLayer];
            
            // 绘制关节点
            void(^dot)(CGPoint)=^(CGPoint p){
                if(p.x<0)return;
                UIView*d=[[UIView alloc]initWithFrame:CGRectMake(p.x-4,p.y-4,8,8)];
                d.backgroundColor=mainColor;
                d.layer.cornerRadius=4;
                [self.root addSubview:d];
            };
            dot(h);dot(t);dot(lh);dot(rh);dot(lf);dot(rf);
            
            // 绘制血量条
            float hpPercent=e.hp/e.maxhp;
            CGRect hpBgRect=CGRectMake(boxRect.origin.x-2, boxRect.origin.y-8, boxRect.size.width+4, 4);
            UIBezierPath*hpBgPath=[UIBezierPath bezierPathWithRect:hpBgRect];
            CAShapeLayer*hpBgLayer=[CAShapeLayer layer];
            hpBgLayer.path=hpBgPath.CGPath;
            hpBgLayer.fillColor=UIColor.grayColor.CGColor;
            [self.root.layer addSublayer:hpBgLayer];
            
            CGRect hpRect=CGRectMake(boxRect.origin.x-2, boxRect.origin.y-8, (boxRect.size.width+4)*hpPercent, 4);
            UIBezierPath*hpPath=[UIBezierPath bezierPathWithRect:hpRect];
            CAShapeLayer*hpLayer=[CAShapeLayer layer];
            hpLayer.path=hpPath.CGPath;
            hpLayer.fillColor=hpPercent>0.5?UIColor.greenColor.CGColor:UIColor.redColor.CGColor;
            [self.root.layer addSublayer:hpLayer];
            
            // 绘制距离文字
            NSString*distStr=[NSString stringWithFormat:@"%.1fm",e.distance/100];
            UILabel*distLabel=[[UILabel alloc]initWithFrame:CGRectMake(boxRect.origin.x, boxRect.origin.y+boxRect.size.height+2, 60, 14)];
            distLabel.text=distStr;
            distLabel.textColor=UIColor.whiteColor;
            distLabel.font=[UIFont systemFontOfSize:12];
            distLabel.backgroundColor=UIColor.clearColor;
            [self.root addSubview:distLabel];
        }
    });
}

-(void)clearAll{
    [self.root.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.root.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
}
@end