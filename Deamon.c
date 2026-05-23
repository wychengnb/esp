#include "libkfd.h"
#include "Common.h"
#include <unistd.h>
#include <stdint.h>
#include <stdbool.h>

static uint64_t g_kfd=0,g_kbase=0,g_task=0;
static bool g_run=true;

#define off_allproc 0x698
#define off_pid 0x68
#define off_proc_next 0x8
#define off_task 0x10
#define off_vm_map 0x28

#define OFF_GWORLD      0x38A12B0
#define OFF_PC          0x38
#define OFF_PAWN        0x168
#define OFF_LOC         0x1A0
#define OFF_MATRIX      0x890
#define BONE_HEAD       0x2C0
#define BONE_TORSO      0x1A0
#define BONE_LHAND      0x380
#define BONE_RHAND      0x390
#define BONE_LFOOT      0x420
#define BONE_RFOOT      0x430

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

static void hide_self(int self_pid)
{
    uint64_t allproc,p,prev=0;
    kread(g_kfd,g_kbase+0x698,&allproc,8);
    p=allproc;
    while(p){
        uint64_t pid;
        kread(g_kfd,p+off_pid,&pid,8);
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

bool kfd_init(int pid,int self_pid){
    g_kfd=kopen(2048,puaf_method_puppet,kr_method_sem_open,kw_method_sem_open);
    if(!g_kfd)return false;
    g_kbase=get_kernel_base();
    g_task=get_task_by_pid(pid);
    hide_self(self_pid);
    return g_task!=0;
}

static bool vm_read_safe(uint64_t va,void*buf,size_t len){
    uint64_t vm_map;
    kread(g_kfd,g_task+off_vm_map,&vm_map,8);
    size_t pos=0;
    while(pos<len){
        uint64_t dat;
        kread(g_kfd,va+pos,&dat,8);
        memcpy((char*)buf+pos,&dat,8);
        pos+=8;
        usleep(350);
    }
    return true;
}

bool read_matrix(float mat[16],uint64_t base){
    uint64_t gw,pc,pawn;
    vm_read_safe(base+OFF_GWORLD,&gw,8);
    if(!gw)return false;
    vm_read_safe(gw+OFF_PC,&pc,8);
    vm_read_safe(pc+OFF_PAWN,&pawn,8);
    vm_read_safe(pawn+OFF_MATRIX,mat,64);
    return true;
}

bool read_skeleton(Skeleton*sk,uint64_t base){
    uint64_t gw,pc,pawn;
    vm_read_safe(base+OFF_GWORLD,&gw,8);
    if(!gw)return false;
    vm_read_safe(gw+OFF_PC,&pc,8);
    vm_read_safe(pc+OFF_PAWN,&pawn,8);
    vm_read_safe(pawn+BONE_HEAD,&sk->head,12);
    vm_read_safe(pawn+BONE_TORSO,&sk->torso,12);
    vm_read_safe(pawn+BONE_LHAND,&sk->lhand,12);
    vm_read_safe(pawn+BONE_RHAND,&sk->rhand,12);
    vm_read_safe(pawn+BONE_LFOOT,&sk->lfoot,12);
    vm_read_safe(pawn+BONE_RFOOT,&sk->rfoot,12);
    return true;
}

void daemon_run(int game_pid,int self_pid,uint64_t base,int pipe_w){
    float mat[16];
    Skeleton sk;
    while(g_run){
        if(read_matrix(mat,base)&&read_skeleton(&sk,base)){
            write(pipe_w,&sk,sizeof(Skeleton));
            write(pipe_w,mat,sizeof(float)*16);
        }
        usleep(16000);
    }
    kclose(g_kfd);
}

void daemon_stop(void){g_run=false;}