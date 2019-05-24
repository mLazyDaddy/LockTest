//
//  ViewController.m
//  LockTest
//
//

#import "ViewController.h"
#import "MultiJobs.h"

@interface ViewController (){
    MultiJobs *_job;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    _job = [[MultiJobs alloc] initWithJobsCount:pow(1000, 2)];
    [_job runJobsInMultipleThreads:10];
}
@end
