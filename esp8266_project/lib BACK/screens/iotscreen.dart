import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class IotScreen extends StatefulWidget {
  @override
  _IotScreenState createState() => _IotScreenState();
}

class _IotScreenState extends State<IotScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  bool isLightOn = false;

  @override
  void initState() {
    super.initState();
    // Load initial state from Firebase
    dbRef.child("LightState").onValue.listen((event) {
      final bool lightState = event.snapshot.child("switch").value as bool? ?? false;
      setState(() {
        isLightOn = lightState;
      });
    });
  }

  void toggleLight() {
    setState(() {
      isLightOn = !isLightOn;
    });
    dbRef.child("LightState").set({"switch": isLightOn});
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('IoT Light Control'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: isLightOn ? Colors.yellow : Colors.grey[800],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isLightOn ? Colors.yellowAccent : Colors.grey,
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.lightbulb,
                  color: isLightOn ? Colors.white : Colors.grey[700],
                  size: 100,
                ),
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: toggleLight,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLightOn ? Colors.red : Colors.green, // Use backgroundColor instead of primary
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                elevation: 10,
              ),
              child: Text(
                isLightOn ? 'Turn Off' : 'Turn On',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
