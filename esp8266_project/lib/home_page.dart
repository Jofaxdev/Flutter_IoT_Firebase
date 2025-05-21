import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; // Thêm import này
import 'package:shimmer/shimmer.dart';

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

  HomePage({Key? key}) : super(key: key);

// Bên trong class HomePage

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String deviceId, String customName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // Người dùng có thể nhấn ra ngoài để đóng
      builder: (BuildContext dialogContext) {
        // Sử dụng một biến để quản lý trạng thái đang xóa, nếu muốn hiển thị loading indicator
        // bool _isDeleting = false; // Bỏ qua nếu không dùng loading indicator phức tạp trong dialog

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Xác nhận xóa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Bạn có chắc chắn muốn xóa vĩnh viễn thiết bị "$customName" khỏi danh sách của bạn không?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[700])),
              ],
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(
                'HỦY BỎ',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.delete_forever_rounded, size: 20),
              label: Text('XÓA', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                // Bước 1: Đóng dialog ngay lập tức
                Navigator.of(dialogContext).pop();

                // Bước 2: Thực hiện tác vụ xóa (không cần await ở đây nếu không muốn chặn UI sau khi dialog đóng)
                // _deleteDevice vẫn là async và sẽ chạy, SnackBar sẽ hiển thị khi nó hoàn thành.
                _deleteDevice(deviceId, context);

                // Không cần await _deleteDevice(deviceId, context); ở đây nữa
                // vì chúng ta muốn dialog đóng ngay.
                // SnackBar trong _deleteDevice sẽ thông báo kết quả.
              },
            ),
          ],
        );
      },
    );
  }

// Hàm _deleteDevice của bạn giữ nguyên như hiện tại
  Future<void> _deleteDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _databaseReference
            .child('users/${user.uid}/devices/$deviceId')
            .remove();
        // Đảm bảo context vẫn còn mounted trước khi hiển thị SnackBar
        // Vì context của dialog đã bị pop, context truyền vào đây là context của HomePage
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa thiết bị $deviceId')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa thiết bị: $e')),
          );
        }
      }
    }
  }

  Future<void> _addDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final DatabaseReference globalDeviceRef =
        _databaseReference.child('devices/$deviceId');
    final DatabaseEvent globalDeviceSnapshotEvent =
        await globalDeviceRef.once();

    if (globalDeviceSnapshotEvent.snapshot.value == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Device ID "$deviceId" không tồn tại trong hệ thống.')));
      }
      return;
    }

    final DatabaseReference userDeviceRef =
        _databaseReference.child('users/${user.uid}/devices/$deviceId');
    final DataSnapshot userDeviceSnapshot = await userDeviceRef.get();

    if (userDeviceSnapshot.exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Thiết bị $deviceId đã có trong danh sách của bạn.')));
      }
    } else {
      Map<String, dynamic> initialUserDataForDevice = {
        "status": "on",
        "customName": deviceId,
        "color": Theme.of(context).primaryColor.withAlpha(150).value
      };
      Map<String, dynamic> initialGlobalDataForDeviceUpdate = {};

      if (deviceId.startsWith('CamBienNhietDoAm')) {
        Map<String, dynamic> autoWateringStructure = {
          "enabled": false,
          "soilMoistureThreshold": 50,
          "pumpDurationWhenDry": 30,
          "scheduledWatering": {"enabled": false, "schedules": {}}
        };

        Map<dynamic, dynamic> currentGlobalDeviceData =
            globalDeviceSnapshotEvent.snapshot.value as Map<dynamic, dynamic>;

        if (currentGlobalDeviceData['autoWatering'] == null) {
          initialGlobalDataForDeviceUpdate['autoWatering'] =
              autoWateringStructure;
        } else {
          Map<dynamic, dynamic> currentAutoWateringData =
              currentGlobalDeviceData['autoWatering'] as Map<dynamic, dynamic>;
          if (currentAutoWateringData['pumpDurationWhenDry'] == null) {
            initialGlobalDataForDeviceUpdate[
                'autoWatering/pumpDurationWhenDry'] = 30;
          }
          if (currentAutoWateringData['enabled'] == null) {
            initialGlobalDataForDeviceUpdate['autoWatering/enabled'] = false;
          }
          if (currentAutoWateringData['soilMoistureThreshold'] == null) {
            initialGlobalDataForDeviceUpdate[
                'autoWatering/soilMoistureThreshold'] = 50;
          }
          if (currentAutoWateringData['scheduledWatering'] == null) {
            initialGlobalDataForDeviceUpdate['autoWatering/scheduledWatering'] =
                {"enabled": false, "schedules": {}};
          }
        }
      }

      await userDeviceRef.set(initialUserDataForDevice);

      if (initialGlobalDataForDeviceUpdate.isNotEmpty) {
        await globalDeviceRef.update(initialGlobalDataForDeviceUpdate);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Thiết bị $deviceId đã được thêm thành công!')));
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginPage()));
    }
  }

  void _showAddDeviceDialog(BuildContext context) {
    deviceController.clear();
    final formKey = GlobalKey<FormState>();

    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            titlePadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 10.0),
            actionsPadding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
            title: Row(
              children: [
                Icon(Icons.playlist_add_rounded,
                    color: Theme.of(context).primaryColor, size: 30),
                SizedBox(width: 12),
                Text('Thêm thiết bị',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Theme.of(context).textTheme.titleLarge?.color)),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Nhập mã định danh (ID) của thiết bị bạn muốn kết nối.",
                      style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: deviceController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'ID Thiết bị',
                      hintText: 'VD: CongTac_123',
                      prefixIcon: Icon(Icons.electrical_services_rounded,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.7)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2.0)),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey.shade50,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 16.0),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập ID thiết bị.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: <Widget>[
              TextButton(
                child: Text('HỦY',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                style: TextButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.add_link_rounded, size: 22),
                label: Text('KẾT NỐI',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  elevation: 3,
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final deviceId = deviceController.text.trim();
                    _addDevice(deviceId, context);
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          );
        });
  }

  void _scanQrCode(BuildContext context) async {
    final qrResult = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => QrScanner()));
    if (qrResult != null && qrResult is String) {
      _addDevice(qrResult, context);
    }
  }

  Widget _buildRelayControlTile(
      BuildContext context,
      String deviceId,
      User? user,
      DatabaseReference dbRef,
      String relayName,
      String relayKey,
      bool isActive,
      IconData iconData) {
    return Container();
  }

  void _showControlSheet(
      BuildContext context, String deviceId, String customName) {
    final User? currentUser = _auth.currentUser;
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
          ),
          child: _DeviceControlSheetContent(
            deviceId: deviceId,
            customName: customName,
            databaseReference: _databaseReference,
            currentUser: currentUser,
            buildRelayControlTileCallback: _buildRelayControlTile,
          ),
        );
      },
    );
  }

