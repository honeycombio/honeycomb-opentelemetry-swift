//
//  CatchNSException.m
//  SmokeTest
//
//  Created by Arri Blais on 2/26/25.
//

#import "CatchNSException.h"

@implementation CatchNSException

+ (NSException *)throwAndCatchNSException {
    NSException * exception = nil;
    @try {
        @throw [NSException exceptionWithName:@"TestException" reason:@"Exception Handling reason" userInfo: nil];
    }
    @catch(NSException * caughtException) {
        exception = caughtException;
    }
    @finally {
        return exception;
    }
}

@end
