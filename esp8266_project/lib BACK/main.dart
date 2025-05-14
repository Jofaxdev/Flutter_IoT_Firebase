import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
// import 'package:esp8266_project/screens/iotscreen.dart';
import 'firebase_options.dart'; // Cấu hình firebase tới API của mình

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions
        .currentPlatform, // Sử dụng tùy chọn Firebase đã định nghĩa
  ); // Khởi tạo Firebase

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: <String, WidgetBuilder>{},
      title: 'Flutter Demo',
      theme: ThemeData(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      // home: IotScreen(),
    );
  }
}
