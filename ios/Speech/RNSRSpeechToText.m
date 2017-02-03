#import "RCTEventDispatcher.h"
#import "RNSRSpeechToText.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <Speech/Speech.h>

@interface RNSRSpeechToText() <SFSpeechRecognitionTaskDelegate,SFSpeechRecognizerDelegate>
@property (strong, nonatomic) RCTEventDispatcher* eventDispatcher;
@property (strong, nonatomic) NSTimer* speechTimeoutTimer;

@property (strong, nonatomic) AVAudioEngine* audioEngine;
@property (strong, nonatomic) AVSpeechSynthesizer* speechSynthesizer;
@property (strong, nonatomic) SFSpeechAudioBufferRecognitionRequest* recognitionRequest;
@property (strong, nonatomic) SFSpeechRecognitionTask* recognitionTask;
@property (strong, nonatomic) SFSpeechRecognizer* speechRecognizer;

@property (copy) void (^completionHandler)(NSString *);
@end

@implementation RNSRSpeechToText

static int const SPEECH_TIMEOUT_SECONDS = 45;
static double const POWER_MIN = -25;
static double const POWER_MAX = -80;
static double const POWER_SCALE_FACTOR = (1 - 0) + 0; // (MAX - MIN) + MIN;
static BOOL const logging = false;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
  if (self = [super init]) {
    self.eventDispatcher = eventDispatcher;

    if (self.audioEngine == nil) {
      self.audioEngine = [[AVAudioEngine alloc] init];
    }

    if (self.speechSynthesizer == nil) {
      self.speechSynthesizer  = [[AVSpeechSynthesizer alloc] init];
      [self.speechSynthesizer setDelegate:self];
    }

    if (self.speechRecognizer == nil) {
      self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
      [self.speechRecognizer setDelegate:self];
      [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceAvailable" body:@([self.speechRecognizer isAvailable])];
    }
  }

  return self;
}

- (void)listenAndTranslate:(void (^)(NSString *))completionHandler
{
  self.completionHandler = completionHandler;

  if (self.recognitionTask != nil) {
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
  }

  NSError *outError;

  if (logging) NSLog(@"Setting up AVAudioEngine");
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setCategory:AVAudioSessionCategoryRecord error:&outError];
  [audioSession setMode:AVAudioSessionModeMeasurement error:&outError];
  [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&outError];

  if (logging) NSLog(@"Creating SFSpeechAudioBufferRecognitionRequest");
  self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];

  AVAudioInputNode *inputNode = [self.audioEngine inputNode];

  if (self.recognitionRequest == nil) {
    if (logging) NSLog(@"Unable to created a SFSpeechAudioBufferRecognitionRequest object");
  }

  if (inputNode == nil) {
    if (logging) NSLog(@"Unable to created a inputNode object");
  }

  self.recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
  if (logging) NSLog(@"Creating recognition task");
  self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest delegate:self];

  if (logging) NSLog(@"Installing tap");
  [inputNode installTapOnBus:0
    bufferSize:4096
    format:[inputNode outputFormatForBus:0]
    block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when)
    {
      [self.recognitionRequest appendAudioPCMBuffer:buffer];
      [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceListening" body:@(true)];

      UInt32 inNumberFrames = buffer.frameLength;
      Float32 averagePower = 0;

      if (buffer.format.channelCount > 0) {
        Float32* samples = (Float32*)buffer.floatChannelData[0];
        Float32 averageValue = 0;

        vDSP_meamgv((Float32*)samples, 1, &averageValue, inNumberFrames);

        Float32 normalizedValue = (averageValue == 0) ? -100 : 20.0;
        Float32 powerValue = normalizedValue * log10f(averageValue);

        averagePower = 1 - ((powerValue - POWER_MIN) / (POWER_MAX - POWER_MIN)) * POWER_SCALE_FACTOR;
        averagePower = averagePower < 0 ? 0 : averagePower;
        averagePower = averagePower > 1 ? 1 : averagePower;
      }

      [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceInputLevel" body:@(averagePower)];
    }
  ];

  // Speech recognition can only run for ~1 minute so we set a timer to return back to the caller
  // when the timeout is reached. This allows a caller to respond appropriately (in the view, etc.).
  self.speechTimeoutTimer = [NSTimer
    scheduledTimerWithTimeInterval:SPEECH_TIMEOUT_SECONDS
    target: self
    selector: @selector(triggerSpeechTimeout:)
    userInfo: nil
    repeats: false
  ];

  if (logging) NSLog(@"Preparing engine and starting");
  [self.audioEngine prepare];
  [self.audioEngine startAndReturnError:&outError];

  if (logging) NSLog(@"Error %@", outError);
}

- (void)stop:(void (^)(NSString *))completionHandler
{
  if (logging) NSLog(@"Invalidating speech timeout timer");
  [self.speechTimeoutTimer invalidate];
  self.speechTimeoutTimer = nil;

  if (self.audioEngine.isRunning) {
    if (logging) NSLog(@"Stopping audio engine");
    [self.audioEngine stop];
    if (logging) NSLog(@"Removing audio engine tap");
    [[self.audioEngine inputNode] removeTapOnBus:0];

    if (self.recognitionRequest != nil) {
      [self.recognitionRequest endAudio];
    }
    if (logging) NSLog(@"Ending audio on recognition request");
  }

  self.recognitionRequest = nil;
  self.recognitionTask = nil;

  if (logging) NSLog(@"Dispatching voiceListening=false");
  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceListening" body:@(false)];
  if (logging) NSLog(@"Calling completion handler");
}

 - (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)result
{
  if (logging) NSLog(@"speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition");
  NSString *translatedString = [[[result bestTranscription] formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if ([result isFinal]) {
    [self stop:false];
  }

  self.completionHandler(translatedString);
}

- (void)speechRecognitionTaskWasCancelled:(SFSpeechRecognitionTask *)task
{
  if (logging) NSLog(@"speechRecognitionTaskWasCancelled");
  [self stop:false];
}

- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didHypothesizeTranscription:(SFTranscription *)transcription
{
  if (logging) NSLog(@"speechRecognitionTask didHypothesizeTranscription");
  NSString *translatedString = [[transcription formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:translatedText" body:@{@"text": translatedString, @"state": @"hypothesized"}];
}

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available
{
  if (logging) NSLog(@"speechRecognizer availabilityDidChange");
  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceAvailable" body:@(available)];
}

- (void)triggerSpeechTimeout:(NSTimer *)timer
{
  if (logging) NSLog(@"triggerSpeechTimeout");
  [self stop:false];
  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceSpeechTimeout" body:@(true)];
}

@end
