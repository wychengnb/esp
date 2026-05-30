#include "libkfd.h"
#include "Common.h"
#include <unistd.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static uint64_t g_kfd=0,g_kbase=0,g_task=0;
static bool g_run=true;

#define off_allproc 0x698
#define off_pid 0x68
#define off_proc_next 0x8
#define off_task 0x10
#define off_vm_map 0x28

// PUBG 2026 libUE4 固定偏移
#define OFF_GWORLD      0x38A12B0
#define OFF_PC          0x38
#define OFF_PAWN        0x168
#define OFF_LOC         0x1A0
#define OFF_MATRIX      0x890
#define OFF_HEALTH      0x238
#define OFF_MAXHEALTH   0x240
#define OFF_TEAM        0x260
#define OFF_MESH        0x280
#define OFF_ANIM        0x6A0
#define OFF_BONEMATRIX  0xB48
#define OFF_CURRENTLEVEL 0x1E8
#define OFF_ACTOR_ARRAY 0x30
#define OFF_ACTOR_COUNT 0x38

// 骨骼索引
#define BONE_HEAD       0
#define BONE_TORSO      2
#define BONE_LHAND      5
#define BONE_RHAND      8
#define BONE_LFOOT      11
#define BONE_RFOOT      14

uint64_t get_kernel_base(void){
    uint64_t leak=0;
    kread(g_kfd,0xFFFFFFF000001008,&leak,8);
    return leak&~0xFFFFFULL;
}

uint64_t get_task_by_pid(int pid){
    uint64_t allproc,p;
    kread(g_kfd,g_kbase+off_allproc,&allproc,8);
    p=allproc;
    while(p){
        uint64_t val;
        kread(g_kfd,p+off_pid,&val,8);
        if((int)val==pid){
            kread(g_kfd,p+off_task,&val,8);
            return val;
        }
        kread(g_kfd,p+off_proc_next,&p,8);
    }
    return 0;
}

// 自动查找PUBG PID
int find_pubg_pid(void){
    uint64_t allproc,p;
    char name[32]={0};
    kread(g_kfd,g_kbase+off_allproc,&allproc,8);
    p=allproc;
    while(p){
        uint64_t pid;
        kread(g_kfd,p+0x68,&pid,8);
        kread(g_kfd,p+0x1E0,name,24);
        if(strstr(name,"PUBG")){
            return (int)pid;
        }
        kread(g_kfd,p+off_proc_next,&p,8);
    }
    return 0;
}

// 内核隐藏自身进程（反作弊第一层）
static void hide_self(int self_pid){
    uint64_t allproc,p,prev=0;
    kread(g_kfd,g_kbase+off_allproc,&allproc,8);
    p=allproc;
    while(p){
        uint64_t pid;
        kread(g_kfd,p+0x68,&pid,8);
        if((int)pid==self_pid){
            uint64_t next_p;
            kread(g_kfd,p+0x8,&next_p,8);
            kwrite(g_kfd,&next_p,prev+0x8,8);
            break;
        }
        prev=p;
        kread(g_kfd,p+off_proc_next,&p,8);
    }
}

// KFD无痕初始化（反作弊第四层）
bool kfd_init(int pid,int self_pid){
    g_kfd=kopen(2048, puaf_method_puppet, kr_method_sem_open, kw_method_sem_open);
    if(!g_kfd)return false;
    g_kbase=get_kernel_base();
    g_task=get_task_by_pid(pid);
    hide_self(self_pid);
    return g_task!=0;
}

// 随机时序安全读取（反作弊第三层）
static bool vm_read_final(uint64_t va,void*buf,size_t len){
    uint64_t vm_map;
    kread(g_kfd,g_task+off_vm_map,&vm_map,8);
    size_t pos=0;
    while(pos<len){
        uint64_t dat;
        kread(g_kfd,va+pos,&dat,8);
        memcpy((char*)buf+pos,&dat,8);
        pos+=8;
        usleep(100 + rand()%300);
    }
    return true;
}

// 读取单个骨骼坐标
bool read_bone(uint64_t pawn, int bone_idx, Vec3* out){
    uint64_t mesh, anim, bone_mat;
    vm_read_final(pawn+OFF_MESH,&mesh,8);
    if(!mesh)return false;
    vm_read_final(mesh+OFF_ANIM,&anim,8);
    if(!anim)return false;
    vm_read_final(anim+OFF_BONEMATRIX,&bone_mat,8);
    if(!bone_mat)return false;
    vm_read_final(bone_mat+bone_idx*64,out,12);
    return true;
}

