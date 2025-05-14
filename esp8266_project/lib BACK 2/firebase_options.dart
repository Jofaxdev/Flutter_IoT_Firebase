import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for Fuchsia.');
      case TargetPlatform.linux:
        // TODO: Handle this case.
      case TargetPlatform.windows:
        // TODO: Handle this case.
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBYLUONPdFLlc2cQap-2LEq5nh51POzqvo',
    appId: '1:27099870753:web:someWebAppID', // Cập nhật với Web App ID của bạn
    messagingSenderId: '27099870753',
    projectId: 'esp8266-flutter-app',
    authDomain: 'esp8266-flutter-app.firebaseapp.com',
    databaseURL: 'https://esp8266-flutter-app-default-rtdb.firebaseio.com',
    storageBucket: 'esp8266-flutter-app.appspot.com',
    measurementId: 'G-XXXXXXXXXX', // Nếu không sử dụng Google Analytics, có thể để trống
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYLUONPdFLlc2cQap-2LEq5nh51POzqvo',
    appId: '1:27099870753:android:ab9cd70a8bba7d0c519560',
    messagingSenderId: '27099870753',
    projectId: 'esp8266-flutter-app',
    databaseURL: 'https://esp8266-flutter-app-default-rtdb.firebaseio.com',
    storageBucket: 'esp8266-flutter-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYLUONPdFLlc2cQap-2LEq5nh51POzqvo',
    appId: '1:27099870753:web:someWebAppID', // Cập nhật với Web App ID của bạn
    messagingSenderId: '27099870753',
    projectId: 'esp8266-flutter-app',
    databaseURL: 'https://esp8266-flutter-app-default-rtdb.firebaseio.com',
    storageBucket: 'esp8266-flutter-app.appspot.com',
    androidClientId: 'xxxxxxxxxxxxxxxxxxx', // Nếu có thông tin này
    iosClientId: 'xxxxxxxxxxxxxxxxxxx', // Nếu có thông tin này
    iosBundleId: 'com.example.esp8266_project', // Nếu có thông tin này
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBYLUONPdFLlc2cQap-2LEq5nh51POzqvo',
    appId: '1:27099870753:web:someWebAppID', // Cập nhật với Web App ID của bạn
    messagingSenderId: '27099870753',
    projectId: 'esp8266-flutter-app',
    databaseURL: 'https://esp8266-flutter-app-default-rtdb.firebaseio.com',
    storageBucket: 'esp8266-flutter-app.appspot.com',
    androidClientId: 'xxxxxxxxxxxxxxxxxxx', // Nếu có thông tin này
    iosClientId: 'xxxxxxxxxxxxxxxxxxx', // Nếu có thông tin này
    iosBundleId: 'com.example.esp8266_project', // Nếu có thông tin này
  );
}
