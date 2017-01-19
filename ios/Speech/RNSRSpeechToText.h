#import <Foundation/Foundation.h>
#import "RCTEventDispatcher.h"

@class RCTEventDispatcher;

@interface RNSRSpeechToText : NSObject

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;
- (void)listenAndTranslate:(void (^)(NSString *))completionHandler;
- (void)stop:(void (^)(NSString *))completionHandler;

@end