// 读取完整骨骼
bool read_skeleton(uint64_t pawn, Skeleton* sk){
    if(!read_bone(pawn,BONE_HEAD,&sk->head))return false;
    if(!read_bone(pawn,BONE_TORSO,&sk->torso))return false;
    if(!read_bone(pawn,BONE_LHAND,&sk->lhand))return false;
    if(!read_bone(pawn,BONE_RHAND,&sk->rhand))return false;
    if(!read_bone(pawn,BONE_LFOOT,&sk->lfoot))return false;
    if(!read_bone(pawn,BONE_RFOOT,&sk->rfoot))return false;
    return true;
}

// 读取视图投影矩阵
bool read_matrix(float mat[16],uint64_t base){
    uint64_t gw,pc,pawn;
    vm_read_final(base+OFF_GWORLD,&gw,8);
    if(!gw)return false;
    vm_read_final(gw+OFF_PC,&pc,8);
    vm_read_final(pc+OFF_PAWN,&pawn,8);
    vm_read_final(pawn+OFF_MATRIX,mat,64);
    return true;
}

// 三维欧几里得距离计算
float get_distance(Vec3 a, Vec3 b){
    float dx=a.x-b.x;
    float dy=a.y-b.y;
    float dz=a.z-b.z;
    return sqrtf(dx*dx+dy*dy+dz*dz);
}

// 简易隔墙检测（距离阈值法）
bool is_visible(Vec3 self, Vec3 target, float dist){
    // 130米内认为可能可见，超过默认隔墙
    return dist<=13000.0f;
}

// 遍历敌人：300米内敌方+隔墙状态检测
int get_enemy_list(Enemy arr[MAX_ENEMY], uint64_t base, Vec3 self_pos, int self_team){
    int cnt=0;
    uint64_t gw, level, tarray, elist;
    vm_read_final(base+OFF_GWORLD,&gw,8);
    if(!gw)return 0;
    vm_read_final(gw+OFF_CURRENTLEVEL,&level,8);
    vm_read_final(level+OFF_ACTOR_ARRAY,&tarray,8);
    vm_read_final(tarray,&elist,8);
    int num;
    vm_read_final(tarray+8,&num,4);
    
    for(int i=0;i<num&&cnt<MAX_ENEMY;i++){
        uint64_t actor;
        vm_read_final(elist+i*8,&actor,8);
        if(!actor)continue;
        
        float hp, maxhp;
        int team;
        vm_read_final(actor+OFF_HEALTH,&hp,4);
        vm_read_final(actor+OFF_MAXHEALTH,&maxhp,4);
        vm_read_final(actor+OFF_TEAM,&team,4);
        
        // 基础过滤：仅存活+仅敌方+300米限制
        if(hp<=0||hp>maxhp)continue;
        if(team==self_team)continue;
        
        Skeleton sk;
        if(!read_skeleton(actor,&sk))continue;
        
        float dist=get_distance(self_pos, sk.head);
        if(dist>30000.0f)continue; // 精确300米限制
        
        arr[cnt].sk=sk;
        arr[cnt].hp=hp;
        arr[cnt].maxhp=maxhp;
        arr[cnt].distance=dist;
        arr[cnt].is_visible=is_visible(self_pos, sk.head, dist);
        cnt++;
    }
    
    // 按距离从小到大排序
    for(int i=0;i<cnt-1;i++){
        for(int j=0;j<cnt-i-1;j++){
            if(arr[j].distance>arr[j+1].distance){
                Enemy temp=arr[j];
                arr[j]=arr[j+1];
                arr[j+1]=temp;
            }
        }
    }
    
    return cnt;
}

// 获取自身位置和队伍
bool get_self_info(Vec3* pos, int* team, uint64_t base){
    uint64_t gw,pc,pawn;
    vm_read_final(base+OFF_GWORLD,&gw,8);
    if(!gw)return false;
    vm_read_final(gw+OFF_PC,&pc,8);
    vm_read_final(pc+OFF_PAWN,&pawn,8);
    vm_read_final(pawn+OFF_LOC,pos,12);
    vm_read_final(pawn+OFF_TEAM,team,4);
    return true;
}

void daemon_run(int game_pid,int self_pid,uint64_t base,int pipe_w){
    float mat[16];
    Enemy enemies[MAX_ENEMY];
    Vec3 self_pos;
    int self_team;
    int enemy_count;
    
    srand((unsigned int)time(NULL));
    while(g_run){
        if(!read_matrix(mat,base))continue;
        if(!get_self_info(&self_pos,&self_team,base))continue;
        
        enemy_count=get_enemy_list(enemies,base,self_pos,self_team);
        
        // 写入管道数据
        write(pipe_w,&enemy_count,4);
        for(int i=0;i<enemy_count;i++){
            write(pipe_w,&enemies[i],sizeof(Enemy));
        }
        write(pipe_w,mat,sizeof(float)*16);
        
        // 随机帧间隔14-18ms，打破严格60Hz特征
        usleep(14000 + rand()%4000);
    }
    kclose(g_kfd);
}

void daemon_stop(void){g_run=false;}