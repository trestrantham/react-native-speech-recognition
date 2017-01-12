
# react-native-speech-recognition

## Getting started

`$ npm install react-native-speech-recognition --save`

### Mostly automatic installation

`$ react-native link react-native-speech-recognition`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-speech-recognition` and add `RNSpeechRecognition.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNSpeechRecognition.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNSpeechRecognitionPackage;` to the imports at the top of the file
  - Add `new RNSpeechRecognitionPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-speech-recognition'
  	project(':react-native-speech-recognition').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-speech-recognition/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-speech-recognition')
  	```

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNSpeechRecognition.sln` in `node_modules/react-native-speech-recognition/windows/RNSpeechRecognition.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Cl.Json.RNSpeechRecognition;` to the usings at the top of the file
  - Add `new RNSpeechRecognitionPackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNSpeechRecognition from 'react-native-speech-recognition';

// TODO: What do with the module?
RNSpeechRecognition;
```
  