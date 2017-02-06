#import "RCTEventDispatcher.h"
#import "RNSRSpeechToText.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <Speech/Speech.h>

@interface RNSRSpeechToText() <AVCaptureAudioDataOutputSampleBufferDelegate,SFSpeechRecognitionTaskDelegate,SFSpeechRecognizerDelegate>
@property (nonatomic) dispatch_queue_t sessionQueue;

@property (strong, nonatomic) RCTEventDispatcher* eventDispatcher;
@property (strong, nonatomic) NSTimer* speechTimeoutTimer;

@property (nonatomic) AVCaptureSession* captureSession;
@property (nonatomic) SFSpeechAudioBufferRecognitionRequest* recognitionRequest;
@property (nonatomic) SFSpeechRecognizer* speechRecognizer;

@property (copy) void (^completionHandler)(NSString *);
@end

@implementation RNSRSpeechToText

static int const SPEECH_TIMEOUT_SECONDS = 45;
static double const POWER_MIN = -50;
static double const POWER_MAX = -5;
static double const POWER_SCALE_FACTOR = (1 - 0) + 0; // (MAX - MIN) + MIN;
static BOOL const logging = false;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
  if (self = [super init]) {
    self.eventDispatcher = eventDispatcher;

    if (self.sessionQueue == nil) {
      self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
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
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
    if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
      self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
      [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest delegate:self];

      // Start capturing in a serial queue (not main) to allow for smooth animations
      dispatch_async(self.sessionQueue, ^{
        [self startCapture];
      });
    }
  }];
}

- (void)stop:(void (^)(NSString *))completionHandler
{
  self.completionHandler = completionHandler;

  if (logging) NSLog(@"Invalidating speech timeout timer");
  [self.speechTimeoutTimer invalidate];
  self.speechTimeoutTimer = nil;

  [self endCapture];
  [self.recognitionRequest endAudio];
}

- (void)startCapture
{
  NSError *error;

  if (logging) NSLog(@"Allocatiing capture session");
  self.captureSession = [[AVCaptureSession alloc] init];
  self.captureSession.automaticallyConfiguresApplicationAudioSession = NO;

  AVCaptureDevice *audioDev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
  if (audioDev == nil){
    NSLog(@"Couldn't create audio capture device");
    return ;
  }

  // create mic device
  if (logging) NSLog(@"Creating capture device input");
  AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDev error:&error];
  if (error != nil){
    NSLog(@"Couldn't create audio input");
    return ;
  }

  // add mic device in capture object
  if ([self.captureSession canAddInput:audioIn] == NO){
    NSLog(@"Couldn't add audio input");
    return ;
  }
  [self.captureSession addInput:audioIn];

  // export audio data
  AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
  [audioOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

  if ([self.captureSession canAddOutput:audioOutput] == NO){
    NSLog(@"Couldn't add audio output");
    return ;
  }

  if (logging) NSLog(@"Adding output to capture session");
  [self.captureSession addOutput:audioOutput];
  [audioOutput connectionWithMediaType:AVMediaTypeAudio];

  // Speech recognition can only run for ~1 minute so we set a timer to return back to the caller
  // when the timeout is reached. This allows a caller to respond appropriately (in the view, etc.).
  self.speechTimeoutTimer = [NSTimer
    scheduledTimerWithTimeInterval:SPEECH_TIMEOUT_SECONDS
    target: self
    selector: @selector(triggerSpeechTimeout:)
    userInfo: nil
    repeats: false
  ];

  if (logging) NSLog(@"Starting capture session");
  [self.captureSession startRunning];
  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceListening" body:@(true)];
  if (logging) NSLog(@"Done starting capture session");
}

-(void)endCapture
{
  if (self.captureSession != nil && [self.captureSession isRunning]) {
    [self.captureSession stopRunning];
  }

  if (logging) NSLog(@"Dispatching voiceListening=false");
  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceListening" body:@(false)];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  [self.recognitionRequest appendAudioSampleBuffer:sampleBuffer];

  NSArray *audioChannels = connection.audioChannels;

  if (audioChannels.count > 0) {
    AVCaptureAudioChannel *channel = audioChannels[0];
    Float32 averagePower = channel.averagePowerLevel;

    averagePower = 1 - ((averagePower - POWER_MAX) / (POWER_MIN - POWER_MAX)) * POWER_SCALE_FACTOR;
    averagePower = averagePower < 0 ? 0 : averagePower;
    averagePower = averagePower > 1 ? 1 : averagePower;

    [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:voiceInputLevel" body:@(averagePower)];
  }

 - (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)result
{
  if (logging) NSLog(@"speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition");
  NSString *translatedString = [[[result bestTranscription] formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if ([result isFinal]) {
    [self stop:false];
  }

  [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:translatedText" body:@{@"text": translatedString, @"state": @"final"}];
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
