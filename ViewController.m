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
    int find_pubg_pid(void);
}

@interface MainVC()
@property UILabel *tipLab;
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

    self.tipLab=[[UILabel alloc]initWithFrame:CGRectMake(20,60,280,40)];
    self.tipLab.text=@"PUBG 学术研究工具";
    self.tipLab.textColor=UIColor.greenColor;
    self.tipLab.textAlignment=NSTextAlignmentCenter;
    self.tipLab.font=[UIFont systemFontOfSize:16];
    [self.view addSubview:self.tipLab];

    UILabel*lab=[[UILabel alloc]initWithFrame:CGRectMake(30,120,120,30)];
    lab.text=@"透视绘制";lab.textColor=UIColor.whiteColor;
    [self.view addSubview:lab];

    self.swDraw=[[UISwitch alloc]initWithFrame:CGRectMake(180,120,60,30)];
    self.swDraw.on=YES;
    [self.swDraw addTarget:self action:@selector(swChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.swDraw];

    self.btnStart=[UIButton buttonWithType:UIButtonTypeSystem];
    self.btnStart.frame=CGRectMake(30,170,260,45);
    [self.btnStart setTitle:@"启动研究程序" forState:UIControlStateNormal];
    [self.btnStart setTitleColor:UIColor.greenColor forState:UIControlStateNormal];
    self.btnStart.titleLabel.font=[UIFont systemFontOfSize:18];
    [self.btnStart addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStart];

    self.btnStop=[UIButton buttonWithType:UIButtonTypeSystem];
    self.btnStop.frame=CGRectMake(30,230,260,45);
    [self.btnStop setTitle:@"停止" forState:UIControlStateNormal];
    [self.btnStop setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    self.btnStop.titleLabel.font=[UIFont systemFontOfSize:18];
    [self.btnStop addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStop];
}

-(void)swChange:(UISwitch*)s{g_draw=s.on;}

-(void)start{
    if(g_running)return;
    g_running=YES;
    g_ov.hidden=NO;
    int self_pid=getpid();
    uint64_t base=0x100000000;
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND,0),^{
        int pid = find_pubg_pid();
        dispatch_async(dispatch_get_main_queue(),^{
            if(pid<=0){
                self.tipLab.text=@"未检测到PUBG进程";
                g_running=NO;
                return;
            }
            self.tipLab.text=[NSString stringWithFormat:@"已连接 PID:%d",pid];
        });
        if(!kfd_init(pid,self_pid)){
            dispatch_async(dispatch_get_main_queue(),^{
                self.tipLab.text=@"KFD初始化失败";
                g_running=NO;
            });
            return;
        }
        daemon_run(pid,self_pid,base,g_pipe[PIPE_WRITE]);
    });
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND,0),^{
        int enemy_count;
        Enemy enemies[MAX_ENEMY];
        float mat[16];
        while(g_running){
            read(g_pipe[PIPE_READ],&enemy_count,4);
            for(int i=0;i<enemy_count;i++){
                read(g_pipe[PIPE_READ],&enemies[i],sizeof(Enemy));
            }
            read(g_pipe[PIPE_READ],mat,sizeof(float)*16);
            
            if(g_draw){
                [g_ov renderEnemies:enemies count:enemy_count matrix:mat];
            }else{
                [g_ov clearAll];
            }
        }
    });
}

-(void)stop{
    g_running=NO;
    daemon_stop();
    g_ov.hidden=YES;
    [g_ov clearAll];
    dispatch_async(dispatch_get_main_queue(),^{
        self.tipLab.text=@"已停止";
    });
}
@end