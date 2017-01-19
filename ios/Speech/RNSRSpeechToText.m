#import "RCTEventDispatcher.h"
#import "RNSRSpeechToText.h"

#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

@interface RNSRSpeechToText() <SFSpeechRecognitionTaskDelegate,SFSpeechRecognizerDelegate>
@property (strong, nonatomic) RCTEventDispatcher* eventDispatcher;

@property (strong, nonatomic) AVAudioEngine* audioEngine;
@property (strong, nonatomic) AVSpeechSynthesizer* speechSynthesizer;
@property (strong, nonatomic) SFSpeechAudioBufferRecognitionRequest* recognitionRequest;
@property (strong, nonatomic) SFSpeechRecognizer* speechRecognizer;

@property (strong, nonatomic) AVAudioInputNode* inputNode;
@property (strong, nonatomic) SFSpeechRecognitionTask* recognitionTask;

@property (copy) void (^completionHandler)(NSString *);
@end

@implementation RNSRSpeechToText

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
    }
  }

  return self;
}

- (void)listenAndTranslate:(void (^)(NSString *))completionHandler
{
  self.completionHandler = completionHandler;

  NSError *outError; 

  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setCategory:AVAudioSessionCategoryRecord error:&outError];
  [audioSession setMode:AVAudioSessionModeMeasurement error:&outError];
  [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&outError];

  self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];

  self.inputNode = [self.audioEngine inputNode];

  if (self.recognitionRequest == nil) {
    NSLog(@"Unable to created a SFSpeechAudioBufferRecognitionRequest object");
  }

  if (self.inputNode == nil) {
    NSLog(@"Unable to created a inputNode object");
  }

  // self.recognitionRequest.shouldReportPartialResults = true;
  self.recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;

  self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest delegate:self];

  [self.inputNode installTapOnBus:0
    bufferSize:4096 
    format:[self.inputNode outputFormatForBus:0]
    block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) 
    { 
      // NSLog(@"Block tap!"); 
      [self.recognitionRequest appendAudioPCMBuffer:buffer]; 
    } 
  ]; 

  [self.audioEngine prepare]; 
  [self.audioEngine startAndReturnError:&outError]; 

  NSLog(@"Error %@", outError); 
}

 - (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)result 
 { 
   NSLog(@"speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition"); 
   NSString *translatedString = [[[result bestTranscription] formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

   self.completionHandler(translatedString);

   if ([result isFinal] && self.audioEngine) { 
     [self.audioEngine stop]; 
     [[self.audioEngine inputNode] removeTapOnBus:0]; 
     task = nil; 
     self.recognitionRequest = nil; 
   } 
 } 

- (void)speechRecognitionDidDetectSpeech:(SFSpeechRecognitionTask *)task
{
  NSLog(@"speechRecognitionDidDetectSpeech");
   // self.completionHandler(@"speechRecognitionDidDetectSpeech");
}

- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)successfully
{
  NSLog(@"speechRecognitionTask didFinishSuccessfully");
   // self.completionHandler(@"speechRecognitionTask didFinishSuccessfully");
}

- (void)speechRecognitionTaskFinishedReadingAudio:(SFSpeechRecognitionTask *)task
{
  NSLog(@"speechRecognitionTaskFinishedReadingAudio");
   // self.completionHandler(@"speechRecognitionTaskFinishedReadingAudio");
}

- (void)speechRecognitionTaskWasCancelled:(SFSpeechRecognitionTask *)task
{
  NSLog(@"speechRecognitionTaskWasCancelled");
   // self.completionHandler(@"speechRecognitionTaskWasCancelled");
}

- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didHypothesizeTranscription:(SFTranscription *)transcription
{
  NSLog(@"speechRecognitionTask didHypothesizeTranscription");
  NSString *translatedString = [[transcription formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSLog(translatedString);
   // self.completionHandler(translatedString);

   [self.eventDispatcher sendAppEventWithName:@"RNSpeechRecognition:translatedText" body:@{@"text": translatedString, @"state": @"hypothesized"}];
}

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available
{
  NSLog(@"speechRecognizer availabilityDidChange");
   // self.completionHandler(@"speechRecognizer availabilityDidChange");
}

@end
