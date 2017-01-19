#import <Speech/Speech.h>
#import "RCTBridge.h"
#import "RNSpeechRecognition.h"
#import "RNSRSpeechToText.h"

@interface RNSpeechRecognition()
@property (strong, nonatomic) RNSRSpeechToText *speechToTextManager;
@end

@implementation RNSpeechRecognition

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_REMAP_METHOD(listen, listen_resolver:(RCTPromiseResolveBlock)resolve listen_rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.speechToTextManager == nil) {
    self.speechToTextManager = [[RNSRSpeechToText alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
  }

  [self.speechToTextManager listenAndTranslate:resolve];
}

RCT_REMAP_METHOD(stop, stop_resolver:(RCTPromiseResolveBlock)resolve stop_rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.speechToTextManager != nil) {
    [self.speechToTextManager stop:resolve];
  }
}

@end
