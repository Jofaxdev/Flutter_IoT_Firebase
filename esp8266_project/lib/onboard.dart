import 'dart:async';

import 'package:esp8266_project/login_pages.dart';
import 'package:flutter/material.dart';
import 'package:esp8266_project/constant.dart';
import 'package:esp8266_project/model/allinonboardscreen.dart';

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  int currentIndex = 0;
  Timer? _timer;

  late PageController _pageController;

  List<AllinOnboardModel> allinonboardlist = [
    AllinOnboardModel(
        "assets/images/design3.png",
        "Faculty of Technology\nDevelopment Team: Nguyen Van Du, Le Van Khang, Nguyen Thanh Tan, Nguyen Ngoc Tho\nInstructor: PhD. Luong Phuong Toan",
        "Mien Tay Construction University"),
    AllinOnboardModel(
        "assets/images/design1.png",
        "Gain practical skills in IoT development and applications.",
        "Build innovative solutions for a connected future."),
    AllinOnboardModel(
        "assets/images/design2.png",
        "Join our vibrant community of IoT enthusiasts and experts.",
        "Connect with fellow students and industry professionals.")
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients && _pageController.page != null) {
        currentIndex = (currentIndex + 1) % allinonboardlist.length;
        _pageController.animateToPage(
          currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: (screenHeight < 700 ||
                          screenWidth > 700 && screenHeight > 1000)
                      ? 0
                      : screenHeight * 0,
                ),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (value) {
                    setState(() {
                      currentIndex = value;
                      _startTimer();
                    });
                  },
                  itemCount: allinonboardlist.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height:
                          constraints.maxHeight * 0.6, // Đặt chiều cao cụ thể
                      width: constraints.maxWidth,
                      child: PageBuilderWidget(
                        title: allinonboardlist[index].titlestr,
                        description: allinonboardlist[index].description,
                        imgurl: allinonboardlist[index].imgStr,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.2,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    allinonboardlist.length,
                    (index) => buildDot(index: index),
                  ),
                ),
              ),
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.08,
                left: screenWidth * 0.2,
                right: screenWidth * 0.2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    backgroundColor: ButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  AnimatedContainer buildDot({int? index}) {
    return AnimatedContainer(
      duration: kAnimationDuration,
      margin: const EdgeInsets.only(right: 5),
      height: 6,
      width: currentIndex == index ? 20 : 6,
      decoration: BoxDecoration(
        color: currentIndex == index ? primarygreen : const Color(0xFFD8D8D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class PageBuilderWidget extends StatelessWidget {
  final String title;
  final String description;
  final String imgurl;

  const PageBuilderWidget({
    super.key,
    required this.title,
    required this.description,
    required this.imgurl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double baseFontSize = constraints.maxWidth * 0.04;
        return Container(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: constraints.maxHeight * 0.14, // Dịch lên trên một chút
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.start, // Đưa các phần tử lên trên
            crossAxisAlignment:
                CrossAxisAlignment.center, // Canh giữa theo chiều ngang
            children: [
              Image.asset(
                imgurl,
                height: constraints.maxHeight * 0.4,
                width: constraints.maxWidth * 0.8,
                fit: BoxFit.contain,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primarygreen,
                  fontSize: baseFontSize * 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: constraints.maxHeight * 0.01),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primarygreen,
                  fontSize: baseFontSize * 1.05,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
