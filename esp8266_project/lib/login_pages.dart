import 'package:esp8266_project/color.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_page.dart';
import 'package:esp8266_project/constant.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AnimationController? _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _waveAnimation;

  // Đăng nhập với Google
  Future<User?> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Khởi tạo AnimationController
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    // Hiệu ứng sóng (Scale từ nhỏ đến lớn)
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeInOut,
    ));

    // Opacity animation cho nút
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeIn,
    ));

    // Khởi động animation
    _controller?.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AnimatedContainer cho hiệu ứng sóng từ CircleAvatar
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Container(
                  width: _scaleAnimation.value * 300, // Kích thước sóng mở rộng
                  height: _scaleAnimation.value * 300,
                  decoration: BoxDecoration(
                    color: lightgreenshede,
                    borderRadius:
                        BorderRadius.circular(150), // Duy trì hình tròn
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 120,
                      backgroundColor: lightgreenshede,
                      child: Image.asset(
                        'assets/icon/logo2.png', // Đường dẫn đến logo
                        height: 120,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 32),
            // Văn bản "Welcome to Tim!"
            FadeTransition(
              opacity: _opacityAnimation,
              child: Text(
                'Welcome to Tim!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primarygreen,
                ),
              ),
            ),
            SizedBox(height: 8),
            // Văn bản mô tả
            FadeTransition(
              opacity: _opacityAnimation,
              child: Text(
                "Hi there! Let's get your tech journey started.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: primarygreen,
                ),
              ),
            ),
            SizedBox(height: 32),
            // Nút đăng nhập với hiệu ứng độ mờ
            FadeTransition(
              opacity: _opacityAnimation,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ButtonColor,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  User? user = await _signInWithGoogle();
                  if (user != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => HomePage()),
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FontAwesomeIcons.google, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Login with Google',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
