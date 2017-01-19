import { NativeModules } from 'react-native';

const { RNSpeechRecognition } = NativeModules;

class SpeechRecognition {
  listen() {
    return RNSpeechRecognition.listen();
  }
}

module.exports = new SpeechRecognition();
