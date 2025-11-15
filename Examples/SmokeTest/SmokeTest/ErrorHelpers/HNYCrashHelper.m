#import "HNYCrashHelper.h"

@implementation HNYCrashHelper

+ (NSException *)throwAndCatchNSException {
    NSException *exception = nil;
    @try {
        @throw [NSException exceptionWithName:@"TestException"
                                       reason:@"Exception Handling reason"
                                     userInfo:nil];
    } @catch (NSException *caughtException) {
        exception = caughtException;
    } @finally {
        return exception;
    }
}

+ (void)segfault {
    int *p = NULL;
    *p = 0;
}

+ (void)throwNSException {
    @throw [NSException exceptionWithName:@"IntentionalCrash"
                                   reason:@"Pushed the crash button"
                                 userInfo:nil];
}

@end
