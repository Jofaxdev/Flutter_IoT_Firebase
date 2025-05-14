import 'dart:async';

import 'package:esp8266_project/login_pages.dart';
import 'package:esp8266_project/widget/QrScanner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomePage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController deviceController = TextEditingController();
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  final GoogleSignIn googleSignIn = GoogleSignIn();

  Future<void> _deleteDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Xóa thiết bị khỏi danh sách thiết bị của người dùng
        await _databaseReference
            .child('users/${user.uid}/devices/$deviceId')
            .remove();

        // Hiển thị thông báo xóa thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa thiết bị $deviceId')),
        );
      } catch (e) {
        // Hiển thị thông báo lỗi nếu có
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa thiết bị: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String deviceId, String customName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Ngăn chặn việc đóng dialog khi chạm ra ngoài
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Bo tròn góc dialog
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded, // Icon cảnh báo
                color: Colors.red, // Màu đỏ cho icon
                size: 30, // Kích thước icon
              ),
              SizedBox(width: 10), // Khoảng cách giữa icon và text
              Text(
                'Confirm deletion',
                style: TextStyle(fontWeight: FontWeight.bold), // In đậm tiêu đề
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete device "$customName"?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey), // Màu xám cho nút Cancel
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
              },
            ),
            TextButton(
              child: Text(
                'Yes',
                style: TextStyle(color: Colors.red), // Màu đỏ cho nút Yes
              ),
              onPressed: () async {
                await _deleteDevice(deviceId, context); // Gọi hàm xóa thiết bị
                Navigator.of(context).pop(); // Đóng dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      // Check if the device exists in the main devices node
      final DatabaseReference deviceExistsRef =
          _databaseReference.child('devices/$deviceId');
      final DatabaseEvent deviceExistsSnapshot = await deviceExistsRef.once();

      if (deviceExistsSnapshot.snapshot.value != null) {
        // If device exists, check if it's already in the user's devices list
        final DatabaseReference userDevicesRef =
            _databaseReference.child('users/${user.uid}/devices/$deviceId');
        final DataSnapshot userDeviceSnapshot = await userDevicesRef.get();

        if (userDeviceSnapshot.exists) {
          // If device already exists in the user's list, show a message
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId already exists!')));
        } else {
          // If device doesn't exist in the user's list, add it
          await userDevicesRef.set({"status": "on"});
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId added successfully!')));
        }
      } else {
        // Show error message if device does not exist
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device $deviceId does not exist.')));
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    await _auth.signOut();
  }

  void _showControlSheet(
      BuildContext context, String deviceId, String customName) {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      context: context,
      builder: (context) {
        final User? user = _auth.currentUser;
        return SizedBox(
          height: 470,
          child: StreamBuilder<DatabaseEvent>(
            stream: _databaseReference.child('devices/$deviceId').onValue,
            builder: (context, snapshot) {
              Widget child;

              // if (snapshot.connectionState == ConnectionState.waiting) {
              //   child = const Center(child: CircularProgressIndicator());
              // } else
              if (snapshot.hasError) {
                child = Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData ||
                  snapshot.data!.snapshot.value == null) {
                // child = const Center(child: Text('Không tìm thấy thiết bị'));
                child = const Center(child: CircularProgressIndicator());
              } else {
                final deviceData =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                child = Container(
                  decoration: const BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Color(0xFF515151), Color(0xFF7F7F7F)],
                    //   begin: Alignment.topLeft,
                    //   end: Alignment.bottomRight,
                    // ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25.0)),
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "Control - $customName",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (deviceId.startsWith('CongTac'))
                        Container(
                          // decoration: const BoxDecoration(
                          //   gradient: LinearGradient(
                          //     colors: [Color(0xFF515151), Color(0xFF7F7F7F)],
                          //     begin: Alignment.topLeft,
                          //     end: Alignment.bottomRight,
                          //   ),
                          //   borderRadius: BorderRadius.vertical(
                          //       top: Radius.circular(25.0)),
                          // ),
                          padding: const EdgeInsets.all(5.0),
                          child: GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2, // 2 items per row
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            children: [
                              // Lặp qua các công tắc để tạo từng ô điều khiển
                              ...List.generate(4, (index) {
                                final switchId = 'D${index + 1}';
                                final switchStatus =
                                    deviceData[switchId] == 'on';

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF7E60BF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          color: Colors.white), // Biểu tượng
                                      Text(
                                        'Switch $switchId',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                      Switch(
                                        activeColor: const Color.fromARGB(
                                            255, 21, 255, 0),
                                        inactiveThumbColor:
                                            const Color.fromARGB(
                                                255, 21, 255, 0),
                                        value: switchStatus,
                                        onChanged: (value) {
                                          _databaseReference
                                              .child('devices/$deviceId')
                                              .update({
                                            switchId: value ? 'on' : 'off'
                                          });
                                          _databaseReference
                                              .child(
                                                  'users/${user?.uid}/devices/$deviceId')
                                              .update({
                                            switchId: value ? 'on' : 'off'
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      if (deviceId.startsWith('CuaCuon'))
                        Column(
                          children: [
                            // Nút Up và Down
                            ...['Up', 'Down'].map((action) {
                              final actionStatus = deviceData[
                                      action.toString() == "Down"
                                          ? "down"
                                          : "up"] ==
                                  'on';
                              Timer? holdTimer;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    // Text(
                                    //   'Cửa Cuốn $action',
                                    //   style: const TextStyle(
                                    //       fontSize: 18,
                                    //       color: Color.fromARGB(255, 0, 0, 0)),
                                    // ),
                                    const SizedBox(
                                        height:
                                            8), // Space between text and button
                                    GestureDetector(
                                      onTapDown: (_) {
                                        // Start a timer to detect a 1-second hold
                                        holdTimer = Timer(
                                            const Duration(milliseconds: 20),
                                            () {
                                          _databaseReference
                                              .child('devices/$deviceId')
                                              .update({
                                            (action.toString() == "Down"
                                                ? "down"
                                                : "up"): 'on',
                                            "stop": "off"
                                          });
                                          _databaseReference
                                              .child(
                                                  'users/${user?.uid}/devices/$deviceId')
                                              .update({
                                            (action.toString() == "Down"
                                                ? "down"
                                                : "up"): 'on',
                                            "stop": "off"
                                          });
                                        });
                                      },
                                      onTapUp: (_) {
                                        // If the hold was less than 1 second, cancel the action
                                        holdTimer?.cancel();
                                        _databaseReference
                                            .child('devices/$deviceId')
                                            .update({
                                          (action.toString() == "Down"
                                              ? "down"
                                              : "up"): 'off',
                                          "stop": "off"
                                        });
                                        _databaseReference
                                            .child(
                                                'users/${user?.uid}/devices/$deviceId')
                                            .update({
                                          (action.toString() == "Down"
                                              ? "down"
                                              : "up"): 'off',
                                          "stop": "off"
                                        });
                                      },
                                      onTapCancel: () {
                                        // Clean up on tap cancel
                                        holdTimer?.cancel();
                                        _databaseReference
                                            .child('devices/$deviceId')
                                            .update({
                                          (action.toString() == "Down"
                                              ? "down"
                                              : "up"): 'off',
                                        });
                                        _databaseReference
                                            .child(
                                                'users/${user?.uid}/devices/$deviceId')
                                            .update({
                                          (action.toString() == "Down"
                                              ? "down"
                                              : "up"): 'off',
                                        });
                                      },
                                      child: Container(
                                        width: 180, // Set desired width
                                        height: 90, // Set desired height
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          color: actionStatus
                                              ? Colors.blue
                                              : Colors.grey,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          // Center text in the button
                                          child: Text(
                                            action,
                                            style: const TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255),
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Nút Dừng
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                children: [
                                  // Text(
                                  //   'Dừng',
                                  //   style: const TextStyle(
                                  //       fontSize: 18,
                                  //       color: Color.fromARGB(255, 0, 0, 0)),
                                  // ),
                                  const SizedBox(
                                      height:
                                          8), // Space between text and button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .center, // Center the button horizontally
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          // Khi nhấn nút, sẽ bật cửa cuốn
                                          _databaseReference
                                              .child('devices/$deviceId')
                                              .update({
                                            'up': 'off',
                                            'down': 'off',
                                            "stop": "on"
                                          });
                                          _databaseReference
                                              .child(
                                                  'users/${user?.uid}/devices/$deviceId')
                                              .update({
                                            'up': 'off',
                                            'down': 'off',
                                            "stop": "on"
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              (deviceData['stop'] == 'on')
                                                  ? Colors.red
                                                  : Colors.green,
                                          padding: const EdgeInsets.symmetric(
                                              vertical:
                                                  10), // Adjusted vertical padding
                                          minimumSize: Size(190,
                                              120), // Set minimum width and height
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Stop',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                    ],
                  ),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: child,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;

        return GestureDetector(
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) {
            setState(() => isPressed = false);
            onPressed();
          },
          onTapCancel: () => setState(() => isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isPressed ? color.withOpacity(0.7) : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              icon,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  void _showEditDialog(
      BuildContext context, String deviceId, String name, Color color) {
    final TextEditingController nameController =
        TextEditingController(text: name);
    final User? user = _auth.currentUser;
    Color selectedColor = color; // Màu hiện tại của thiết bị

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: selectedColor,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Edit device',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter custom name',
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildColorOption(Colors.blue, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.blue;
                        });
                      }),
                      _buildColorOption(Colors.red, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.red;
                        });
                      }),
                      _buildColorOption(Colors.green, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.green;
                        });
                      }),
                      _buildColorOption(Colors.orange, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.orange;
                        });
                      }),
                      _buildColorOption(Color(0xFF7E60BF), selectedColor, () {
                        setState(() {
                          selectedColor = Color(0xFF7E60BF);
                        });
                      }),
                      // Thêm các màu khác nếu cần
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && user != null) {
                      await _databaseReference
                          .child('users/${user.uid}/devices/$deviceId')
                          .update({
                        'customName': newName,
                        'color': selectedColor.value
                      });
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid name')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Hàm để tạo widget lựa chọn màu sắc
  Widget _buildColorOption(
      Color color, Color selectedColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == selectedColor ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Stream<DatabaseEvent> _getDevices() {
    final User? user = _auth.currentUser;
    return _databaseReference.child('users/${user?.uid}/devices').onValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tim',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _signOut();
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginPage()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            const Center(
              child: Text(
                'Smart Home',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E60BF),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    // cursorColor: Colors.red,
                    // cursorRadius: Radius.circular(16.0),
                    // cursorWidth: 16.0,
                    controller: deviceController,
                    decoration: InputDecoration(
                      labelText: 'Enter ID devices',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.grey,
                          width: 1.0,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.0,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2.0,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final deviceId = deviceController.text.trim();
                    if (deviceId.isNotEmpty) {
                      _addDevice(deviceId, context);
                      deviceController.clear();
                    }
                  },
                  child: Text(
                    'Add devices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFEF9F2),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 0, 154, 243),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Mở QrScanner và nhận kết quả
                    final qrResult = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QrScanner()),
                    );

                    if (qrResult != null) {
                      // Xử lý kết quả quét mã QR (ví dụ: thêm thiết bị)
                      String deviceId = qrResult as String;
                      _addDevice(deviceId, context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200], // Màu nền cho nút
                    padding: EdgeInsets.all(10.0), // Khoảng cách lề cho nút
                    shape: CircleBorder(), // Hình dạng tròn cho nút
                  ),
                  child: Icon(
                    Icons.qr_code,
                    size: 32.0, // Kích thước biểu tượng
                  ),
                )
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _getDevices(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final devicesMap =
                      snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                  if (devicesMap == null) {
                    return Center(child: Text('No devices'));
                  }

                  final deviceKeys = devicesMap.keys.toList();

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: deviceKeys.length,
                    itemBuilder: (context, index) {
                      final deviceId = deviceKeys[index];
                      final deviceData = devicesMap[deviceId];
                      final deviceStatus = deviceData['status'];
                      final customName = deviceData['customName'] ?? deviceId;
                      Color color = Color(deviceData['color'] ?? 0xFF7E60BF);
                      return GestureDetector(
                        onTap: () =>
                            _showControlSheet(context, deviceId, customName),
                        onLongPress: () => _showEditDialog(
                            context, deviceId, customName, color),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color:
                                    deviceStatus == 'on' ? color : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    (deviceId.startsWith('CongTac')
                                        ? Icons.room_preferences_outlined
                                        : Icons.door_sliding),
                                    size: 60,
                                    color: deviceStatus == 'on'
                                        ? Colors.white
                                        : Color(0xFFC4D7FF),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    customName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: deviceStatus == 'on'
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  // Xóa Positioned khỏi đây
                                ],
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon:
                                      Icon(Icons.close, color: Colors.red[300]),
                                  padding: EdgeInsets.zero, // Loại bỏ padding
                                  alignment: Alignment.center,
                                  onPressed: () =>
                                      _showDeleteConfirmationDialog(
                                    context,
                                    deviceId,
                                    customName,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
