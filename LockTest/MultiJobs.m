//
//  Lock.m
//  LockTest
//
//

#import "MultiJobs.h"
#import <QuartzCore/QuartzCore.h>
typedef NS_ENUM(NSUInteger,TLockType) {
    TLockTypeDispatch_semaphore,
    TLockTypePthread_mutex,
    TLockTypeNSCondition,
    TLockTypeNSLock,
    TLockTypeThread_mutex_recursive,
    TLockTypeNSRecursiveLock,
    TLockTypeNSConditionLock,
    TLockTypeSynchronized,
    TLockTypeUnfair,
    TLockTypeCount,
};

NSTimeInterval TTimeCosts[TLockTypeCount] = {0};


@interface MultiJobs ()
{
    TLockType currentLockType;
    
    dispatch_semaphore_t semaphoreLock;
    pthread_mutex_t mutexLock;
    NSConditionLock *conditionLock;
    NSLock *lock;
    pthread_mutex_t mutexRecursiveLock;
    NSRecursiveLock *recursiveLock;
    NSConditionLock *conditionLockWithCondition;
    os_unfair_lock unfairLock;
    NSObject *synchronizedLock;
}
@end

@implementation MultiJobs
- (id)initWithJobsCount:(unsigned int)count{
    self = [super init];
    if (self) {
        jobCount = count;
        countLock = OS_UNFAIR_LOCK_INIT;
        logLock = OS_UNFAIR_LOCK_INIT;
        
        semaphoreLock = dispatch_semaphore_create(1);
        pthread_mutex_init(&mutexLock,NULL);
        conditionLock = [[NSConditionLock alloc] init];
        lock = [NSLock new];
        {
            pthread_mutexattr_t attr;
            pthread_mutexattr_init(&attr);
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
            pthread_mutex_init(&mutexRecursiveLock, &attr);
            pthread_mutexattr_destroy(&attr);
        }
        recursiveLock = [NSRecursiveLock new];
        conditionLockWithCondition = [[NSConditionLock alloc] initWithCondition:1];
        synchronizedLock = [NSObject new];
        
        nextJobIndex = 0;
        currentLockType = 0;
        
        
    }
    return self;
}

- (void)startNextType{
    nextJobIndex = 0;
    currentLockType ++;
    shouldLog = NO;
    if (currentLockType < TLockTypeCount) {
        [self runJobsInMultipleThreads:threadCount];
    }else{
        [self log];
    }
    
}

- (int)nextJobIndex{
    int result = -1;
    NSTimeInterval begin = CACurrentMediaTime();
    switch (currentLockType) {
        case TLockTypeDispatch_semaphore:
            [self nextIndexUsingSemaphoreLock:&result];
            break;
        case TLockTypePthread_mutex:
            [self nextIndexUsingMutexLock:&result];
            break;
        case TLockTypeNSCondition:
            [self nextIndexUsingConditionLock:&result];
            break;
        case TLockTypeNSLock:
            [self nextIndexUsingNSLock:&result];
            break;
        case TLockTypeThread_mutex_recursive:
            [self nextIndexUsingMutexRecursiveLock:&result];
            break;
        case TLockTypeNSRecursiveLock:
            [self nextIndexUsingRecursiveLock:&result];
            break;
        case TLockTypeSynchronized:
            [self nextIndexUsingSychornizedLock:&result];
            break;
        case TLockTypeUnfair:
            [self nextIndexUsingUnfairLock:&result];
            break;
        case TLockTypeNSConditionLock:
            [self nextIndexUsingConditionLockWithCondition:&result];
        default:
            break;
    }
    NSTimeInterval end = CACurrentMediaTime();
    os_unfair_lock_lock(&countLock);
    TTimeCosts[currentLockType] += end - begin;
    os_unfair_lock_unlock(&countLock);
    return result;
}

- (void)nextIndexUsingSemaphoreLock:(int *)index{
    dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER);
    *index = [self nextIndex];
    dispatch_semaphore_signal(semaphoreLock);
}

- (void)nextIndexUsingMutexLock:(int *)index{
    pthread_mutex_lock(&mutexLock);
    *index = [self nextIndex];
    pthread_mutex_unlock(&mutexLock);
}

- (void)nextIndexUsingNSLock:(int *)index{
    [lock lock];
    *index = [self nextIndex];
    [lock unlock];
}

- (void)nextIndexUsingMutexRecursiveLock:(int *)index{
    pthread_mutex_lock(&mutexRecursiveLock);
    *index = [self nextIndex];
    pthread_mutex_unlock(&mutexRecursiveLock);
}

- (void)nextIndexUsingRecursiveLock:(int *)index{
    [recursiveLock lock];
    *index = [self nextIndex];
    [recursiveLock unlock];
}

- (void)nextIndexUsingConditionLock:(int *)index{
    [conditionLock lock];
    *index = [self nextIndex];
    [conditionLock unlock];
}

- (void)nextIndexUsingConditionLockWithCondition:(int *)index{
    [conditionLockWithCondition lock];
    *index = [self nextIndex];
    [conditionLockWithCondition unlock];
}

- (void)nextIndexUsingSychornizedLock:(int *)index{
    @synchronized (synchronizedLock) {
        *index = [self nextIndex];
    }
}

- (void)nextIndexUsingUnfairLock:(int *)index{
    os_unfair_lock_lock(&unfairLock);
    *index = [self nextIndex];
    os_unfair_lock_unlock(&unfairLock);
}

- (int)nextIndex{
    int result = -1;
    if(nextJobIndex < jobCount){
        result = nextJobIndex;
        nextJobIndex ++;
    }
    return result;
}

- (void)runJobs:(id)sender{
    int i = [self nextJobIndex];
    while (i>= 0 ) {
        i = [self nextJobIndex];
    }
    os_unfair_lock_lock(&logLock);
    if (!shouldLog) {
        shouldLog = YES;
        if (currentLockType < TLockTypeCount) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self startNextType];
            });
        }
        
    }
    
    os_unfair_lock_unlock(&logLock);
}

- (void)runJobsInMultipleThreads:(unsigned int)count{
    threadCount = count;
    
    for (int i = 1; i<=threadCount; i++) {        
        [NSThread detachNewThreadSelector:@selector(runJobs:) toTarget:self withObject:self];
    }
}

- (void)log{
    printf("os_unfair_lock:             %8.2f ms\n",TTimeCosts[TLockTypeUnfair]*1000);
    printf("@synchronized:              %8.2f ms\n",TTimeCosts[TLockTypeSynchronized]*1000);
    printf("dispatch_semaphore:         %8.2f ms\n",TTimeCosts[TLockTypeDispatch_semaphore]*1000);
    printf("pthread_mutex:              %8.2f ms\n",TTimeCosts[TLockTypePthread_mutex]*1000);
    
    printf("NSLock:                     %8.2f ms\n",TTimeCosts[TLockTypeNSLock]*1000);
    printf("pthread_mutex(recursive):   %8.2f ms\n",TTimeCosts[TLockTypeThread_mutex_recursive]*1000);
    printf("NSRecursiveLock:            %8.2f ms\n",TTimeCosts[TLockTypeNSRecursiveLock]*1000);
    printf("NSCondition:                %8.2f ms\n",TTimeCosts[TLockTypeNSCondition]*1000);
    printf("NSConditionLock:            %8.2f ms\n",TTimeCosts[TLockTypeNSConditionLock]*1000);
}
@end
