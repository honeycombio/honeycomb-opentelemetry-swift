//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>

@interface HNYCrashHelper : NSObject

+ (NSException *)throwAndCatchNSException;

+ (void)segfault;

+ (void)throwNSException;

@end
