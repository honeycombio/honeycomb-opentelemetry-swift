#import "CatchNSException.h"

@implementation CatchNSException

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

+ (void)crashTheApp {
    @throw [NSException exceptionWithName:@"IntentionalCrash"
                                   reason:@"Pushed the crash button"
                                 userInfo:nil];
}

@end
