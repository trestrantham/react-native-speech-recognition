import { NativeModules } from 'react-native';

const { RNSpeechRecognition } = NativeModules;

class SpeechRecognition {
  listen() {
    return RNSpeechRecognition.listen();
  }

  stop() {
    return RNSpeechRecognition.stop();
  }
}

module.exports = new SpeechRecognition();
