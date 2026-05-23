#import "ViewController.h"
#import "Overlay.h"
#import "Common.h"
#include <unistd.h>

static BOOL g_running=NO;
static BOOL g_draw=YES;
static PubgOverlay*g_ov;
static int g_pipe[2];

extern "C"{
    bool kfd_init(int game_pid,int self_pid);
    void daemon_run(int game_pid,int self_pid,uint64_t base,int pipe_w);
    void daemon_stop(void);
}

@interface MainVC()
@property UITextField*pidInput;
@property UISwitch*swDraw;
@property UIButton*btnStart,*btnStop;
@end
@implementation MainVC
- (void)viewDidLoad{
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.blackColor;
    pipe(g_pipe);
    g_ov=[[PubgOverlay alloc]init];
    g_ov.hidden=YES;

    self.pidInput=[[UITextField alloc]initWithFrame:CGRectMake(30,80,260,44)];
    self.pidInput.placeholder=@"PUBG PID";
    self.pidInput.textColor=UIColor.whiteColor;
    self.pidInput.backgroundColor=UIColor.darkGrayColor;
    self.pidInput.borderStyle=UITextBorderStyleRoundedRect;
    [self.view addSubview:self.pidInput];

    UILabel*lab=[[UILabel alloc]initWithFrame:CGRectMake(30,140,120,30)];
    lab.text=@"骨骼绘制";lab.textColor=UIColor.whiteColor;
    [self.view addSubview:lab];

    self.swDraw=[[UISwitch alloc]initWithFrame:CGRectMake(180,140,60,30)];
    self.swDraw.on=YES;
    [self.swDraw addTarget:self action:@selector(swChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.swDraw];

    self.btnStart=[UIButton buttonWithType:UIButtonTypeSystem];
    self.btnStart.frame=CGRectMake(30,190,260,45);
    [self.btnStart setTitle:@"启动研究程序" forState:UIControlStateNormal];
    [self.btnStart setTitleColor:UIColor.greenColor forState:UIControlStateNormal];
    [self.btnStart addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStart];

    self.btnStop=[UIButton buttonWithType:UIButtonTypeSystem];
    self.btnStop.frame=CGRectMake(30,250,260,45);
    [self.btnStop setTitle:@"停止" forState:UIControlStateNormal];
    [self.btnStop setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    [self.btnStop addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStop];
}
-(void)swChange:(UISwitch*)s{g_draw=s.on;}
-(void)start{
    if(g_running)return;
    int pid=self.pidInput.text.intValue;
    if(pid<=0)return;
    g_running=YES;
    g_ov.hidden=NO;
    int self_pid=getpid();
    uint64_t base=0x100000000;
    dispatch_async(dispatch_get_global_queue(0,0),^{
        if(!kfd_init(pid,self_pid)){g_running=NO;return;}
        daemon_run(pid,self_pid,base,g_pipe[PIPE_WRITE]);
    });
    dispatch_async(dispatch_get_global_queue(0,0),^{
        Skeleton sk;float mat[16];
        while(g_running){
            read(g_pipe[PIPE_READ],&sk,sizeof(Skeleton));
            read(g_pipe[PIPE_READ],mat,sizeof(float)*16);
            if(g_draw)[g_ov renderSkeleton:sk mat:mat];
            else [g_ov clearAll];
        }
    });
}
-(void)stop{
    g_running=NO;
    daemon_stop();
    g_ov.hidden=YES;
    [g_ov clearAll];
}
@end