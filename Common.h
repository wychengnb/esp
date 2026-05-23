#ifndef Common_h
#define Common_h
typedef struct{float x,y,z;}Vec3;
typedef struct{
    Vec3 head;Vec3 torso;Vec3 lhand,rhand;Vec3 lfoot,rfoot;
}Skeleton;
#define PIPE_READ  0
#define PIPE_WRITE 1
#endif