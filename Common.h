#ifndef Common_h
#define Common_h
typedef struct{float x,y,z;}Vec3;
typedef struct{
    Vec3 head;
    Vec3 torso;
    Vec3 lhand,rhand;
    Vec3 lfoot,rfoot;
}Skeleton;
typedef struct{
    Skeleton sk;
    float hp;
    float maxhp;
    float distance;
    int is_visible; // 1=可见(不隔墙) 0=不可见(隔墙)
}Enemy;
#define PIPE_READ  0
#define PIPE_WRITE 1
#define MAX_ENEMY 16
#endif