// Bên trong class HomePage

  void _showEditDialog(BuildContext context, String deviceId,
      String currentCustomName, Color currentColor) {
    final TextEditingController nameController =
        TextEditingController(text: currentCustomName);
    final User? user = _auth.currentUser;
    Color selectedColor = currentColor;
    final int maxNameLength = 20;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Đây là context của dialog
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Chỉnh sửa Thiết bị',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tên tùy chỉnh cho thiết bị:",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'Nhập tên tùy chỉnh (tối đa ${maxNameLength} ký tự)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        counterText:
                            "${nameController.text.length}/${maxNameLength}",
                      ),
                      maxLength: maxNameLength,
                      onChanged: (text) {
                        setStateDialog(() {});
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Chọn Màu:",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildColorOption(context, Colors.blue, selectedColor,
                            () {
                          setStateDialog(() {
                            selectedColor = Colors.blue;
                          });
                        }),
                        _buildColorOption(context, Colors.red, selectedColor,
                            () {
                          setStateDialog(() {
                            selectedColor = Colors.red;
                          });
                        }),
                        _buildColorOption(context, Colors.green, selectedColor,
                            () {
                          setStateDialog(() {
                            selectedColor = Colors.green;
                          });
                        }),
                        _buildColorOption(context, Colors.orange, selectedColor,
                            () {
                          setStateDialog(() {
                            selectedColor = Colors.orange;
                          });
                        }),
                        _buildColorOption(
                            context, Color(0xFF7E60BF), selectedColor, () {
                          setStateDialog(() {
                            selectedColor = Color(0xFF7E60BF);
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Hủy', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && user != null) {
                      if (newName.length > maxNameLength) {
                        // Kiểm tra mounted cho dialogContext trước khi hiển thị SnackBar từ bên trong nó
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                              content: Text(
                                  'Tên thiết bị quá dài (tối đa ${maxNameLength} ký tự).')));
                        }
                        return;
                      }

                      await _databaseReference
                          .child('users/${user.uid}/devices/$deviceId')
                          .update({
                        'customName': newName,
                        'color': selectedColor.value
                      });

                      // Sử dụng dialogContext.mounted để kiểm tra trước khi pop
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } else if (newName.isEmpty) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Tên thiết bị không được để trống.')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: Text('Lưu', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorOption(BuildContext context, Color color,
      Color selectedColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == selectedColor
                ? Theme.of(context).primaryColorDark
                : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: color == selectedColor
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 5,
                      spreadRadius: 1)
                ]
              : [],
        ),
      ),
    );
  }

  Stream<DatabaseEvent> _getDevices() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }
    return _databaseReference.child('users/${user.uid}/devices').onValue;
  }

  @override
  Widget build(BuildContext context) {
    // --- Định nghĩa màu xanh nước biển ---
    const Color oceanBlueDark =
        Color.fromARGB(255, 10, 139, 238); // Một màu xanh đậm
    const Color oceanBlueMedium =
        Color.fromARGB(255, 85, 200, 239); // Một màu xanh trung bình
    const Color oceanBlueLight =
        Color(0xFF48CAE4); // Một màu xanh sáng/xanh ngọc
    const Color appBarContentColor =
        Colors.white; // Màu cho chữ và icon trên AppBar

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors
            .transparent, // Luôn để transparent khi dùng flexibleSpace với gradient
        elevation: 0, // Bỏ đổ bóng mặc định
        scrolledUnderElevation: 3.0, // Đổ bóng nhẹ khi cuộn
        title: Text(
          'Tim',
          style: GoogleFonts.nunitoSans(
            // Font Nunito Sans khá hiện đại và dễ đọc
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: appBarContentColor,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: appBarContentColor),
        actionsIconTheme:
            const IconThemeData(color: appBarContentColor, size: 26),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25), // Độ bo góc có thể điều chỉnh
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                oceanBlueDark, // Bắt đầu từ màu đậm
                oceanBlueMedium, // Chuyển qua màu trung bình
                // oceanBlueLight, // Có thể thêm màu sáng ở cuối nếu muốn hiệu ứng rộng hơn
              ],
              begin: Alignment.topLeft, // Hướng gradient
              end: Alignment.bottomRight,
              // stops: [0.0, 0.6], // Điều chỉnh điểm dừng nếu cần
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(25), // Phải khớp với shape của AppBar
            ),
            boxShadow: [
              BoxShadow(
                color: oceanBlueDark.withOpacity(
                    0.3), // Bóng màu theo màu đậm nhất của gradient
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'add_id',
                child: ListTile(
                  leading: Icon(Icons.input_rounded),
                  title: Text('Thêm bằng ID'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'scan_qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner_rounded),
                  title: Text('Quét mã QR'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading:
                      Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  title: Text('Đăng xuất',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'add_id') {
                _showAddDeviceDialog(context);
              } else if (value == 'scan_qr') {
                _scanQrCode(context);
              } else if (value == 'logout') {
                _signOut(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        // ... (Phần body của bạn giữ nguyên) ...
        color: Theme.of(context).colorScheme.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                    child: Text('Bảng Điều Khiển Nhà Thông Minh',
                        style: GoogleFonts.robotoCondensed(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary))),
              ),
              Text('Thiết bị của bạn',
                  style: GoogleFonts.openSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleMedium?.color)),
              SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _getDevices(),
                  builder: (context, snapshot) {
                    // ... (Phần GridView của bạn giữ nguyên) ...
                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final devicesMap =
                        snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                    if (devicesMap == null || devicesMap.isEmpty) {
                      return Center(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices_other_rounded,
                              size: 80, color: Colors.grey[400]),
                          SizedBox(height: 20),
                          Text('Không có thiết bị nào được kết nối.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 17, color: Colors.grey[600])),
                          SizedBox(height: 10),
                          Text('Thêm thiết bị mới bằng menu ở góc trên.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500])),
                        ],
                      ));
                    }
                    final deviceKeys = devicesMap.keys.toList();

                    return GridView.builder(
                      padding: const EdgeInsets.only(
                          top: 8.0, bottom: 16.0), // Thêm padding cho GridView
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16),
                      itemCount: deviceKeys.length,
                      itemBuilder: (context, index) {
                        final deviceId = deviceKeys[index] as String;
                        final deviceData =
                            devicesMap[deviceId] as Map<dynamic, dynamic>;
                        final deviceStatus = deviceData['status'] as String?;
                        final customName =
                            deviceData['customName'] as String? ?? deviceId;

                        dynamic rawColor = deviceData['color'];
                        int intColorValue;
                        if (rawColor is int) {
                          intColorValue = rawColor;
                        } else if (rawColor is String &&
                            int.tryParse(rawColor) != null) {
                          intColorValue = int.tryParse(rawColor)!;
                        } else if (rawColor is double) {
                          intColorValue = rawColor.toInt();
                        } else {
                          intColorValue = Theme.of(context)
                              .primaryColor
                              .withAlpha(150)
                              .value;
                        }
                        Color color = Color(intColorValue);

                        IconData deviceIcon;
                        if (deviceId.startsWith('CongTac')) {
                          deviceIcon = Icons.lightbulb_outline_rounded;
                        } else if (deviceId.startsWith('CuaCuon')) {
                          deviceIcon = Icons.door_sliding_rounded;
                        } else if (deviceId.startsWith('CamBienNhietDoAm')) {
                          deviceIcon = Icons.thermostat_auto_rounded;
                        } else {
                          deviceIcon = Icons.developer_board_rounded;
                        }

                        bool isActive = deviceStatus == 'on';

                        return GestureDetector(
                          onTap: () =>
                              _showControlSheet(context, deviceId, customName),
                          onLongPress: () => _showEditDialog(
                              context, deviceId, customName, color),
                          child: Card(
                            elevation: isActive
                                ? 6.0
                                : 2.5, // Tăng nhẹ elevation khi active
                            shadowColor: isActive
                                ? color
                                    .withOpacity(0.5) // Bóng rõ hơn khi active
                                : Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    20.0)), // Bo góc lớn hơn một chút
                            color: isActive
                                ? color
                                : Theme.of(context).cardColor.withOpacity(
                                    0.85), // Nền mờ hơn khi inactive
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(
                                      12.0), // Tăng padding tổng thể cho Card
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment
                                        .center, // Căn giữa các phần tử chính
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isActive
                                            ? 12
                                            : 10), // Padding lớn hơn cho icon
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.white.withOpacity(
                                                  0.25) // Nền icon sáng hơn
                                              : color.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(deviceIcon,
                                            size: isActive
                                                ? 44
                                                : 40, // Icon lớn hơn
                                            color: isActive
                                                ? Colors.white
                                                : color.computeLuminance() > 0.5
                                                    ? Colors.black87
                                                    : Colors.white70
                                            // Đảm bảo icon luôn có màu tương phản tốt
                                            ),
                                      ),
                                      const SizedBox(
                                          height: 10), // Tăng khoảng cách
                                      Text(
                                        customName,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.openSans(
                                            // Sử dụng GoogleFonts
                                            fontSize:
                                                14.5, // Tên thiết bị lớn hơn một chút
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                            color: isActive
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.color),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isActive
                                            ? "Đang hoạt động"
                                            : "Ngoại tuyến", // Rõ ràng hơn
                                        style: GoogleFonts.mulish(
                                          // Font khác cho trạng thái
                                          fontSize:
                                              11, // Trạng thái nhỏ hơn một chút
                                          fontWeight: FontWeight.w500,
                                          color: isActive
                                              ? Colors.white.withOpacity(0.85)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0, // Đặt sát góc trên
                                  right: 0, // Đặt sát góc trên
                                  child: Material(
                                    // Thêm Material để InkWell có hiệu ứng ripple
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          _showDeleteConfirmationDialog(
                                              context, deviceId, customName),
                                      borderRadius: const BorderRadius.only(
                                          // Bo góc cho vùng chạm
                                          topRight: Radius.circular(
                                              20.0), // Khớp với bo góc Card
                                          bottomLeft: Radius.circular(
                                              12.0) // Bo góc chéo tạo điểm nhấn
                                          ),
                                      splashColor: Colors.red.withOpacity(0.3),
                                      highlightColor:
                                          Colors.red.withOpacity(0.1),
                                      child: Padding(
                                        // Tăng vùng chạm cho nút xóa
                                        padding: const EdgeInsets.all(
                                            8.0), // Padding lớn hơn
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: isActive
                                              ? Colors.white.withOpacity(0.8)
                                              : Colors.grey.shade700,
                                          size: 20, // Icon xóa lớn hơn
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
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
      ),
    );
  }
}

// End of Part 1
class _DeviceControlSheetContent extends StatefulWidget {
  final String deviceId;
  final String customName;
  final DatabaseReference databaseReference;
  final User? currentUser;
  final Widget Function(BuildContext, String, User?, DatabaseReference, String,
      String, bool, IconData) buildRelayControlTileCallback;

  const _DeviceControlSheetContent({
    Key? key,
    required this.deviceId,
    required this.customName,
    required this.databaseReference,
    required this.currentUser,
    required this.buildRelayControlTileCallback,
  }) : super(key: key);

  @override
  __DeviceControlSheetContentState createState() =>
      __DeviceControlSheetContentState();
}

class __DeviceControlSheetContentState
    extends State<_DeviceControlSheetContent> {
  Map<dynamic, dynamic>? _deviceData;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<DatabaseEvent>? _dataSubscription;
  TextEditingController? _soilMoistureThresholdController;
  TextEditingController? _autoPumpDurationController;
  double _sliderValue = 50.0;
  int _autoPumpDurationSeconds = 30;

  final List<Map<String, dynamic>> _sensorRelaysInfo = [
    {
      'key': 'relay1',
      'name': 'Đèn chiếu sáng',
      'icon': Icons.lightbulb_outline_rounded
    },
    {'key': 'relay2', 'name': 'Quạt thông gió', 'icon': FontAwesomeIcons.fan},
    {
      'key': 'relay3',
      'name': 'Máy phun sương',
      'icon': Icons.water_drop_outlined
    },
    {
      'key': 'water_pump',
      'name': 'Bơm tưới nước',
      'icon': Icons.water_outlined
    },
  ];

  @override
  void initState() {
    super.initState();
    _soilMoistureThresholdController =
        TextEditingController(text: _sliderValue.round().toString());
    _autoPumpDurationController =
        TextEditingController(text: _autoPumpDurationSeconds.toString());
    _listenToDeviceData();
  }

  void _listenToDeviceData() {
    if (widget.deviceId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Device ID is empty.";
        });
      }
      return;
    }
    _dataSubscription = widget.databaseReference
        .child('devices/${widget.deviceId}')
        .onValue
        .listen((DatabaseEvent event) {
      if (mounted) {
        setState(() {
          if (event.snapshot.value != null && event.snapshot.value is Map) {
            _deviceData =
                Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            if (widget.deviceId.startsWith('CamBienNhietDoAm')) {
              final autoWateringData =
                  _deviceData?['autoWatering'] as Map<dynamic, dynamic>? ?? {};

              dynamic rawThreshold = autoWateringData['soilMoistureThreshold'];
              int currentThresholdInt = 50;
              if (rawThreshold is int) {
                currentThresholdInt = rawThreshold;
              } else if (rawThreshold is double) {
                currentThresholdInt = rawThreshold.round();
              } else if (rawThreshold is String) {
                currentThresholdInt = int.tryParse(rawThreshold) ?? 50;
              }
              String currentThresholdString = currentThresholdInt.toString();
              double currentThresholdDouble = currentThresholdInt.toDouble();

              if (_soilMoistureThresholdController != null &&
                  _soilMoistureThresholdController!.text !=
                      currentThresholdString) {
                _soilMoistureThresholdController!.text = currentThresholdString;
              }
              if (_sliderValue != currentThresholdDouble) {
                _sliderValue = currentThresholdDouble;
              }

              dynamic rawPumpDuration = autoWateringData['pumpDurationWhenDry'];
              _autoPumpDurationSeconds = 30;
              if (rawPumpDuration is int) {
                _autoPumpDurationSeconds = rawPumpDuration;
              } else if (rawPumpDuration is String) {
                _autoPumpDurationSeconds = int.tryParse(rawPumpDuration) ?? 30;
              } else if (rawPumpDuration is double) {
                _autoPumpDurationSeconds = rawPumpDuration.toInt();
              }
              if (_autoPumpDurationController != null &&
                  _autoPumpDurationController!.text !=
                      _autoPumpDurationSeconds.toString()) {
                _autoPumpDurationController!.text =
                    _autoPumpDurationSeconds.toString();
              }
            }
          } else {
            _deviceData = null;
          }
          _isLoading = false;
          _error = _deviceData == null && !_isLoading
              ? "Không tìm thấy dữ liệu thiết bị."
              : null;
        });
      }
    }, onError: (Object o) {
      if (mounted) {
        setState(() {
          _error = "Lỗi tải dữ liệu: ${o.toString()}";
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _soilMoistureThresholdController?.dispose();
    _autoPumpDurationController?.dispose();
    super.dispose();
  }

  Widget _buildTitlePlaceholder(
      {bool isActuallyLoading = false, double fontSize = 22}) {
    // Actual height of Text("Điều khiển - Cây thủy sinh") with fontSize 22, bold is ~31.
    // Padding is EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0), so vertical is 28.
    // Total height for title part: 31 + 28 = 59.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          20.0, 16.0, 20.0, 12.0), // This makes the total height ~59px
      child: Container(
        // Wrapping with container to give it a fixed height for skeleton
        height: 31, // Matching approximate text height
        alignment: Alignment.center,
        child: isActuallyLoading
            ? _buildPlaceholderContainer(fontSize * 0.8,
                width: 200 + (widget.customName.length * 2.0),
                radius: 6,
                color: Colors.grey[300]!) // Placeholder text
            : Text(
                "Điều khiển - ${widget.customName}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ),
    );
  }

  Widget _buildPlaceholderContainer(double height,
      {double? width,
      Color? color, // Cho phép màu null để shimmer có tác dụng
      double radius = 18.0,
      EdgeInsetsGeometry? margin}) {
    Widget placeholder = Container(
      height: height,
      width: width ?? double.infinity,
      margin: margin,
      decoration: BoxDecoration(
          color: color ?? Colors.grey[300]!, // Màu nền cho shimmer
          borderRadius: BorderRadius.circular(radius)),
    );

    // Chỉ áp dụng Shimmer nếu không có màu cụ thể được truyền vào (mặc định cho skeleton)
    if (color == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: placeholder,
      );
    }
    return placeholder;
  }

  Widget _buildCongTacSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        key: ValueKey('CongTacSkeleton-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitlePlaceholder(isActuallyLoading: true, fontSize: 20),
          SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 1.1,
            children: List.generate(4, (index) {
              return Card(
                // Mimicking the actual Card structure
                elevation: 2.5,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlaceholderContainer(36,
                              width: 36,
                              radius: 18,
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.08)),
                          _buildPlaceholderContainer(20,
                              width: 45, radius: 10, color: Colors.grey[200]!),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlaceholderContainer(18,
                              width: 80, radius: 4, color: Colors.grey[200]!),
                          SizedBox(height: 4),
                          _buildPlaceholderContainer(14,
                              width: 60, radius: 4, color: Colors.grey[200]!),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

// Located in __DeviceControlSheetContentState within lib/home_page.dart

  Widget _buildCuaCuonSkeleton() {
    // Title placeholder font size should match the default of _buildTitlePlaceholder used in actual content
    double titlePlaceholderFontSize = 22;

    // Dimensions for "Up" and "Down" button placeholders
    // These match the `_buildCuaCuonButton`'s container
    double upDownButtonHeight = 75;
    // Width is calculated dynamically in _buildCuaCuonButton,
    // for skeleton we can use a similar proportion or a fixed sensible width.
    // Using MediaQuery here for width makes sense if actual buttons also scale with screen width.
    // The actual _buildCuaCuonButton uses `MediaQuery.of(context).size.width * 0.38;`
    double upDownButtonWidth = MediaQuery.of(context).size.width * 0.38;

    // Dimensions for "Stop" button placeholder (ElevatedButton.icon)
    // Actual button padding: EdgeInsets.symmetric(horizontal: 60, vertical: 22)
    // Actual icon size: 34
    // Estimated height: 34 (icon) + 22 (top pad) + 22 (bottom pad) = 78px
    double stopButtonPlaceholderHeight = 78;
    // Actual width is intrinsic. Let's use a representative fixed width for the skeleton.
    // (Icon + Label + Horizontal Padding). (e.g., 34 + ~60 + 120 = ~214)
    double stopButtonPlaceholderWidth = 220;

    return SingleChildScrollView(
      key: ValueKey(
          'CuaCuonSkeletonScrollContainer-${widget.deviceId}'), // Key for the scroll view
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 10.0), // Matches actual content's scroll view padding
      child: Column(
        key: ValueKey(
            'CuaCuonSkeletonColumn-${widget.deviceId}'), // Key for the inner column
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTitlePlaceholder(
              isActuallyLoading: true,
              fontSize: titlePlaceholderFontSize), // Matched actual title size
          const SizedBox(height: 25), // Matches actual content
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPlaceholderContainer(upDownButtonHeight,
                  width: upDownButtonWidth,
                  radius: 20, // Matches actual button's BorderRadius
                  color: Colors.grey[300]),
              const SizedBox(width: 16), // Matches actual content
              _buildPlaceholderContainer(upDownButtonHeight,
                  width: upDownButtonWidth,
                  radius: 20, // Matches actual button's BorderRadius
                  color: Colors.grey[300]),
            ],
          ),
          const SizedBox(height: 25), // Matches actual content
          _buildPlaceholderContainer(stopButtonPlaceholderHeight,
              width: stopButtonPlaceholderWidth,
              radius: 20, // Matches actual button's BorderRadius
              color: Colors.grey[300]),
          const SizedBox(
              height: 14), // Matches actual content (was 13, corrected to 14)
        ],
      ),
    );
  }
// Located in __DeviceControlSheetContentState within lib/home_page.dart

  Widget _buildCamBienNhietDoAmSkeleton() {
    double titleFontSize = 22;
    double sectionTitleFontSize = 19;
    double cardTitleFontSize = 18;
    double regularTextFontSize = 16;
    double smallTextFontSize = 11.5;
    double lineSpacing = 8;
    double cardInnerPaddingAll = 16.0;

    double sensorInfoLineHeight = regularTextFontSize * 1.5 + lineSpacing;
    double switchListTileHeight = 56.0;
    double textFormFieldHeight = 60.0;
    double sliderHeight = 48.0;
    double buttonHeight = 40.0;
    double relayItemCardHeight = 120;

    // Wrap the main Column with SingleChildScrollView
    return SingleChildScrollView(
      key: ValueKey(
          'CamBienNhietDoAmSkeletonScroll-${widget.deviceId}'), // Optional: Add a key to the scroll view
      padding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 8.0), // Matched actual content's scroll view padding
      child: Column(
        key: ValueKey('CamBienNhietDoAmSkeleton-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitlePlaceholder(
              isActuallyLoading: true, fontSize: titleFontSize),
          const SizedBox(height: 10),

          // Sensor Info Card Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            child: Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0)),
              child: Padding(
                padding: EdgeInsets.all(cardInnerPaddingAll),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlaceholderContainer(cardTitleFontSize * 1.2,
                        width: 150, radius: 4, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 200, radius: 3, color: Colors.grey[300]),
                    SizedBox(height: lineSpacing),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 220, radius: 3, color: Colors.grey[300]),
                    SizedBox(height: lineSpacing),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 180, radius: 3, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Relay Title Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildPlaceholderContainer(sectionTitleFontSize * 1.2,
                width: 130, radius: 4, color: Colors.grey[300]),
          ),
          const SizedBox(height: 15),

          // Relay GridView Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: List.generate(4, (index) {
                return Card(
                  elevation: 2.0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  color: Theme.of(context)
                      .cardColor, // Use cardColor for skeleton items
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaceholderContainer(36,
                                width: 36, radius: 18, color: Colors.grey[200]),
                            _buildPlaceholderContainer(20,
                                width: 45, radius: 10, color: Colors.grey[200]),
                          ],
                        ),
                        SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlaceholderContainer(15 * 1.2,
                                width: 80, radius: 3, color: Colors.grey[200]),
                            SizedBox(height: 3),
                            _buildPlaceholderContainer(smallTextFontSize * 1.2,
                                width: 60, radius: 3, color: Colors.grey[200]),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Use a SizedBox to represent the Divider's space, or a thin placeholder
          SizedBox(
              height:
                  30), // Approximation for Divider height (default is 16, but your content uses Divider(height:30))

          // Auto Watering Title Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildPlaceholderContainer(sectionTitleFontSize * 1.2,
                width: 150, radius: 4, color: Colors.grey[300]),
          ),
          SizedBox(height: 10),

          // Auto Watering Card Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4.0),
            child: Card(
              elevation: 2.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Approximating SwitchListTile
                    Row(children: [
                      Expanded(
                          child: _buildPlaceholderContainer(
                              regularTextFontSize * 1.2,
                              width: double.infinity,
                              radius: 4,
                              color: Colors.grey[300])),
                      SizedBox(width: 8),
                      _buildPlaceholderContainer(20,
                          width: 45, radius: 10, color: Colors.grey[300])
                    ]),
                    SizedBox(height: 16),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 200, radius: 3, color: Colors.grey[300]),
                    SizedBox(height: 8),
                    _buildPlaceholderContainer(sliderHeight - 28,
                        width: double.infinity,
                        radius: 4,
                        color: Colors.grey[300]), // Simplified slider
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildPlaceholderContainer(
                                textFormFieldHeight - 28,
                                radius: 6,
                                color: Colors.grey[300])),
                        SizedBox(width: 12),
                        Expanded(
                            child: _buildPlaceholderContainer(
                                textFormFieldHeight - 28,
                                radius: 6,
                                color: Colors.grey[300])),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
              height:
                  25), // Approximation for Divider height (default is 16, content uses Divider(height:25))

          // Scheduled Watering Title + Switch Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlaceholderContainer(cardTitleFontSize * 1.2,
                    width: 180, radius: 4, color: Colors.grey[300]),
                _buildPlaceholderContainer(20,
                    width: 45, radius: 10, color: Colors.grey[300]),
              ],
            ),
          ),
          SizedBox(height: 6.0),

          // Placeholder for one schedule item
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Card(
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0)),
              color: Theme.of(context).cardColor, // Use cardColor
              child: SizedBox(
                  height: 70,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPlaceholderContainer(18 * 1.2,
                            width: 100, radius: 3, color: Colors.grey[200]),
                        SizedBox(height: 4),
                        _buildPlaceholderContainer(13 * 1.2,
                            width: 150, radius: 3, color: Colors.grey[200]),
                      ],
                    ),
                  )),
            ),
          ),
          SizedBox(height: 6.0),

          // Add Schedule Button Placeholder
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildPlaceholderContainer(buttonHeight,
                  width: 150, radius: 12, color: Colors.grey[300]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCuaCuonButton(BuildContext context,
      {required String label,
      required IconData icon,
      required bool isActive,
      required VoidCallback onTapDown,
      required VoidCallback onTapUpOrCancel,
      Color? activeColor,
      Color? inactiveColor}) {
    Timer? holdTimer;
    Color currentBgColor = (isActive
        ? (activeColor ?? Theme.of(context).primaryColor)
        : (inactiveColor ?? Theme.of(context).colorScheme.surfaceVariant));
    Color currentFgColor = isActive
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    double buttonWidth = MediaQuery.of(context).size.width * 0.38;
    double buttonHeight = 75;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) {
          holdTimer = Timer(const Duration(milliseconds: 20), onTapDown);
        },
        onTapUp: (_) {
          holdTimer?.cancel();
          onTapUpOrCancel();
        },
        onTapCancel: () {
          holdTimer?.cancel();
          onTapUpOrCancel();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: buttonWidth,
          height: buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: currentBgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isActive ? 0.18 : 0.08),
                  blurRadius: isActive ? 7 : 4,
                  offset: Offset(0, isActive ? 4 : 2))
            ],
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      activeColor ?? Theme.of(context).primaryColor,
                      (activeColor ?? Theme.of(context).primaryColor)
                          .withOpacity(0.65)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: currentFgColor),
              SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: currentFgColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledWateringList(BuildContext context, Map schedulesData) {
    // ... (Previous _buildScheduledWateringList implementation) ...
    // This method should be fine as is, focusing on layout of its parent.
    // Ensure its internal card heights are reasonable.
    if (schedulesData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Center(
            child: Column(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 40, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text("Chưa có lịch tưới nào được thiết lập.",
                style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700])),
          ],
        )),
      );
    }
    List<Widget> scheduleWidgets = [];
    List<MapEntry<dynamic, dynamic>> sortedSchedules =
        schedulesData.entries.toList()
          ..sort((a, b) {
            final timeA = a.value['time'] as String?;
            final timeB = b.value['time'] as String?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return -1;
            if (timeB == null) return 1;
            return timeA.compareTo(timeB);
          });

    for (var entry in sortedSchedules) {
      final scheduleId = entry.key as String;
      final details = entry.value as Map<dynamic, dynamic>;
      final bool itemIsActive = details['isActive'] as bool? ?? true;
      final bool itemCheckSoil = details['checkSoilMoisture'] as bool? ?? false;

      scheduleWidgets.add(Card(
          elevation: itemIsActive ? 2.0 : 1.0,
          margin: EdgeInsets.symmetric(vertical: 7.0, horizontal: 4.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: itemIsActive
              ? Theme.of(context).cardColor
              : Theme.of(context).cardColor.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 8.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.alarm_on_rounded,
                        color: itemIsActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade500,
                        size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${details['time'] ?? 'N/A'}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: itemIsActive
                                      ? Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.color
                                      : Colors.grey.shade700)),
                          SizedBox(height: 2),
                          Text(
                              "Bơm: ${details['durationSeconds'] ?? '--'} giây.",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: itemIsActive
                                      ? Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.8)
                                      : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_calendar_outlined,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 20),
                          tooltip: "Sửa lịch",
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            _showAddEditScheduleDialog(context, widget.deviceId,
                                widget.databaseReference,
                                scheduleId: scheduleId, initialData: details);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever_outlined,
                              color: Colors.redAccent.shade100, size: 20),
                          tooltip: "Xóa lịch",
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text("Xác nhận xóa lịch"),
                                content: Text(
                                    "Bạn có chắc muốn xóa lịch tưới lúc ${details['time'] ?? ''}? Hành động này không thể hoàn tác."),
                                actions: [
                                  TextButton(
                                      child: Text("Hủy"),
                                      onPressed: () => Navigator.of(ctx).pop()),
                                  TextButton(
                                    child: Text("Xóa",
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      widget.databaseReference
                                          .child(
                                              'devices/${widget.deviceId}/autoWatering/scheduledWatering/schedules/$scheduleId')
                                          .remove();
                                      Navigator.of(ctx).pop();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.only(left: 0, right: -8),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text("Kích hoạt",
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        value: itemIsActive,
                        onChanged: (bool? value) {
                          if (value != null) {
                            widget.databaseReference
                                .child(
                                    'devices/${widget.deviceId}/autoWatering/scheduledWatering/schedules/$scheduleId')
                                .update({'isActive': value});
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.only(left: 0, right: 0),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text("Theo độ ẩm",
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        value: itemCheckSoil,
                        onChanged: (bool? value) {
                          if (value != null) {
                            widget.databaseReference
                                .child(
                                    'devices/${widget.deviceId}/autoWatering/scheduledWatering/schedules/$scheduleId')
                                .update({'checkSoilMoisture': value});
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )));
    }
    return Column(children: scheduleWidgets);
  }

  void _showAddEditScheduleDialog(
      BuildContext context, String deviceId, DatabaseReference dbRef,
      {String? scheduleId, Map<dynamic, dynamic>? initialData}) {
    // ... (Previous _showAddEditScheduleDialog implementation from Part 2 of the previous response) ...
    final formKey = GlobalKey<FormState>();
    TimeOfDay? selectedTime;
    String dialogTitle =
        scheduleId == null ? "Thêm Lịch Tưới Mới" : "Chỉnh Sửa Lịch Tưới";

    bool initialIsActive = true;
    bool initialCheckSoil = false;

    if (initialData != null) {
      if (initialData['time'] != null) {
        try {
          final parts = (initialData['time'] as String).split(':');
          selectedTime =
              TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (e) {
          selectedTime = TimeOfDay.now();
        }
      } else {
        selectedTime = TimeOfDay.now();
      }
      initialIsActive = initialData['isActive'] as bool? ?? true;
      initialCheckSoil = initialData['checkSoilMoisture'] as bool? ?? false;
    } else {
      selectedTime = TimeOfDay(hour: 6, minute: 0);
    }
    final TextEditingController durationSecondsController =
        TextEditingController(
            text: initialData?['durationSeconds']?.toString() ?? '30');

    bool currentIsActive = initialIsActive;
    bool currentCheckSoil = initialCheckSoil;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            title: Text(dialogTitle,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
            contentPadding: EdgeInsets.fromLTRB(20, 10, 20, 8),
            content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Chọn thời gian bắt đầu tưới:",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      SizedBox(height: 8),
                      InkWell(
                          onTap: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context)
                                        .colorScheme
                                        .copyWith(
                                          primary:
                                              Theme.of(context).primaryColor,
                                          onPrimary: Colors.white,
                                          surface: Theme.of(context)
                                              .dialogBackgroundColor,
                                          onSurface: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                        ),
                                    timePickerTheme: TimePickerThemeData(
                                      dialHandColor:
                                          Theme.of(context).primaryColorDark,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(context).primaryColorDark,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != selectedTime) {
                              setStateDialog(() {
                                selectedTime = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.access_time_filled_rounded,
                                    color: Theme.of(context).primaryColor,
                                    size: 22),
                                Text(
                                    selectedTime?.format(context) ??
                                        'Chưa chọn',
                                    style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w500)),
                                Icon(Icons.arrow_drop_down_circle_outlined,
                                    color: Colors.grey.shade700, size: 22),
                              ],
                            ),
                          )),
                      SizedBox(height: 18),
                      Text("Thời lượng bơm (tính bằng giây):",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: durationSecondsController,
                        decoration: InputDecoration(
                            hintText: "VD: 30",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 14.0, horizontal: 16.0),
                            prefixIcon: Icon(Icons.timer_outlined, size: 20)),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Không được để trống';
                          final n = int.tryParse(value);
                          if (n == null || n <= 0) return 'Phải là số dương';
                          if (n > 600) return 'Tối đa 600 giây (10 phút)';
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      CheckboxListTile(
                        title: Text("Kích hoạt lịch này",
                            style: TextStyle(
                                fontSize: 14.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        value: currentIsActive,
                        onChanged: (bool? value) {
                          if (value != null) {
                            setStateDialog(() {
                              currentIsActive = value;
                            });
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        dense: true,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      CheckboxListTile(
                        title: Text("Kiểm tra độ ẩm đất trước khi tưới",
                            style: TextStyle(
                                fontSize: 14.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        subtitle: Text(
                            "(Nếu đất còn ẩm > ngưỡng, hệ thống sẽ bỏ qua)",
                            style: TextStyle(
                                fontSize: 11.5, color: Colors.grey[600])),
                        value: currentCheckSoil,
                        onChanged: (bool? value) {
                          if (value != null) {
                            setStateDialog(() {
                              currentCheckSoil = value;
                            });
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        dense: true,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                )),
            actionsAlignment: MainAxisAlignment.end,
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                  style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                  child: Text("HỦY",
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.of(ctx).pop()),
              ElevatedButton.icon(
                icon: Icon(Icons.save_alt_rounded, size: 20),
                label: Text("LƯU LỊCH",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (formKey.currentState!.validate() &&
                      selectedTime != null) {
                    final duration = int.parse(durationSecondsController.text);
                    final Map<String, dynamic> newScheduleData = {
                      'time':
                          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                      'durationSeconds': duration,
                      'isActive': currentIsActive,
                      'checkSoilMoisture': currentCheckSoil,
                    };

                    String currentScheduleId = scheduleId ??
                        dbRef
                            .child(
                                'devices/$deviceId/autoWatering/scheduledWatering/schedules')
                            .push()
                            .key!;

                    dbRef
                        .child(
                            'devices/$deviceId/autoWatering/scheduledWatering/schedules/$currentScheduleId')
                        .set(newScheduleData);
                    Navigator.of(ctx).pop();
                  } else if (selectedTime == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Vui lòng chọn giờ tưới.")));
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      if (widget.deviceId.startsWith('CongTac')) {
        content = _buildCongTacSkeleton();
      } else if (widget.deviceId.startsWith('CuaCuon')) {
        content = _buildCuaCuonSkeleton();
      } else if (widget.deviceId.startsWith('CamBienNhietDoAm')) {
        content = _buildCamBienNhietDoAmSkeleton();
      } else {
        content = Column(
          key: ValueKey('GenericLoadingSkeleton-${widget.deviceId}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitlePlaceholder(isActuallyLoading: true),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: const Center(child: CircularProgressIndicator()),
            )
          ],
        );
      }
    } else if (_error != null) {
      content = Column(
        key: ValueKey('errorState-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildTitlePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
                child: Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 50),
                SizedBox(height: 15),
                Text('Đã xảy ra lỗi',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[700])),
              ],
            )),
          ),
        ],
      );
    } else if (_deviceData == null) {
      content = Column(
        key: ValueKey('noDataState-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildTitlePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
                child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    color: Colors.grey[400], size: 50),
                SizedBox(height: 15),
                Text('Không tìm thấy dữ liệu cho thiết bị này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              ],
            )),
          ),
        ],
      );
    } else {
      final deviceData = _deviceData!;
      final autoWateringData =
          _deviceData!['autoWatering'] as Map<dynamic, dynamic>? ?? {};

      if (widget.deviceId.startsWith('CongTac')) {
        content = SingleChildScrollView(
          key: ValueKey('CongTacScroll-${widget.deviceId}'),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            key: ValueKey('CongTac-${widget.deviceId}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitlePlaceholder(),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 1.1,
                children: List.generate(4, (index) {
                  final switchId = 'D${index + 1}';
                  final switchStatus = deviceData[switchId] == 'on';
                  return Card(
                    elevation: switchStatus ? 5 : 2.5,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    color: switchStatus
                        ? Theme.of(context).primaryColor.withOpacity(0.85)
                        : Theme.of(context).cardColor,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        bool newValue = !switchStatus;
                        widget.databaseReference
                            .child('devices/${widget.deviceId}')
                            .update({switchId: newValue ? 'on' : 'off'});
                        if (widget.currentUser != null) {
                          widget.databaseReference
                              .child(
                                  'users/${widget.currentUser!.uid}/devices/${widget.deviceId}')
                              .update({switchId: newValue ? 'on' : 'off'});
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: switchStatus
                                        ? Colors.white.withOpacity(0.25)
                                        : Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.power_rounded,
                                      size: 28,
                                      color: switchStatus
                                          ? Colors.white
                                          : Theme.of(context).primaryColor),
                                ),
                                Transform.scale(
                                    scale: 0.9,
                                    alignment: Alignment.topRight,
                                    child: Switch(
                                      value: switchStatus,
                                      onChanged: (value) {
                                        widget.databaseReference
                                            .child('devices/${widget.deviceId}')
                                            .update({
                                          switchId: value ? 'on' : 'off'
                                        });
                                      },
                                      activeColor: Colors.white,
                                      activeTrackColor:
                                          Colors.white.withOpacity(0.5),
                                      inactiveThumbColor: Colors.grey.shade400,
                                      inactiveTrackColor: Colors.grey.shade200,
                                    )),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Thiết bị ${index + 1}',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: switchStatus
                                            ? Colors.white
                                            : Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.color)),
                                SizedBox(height: 2),
                                Text(switchStatus ? "ĐANG BẬT" : "ĐANG TẮT",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                        color: switchStatus
                                            ? Colors.white.withOpacity(0.85)
                                            : Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 10),
            ],
          ),
        );
      } else if (widget.deviceId.startsWith('CuaCuon')) {
        final bool upStatus =
            deviceData['up'] == 'on' || deviceData['Up'] == 'on';
        final bool downStatus = deviceData['down'] == 'on';
        final bool stopStatus = deviceData['stop'] == 'on';

        content = SingleChildScrollView(
          key: ValueKey('CuaCuon-${widget.deviceId}'),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTitlePlaceholder(),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCuaCuonButton(context,
                      label: "Mở Lên",
                      icon: Icons.keyboard_double_arrow_up_rounded,
                      isActive: upStatus,
                      activeColor: Colors.tealAccent[700], onTapDown: () {
                    widget.databaseReference
                        .child('devices/${widget.deviceId}')
                        .update({'up': 'on', 'stop': 'off', 'down': 'off'});
                  }, onTapUpOrCancel: () {
                    widget.databaseReference
                        .child('devices/${widget.deviceId}')
                        .update({'up': 'off'});
                  }),
                  SizedBox(width: 16.0),
                  _buildCuaCuonButton(context,
                      label: "Đóng Xuống",
                      icon: Icons.keyboard_double_arrow_down_rounded,
                      isActive: downStatus,
                      activeColor: Colors.lightBlueAccent[700], onTapDown: () {
                    widget.databaseReference
                        .child('devices/${widget.deviceId}')
                        .update({'down': 'on', 'stop': 'off', 'up': 'off'});
                  }, onTapUpOrCancel: () {
                    widget.databaseReference
                        .child('devices/${widget.deviceId}')
                        .update({'down': 'off'});
                  }),
                ],
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                icon: Icon(Icons.stop_screen_share_rounded,
                    color: Colors.white, size: 34),
                label: Text("DỪNG",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      stopStatus ? Colors.red.shade600 : Colors.red.shade400,
                  padding: EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: stopStatus ? 5 : 10,
                ),
                onPressed: () {
                  widget.databaseReference
                      .child('devices/${widget.deviceId}')
                      .update({'up': 'off', 'down': 'off', 'stop': 'on'});
                },
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      } else if (widget.deviceId.startsWith('CamBienNhietDoAm')) {
        final bool autoWateringOverallEnabled =
            autoWateringData['enabled'] as bool? ?? false;
        final bool scheduledWateringOverallEnabled =
            autoWateringData['scheduledWatering']?['enabled'] as bool? ?? false;
        final Map<dynamic, dynamic> schedulesMap =
            autoWateringData['scheduledWatering']?['schedules']
                    as Map<dynamic, dynamic>? ??
                {};

        content = SingleChildScrollView(
          key: ValueKey('CamBien-${widget.deviceId}'),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitlePlaceholder(),
              const SizedBox(height: 10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                child: Card(
                  elevation: 2.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Thông số cảm biến",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.secondary)),
                          SizedBox(height: 12),
                          Row(children: [
                            Icon(FontAwesomeIcons.thermometerHalf,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Nhiệt độ: ${deviceData['temperature'] ?? '--'} °C",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)))
                          ]),
                          SizedBox(height: 8),
                          Row(children: [
                            Icon(FontAwesomeIcons.water,
                                color: Colors.blueAccent, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Độ ẩm không khí: ${deviceData['humidity'] ?? '--'} %",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)))
                          ]),
                          SizedBox(height: 8),
                          Row(children: [
                            Icon(FontAwesomeIcons.seedling,
                                color: Colors.green.shade600, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Độ ẩm đất: ${deviceData['soilMoisture'] ?? '--'} %",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)))
                          ]),
                        ]),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Điều khiển Relay",
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleMedium?.color)),
              ),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: _sensorRelaysInfo.map((relayInfo) {
                  final String relayKey = relayInfo['key'];
                  final String relayName = relayInfo['name'];
                  final IconData relayIcon = relayInfo['icon'];
                  bool switchStatus = false;
                  if (_deviceData != null && _deviceData![relayKey] != null) {
                    if (_deviceData![relayKey] is bool) {
                      switchStatus = _deviceData![relayKey] as bool;
                    } else if (_deviceData![relayKey] is String) {
                      switchStatus = _deviceData![relayKey] == 'on';
                    }
                  }

                  return Card(
                    elevation: switchStatus ? 6 : 3,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    color: switchStatus
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        bool newValue = !switchStatus;
                        widget.databaseReference
                            .child('devices/${widget.deviceId}')
                            .update({relayKey: newValue ? 'on' : 'off'});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: switchStatus
                                        ? Colors.white.withOpacity(0.2)
                                        : Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(relayIcon,
                                      size: 26,
                                      color: switchStatus
                                          ? Colors.white
                                          : Theme.of(context).primaryColorDark),
                                ),
                                Switch(
                                  value: switchStatus,
                                  onChanged: (value) {
                                    widget.databaseReference
                                        .child('devices/${widget.deviceId}')
                                        .update(
                                            {relayKey: value ? 'on' : 'off'});
                                  },
                                  activeColor: Colors.white,
                                  activeTrackColor:
                                      Colors.white.withOpacity(0.4),
                                  inactiveThumbColor: Colors.grey.shade400,
                                  inactiveTrackColor: Colors.grey.shade200,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(relayName,
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: switchStatus
                                            ? Colors.white
                                            : Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.color)),
                                SizedBox(height: 3),
                                Text(switchStatus ? "ĐANG BẬT" : "ĐANG TẮT",
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                        color: switchStatus
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Divider(
                  height: 30,
                  thickness: 1,
                  indent: 8,
                  endIndent: 8,
                  color: Colors.grey[300]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Tưới Tự Động",
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ),
              Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: Text("Kích hoạt chế độ tự động",
                              style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color)),
                          value: autoWateringOverallEnabled,
                          onChanged: (bool value) {
                            widget.databaseReference
                                .child(
                                    'devices/${widget.deviceId}/autoWatering')
                                .update({'enabled': value});
                          },
                          activeColor: Theme.of(context).primaryColor,
                          dense: false,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
                          secondary: Icon(Icons.eco_rounded,
                              color: autoWateringOverallEnabled
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey),
                        ),
                        if (autoWateringOverallEnabled) ...[
                          SizedBox(height: 16),
                          Text(
                              "Ngưỡng độ ẩm đất để tưới: ${_sliderValue.round()}%",
                              style: TextStyle(
                                  fontSize: 15.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          Slider(
                            value: _sliderValue,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: "${_sliderValue.round()}%",
                            activeColor: Theme.of(context).primaryColor,
                            inactiveColor:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            onChanged: (double value) {
                              setState(() {
                                _sliderValue = value;
                                _soilMoistureThresholdController?.text =
                                    value.round().toString();
                              });
                            },
                            onChangeEnd: (double value) {
                              int finalThreshold = value.round();
                              widget.databaseReference
                                  .child(
                                      'devices/${widget.deviceId}/autoWatering')
                                  .update({
                                'soilMoistureThreshold': finalThreshold
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _soilMoistureThresholdController,
                                  decoration: InputDecoration(
                                    labelText: "Ngưỡng ẩm",
                                    hintText: "0-100",
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    suffixText: "%",
                                  ),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  onChanged: (String value) {
                                    double? typedValue = double.tryParse(value);
                                    if (typedValue != null &&
                                        typedValue >= 0 &&
                                        typedValue <= 100) {
                                      if (_sliderValue.round() !=
                                          typedValue.round()) {
                                        setState(() {
                                          _sliderValue = typedValue;
                                        });
                                      }
                                    }
                                  },
                                  onFieldSubmitted: (String value) {
                                    int? threshold = int.tryParse(value);
                                    if (threshold != null &&
                                        threshold >= 0 &&
                                        threshold <= 100) {
                                      widget.databaseReference
                                          .child(
                                              'devices/${widget.deviceId}/autoWatering')
                                          .update({
                                        'soilMoistureThreshold': threshold
                                      });
                                      if (_sliderValue.round() != threshold) {
                                        setState(() {
                                          _sliderValue = threshold.toDouble();
                                        });
                                      }
                                    } else {
                                      _soilMoistureThresholdController?.text =
                                          _sliderValue.round().toString();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Ngưỡng ẩm không hợp lệ (0-100).")));
                                      }
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Nhập ngưỡng';
                                    }
                                    final n = int.tryParse(value);
                                    if (n == null || n < 0 || n > 100) {
                                      return '0-100';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _autoPumpDurationController,
                                  decoration: InputDecoration(
                                    labelText: "Bơm (giây)",
                                    hintText: "1-600",
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    suffixText: "giây",
                                  ),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  onFieldSubmitted: (String value) {
                                    int? duration = int.tryParse(value);
                                    if (duration != null &&
                                        duration > 0 &&
                                        duration <= 600) {
                                      widget.databaseReference
                                          .child(
                                              'devices/${widget.deviceId}/autoWatering')
                                          .update({
                                        'pumpDurationWhenDry': duration
                                      });
                                      setState(() {
                                        _autoPumpDurationSeconds = duration;
                                      });
                                    } else {
                                      _autoPumpDurationController?.text =
                                          _autoPumpDurationSeconds.toString();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Thời gian bơm không hợp lệ (1-600 giây).")));
                                      }
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Nhập thời gian';
                                    }
                                    final n = int.tryParse(value);
                                    if (n == null || n <= 0 || n > 600) {
                                      return '1-600';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )),
              if (autoWateringOverallEnabled) ...[
                Divider(
                    height: 25,
                    thickness: 1,
                    indent: 8,
                    endIndent: 8,
                    color: Colors.grey[300]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Tưới Theo Lịch Trình",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color)),
                      Switch(
                        value: scheduledWateringOverallEnabled,
                        onChanged: (bool value) {
                          widget.databaseReference
                              .child(
                                  'devices/${widget.deviceId}/autoWatering/scheduledWatering')
                              .update({'enabled': value});
                        },
                        activeColor: Theme.of(context).primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                if (scheduledWateringOverallEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4.0, vertical: 6.0),
                    child: _buildScheduledWateringList(context, schedulesMap),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 8.0, top: 6.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.15),
                            foregroundColor: Theme.of(context).primaryColorDark,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: Icon(Icons.add_alarm_rounded, size: 20),
                        label: Text("Thêm Lịch Tưới",
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w500)),
                        onPressed: () {
                          _showAddEditScheduleDialog(context, widget.deviceId,
                              widget.databaseReference);
                        },
                      ),
                    ),
                  ),
                ],
              ],
              SizedBox(height: 10),
            ],
          ),
        );
      } else {
        content = Center(
            key: ValueKey('Unknown-${widget.deviceId}'),
            child: const Text('Loại thiết bị không xác định.'));
      }
    }
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 10.0,
          left: 8.0,
          right: 8.0,
          top: 8.0),
      child: content,
    );
  }
}
// End of Part 2