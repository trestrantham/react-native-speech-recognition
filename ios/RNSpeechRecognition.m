#import "RNSpeechRecognition.h"

@implementation RNSpeechRecognition

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_REMAP_METHOD(listen, resolve:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@"From RNSpeechRecognition");
}

@end
