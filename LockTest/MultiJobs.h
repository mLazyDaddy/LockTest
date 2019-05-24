//
//  Lock.h
//  LockTest
//
//

#import <Foundation/Foundation.h>
#import <os/lock.h>
#import <pthread.h>
#import <libkern/OSAtomic.h>

NS_ASSUME_NONNULL_BEGIN

@interface MultiJobs : NSObject{
    int nextJobIndex;
    NSTimeInterval cost;
    
    unsigned int jobCount;
    
    os_unfair_lock countLock;
    
    os_unfair_lock logLock;
    BOOL shouldLog;
    unsigned int threadCount;
}
- (void)runJobsInMultipleThreads:(unsigned int)count;
- (id)initWithJobsCount:(unsigned int)count;
@end

NS_ASSUME_NONNULL_END
