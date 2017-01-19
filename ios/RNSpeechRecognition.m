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

RCT_REMAP_METHOD(listen, resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  if (self.speechToTextManager == nil) {
    self.speechToTextManager = [[RNSRSpeechToText alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
  }

  [self.speechToTextManager listenAndTranslate:resolve];
}

@end
