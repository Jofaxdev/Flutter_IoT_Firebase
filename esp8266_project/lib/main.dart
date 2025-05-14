import 'package:esp8266_project/home_page.dart';
import 'package:esp8266_project/login_pages.dart';
import 'package:esp8266_project/onboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // Cấu hình firebase tới API của mình

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;

  try {
    Firebase.app(); // Thử lấy instance mặc định
    firebaseInitialized = true;
  } catch (e) {
    // Nếu lỗi (chưa có instance), thì mới khởi tạo
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true; // Đánh dấu đã khởi tạo
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP8266 Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasData) {
            return HomePage();
          } else {
            return OnboardScreen();
          }
        },
      ),
    );
  }
}
