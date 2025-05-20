import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  double _cutOutSize = 300; // Kích thước ban đầu của vùng quét

  late final FirebaseDatabase _database;
  late final FirebaseAuth _auth;

  @override
  void initState() {
    super.initState();
    _database = FirebaseDatabase.instance;
    _auth = FirebaseAuth.instance;
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: _cutOutSize,
            ),
          ),
          const Positioned(
            bottom: 80,
            child: Text(
              'Add new devices using QR code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
      });

      // Dừng quét sau khi nhận được kết quả
      await controller.pauseCamera();

      String deviceId = result!.code!;
      bool isValid = await _checkDeviceValidity(deviceId);

      if (isValid) {
        _addDevice(deviceId, context);
        Navigator.pop(context, deviceId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code')),
        );
        controller.resumeCamera();
      }

      // Sử dụng AnimatedContainer để tạo hiệu ứng mượt mà (800ms)
      await Future.delayed(
          const Duration(milliseconds: 100)); // Chờ 100ms trước khi zoom
      setState(() {
        _cutOutSize = 250; // Thu nhỏ vùng quét
      });

      // Đặt lại kích thước vùng quét sau khi xử lý xong (800ms)
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _cutOutSize = 300;
      });
    });
  }

  // Thay thế bằng hàm kiểm tra thiết bị của bạn
  Future<bool> _checkDeviceValidity(String deviceId) async {
    // Xuất ra debug console
    debugPrint('Scanned device ID: $deviceId');
    // Kiểm tra xem deviceId có bắt đầu bằng "CongTac", "CuaCuon" hoặc "CamBienNhietDoAm"
    return deviceId.startsWith("CongTac") ||
        deviceId.startsWith("CuaCuon") ||
        deviceId.startsWith("CamBienNhietDoAm"); // Thêm điều kiện mới
  }

  Future<void> _addDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      // Tham chiếu đến nút thiết bị của người dùng
      final DatabaseReference userDevicesRef =
          _database.ref('users/${user.uid}/devices/$deviceId');

      // Kiểm tra xem thiết bị đã tồn tại trong danh sách thiết bị của người dùng chưa
      final DataSnapshot userDeviceSnapshot = await userDevicesRef.get();

      if (userDeviceSnapshot.exists) {
        // Nếu thiết bị đã tồn tại, hiển thị thông báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device $deviceId already exists!')));
      } else {
        // Nếu thiết bị chưa tồn tại, kiểm tra xem nó có tồn tại trong nút devices chung không
        final DatabaseReference deviceExistsRef =
            _database.ref('devices/$deviceId');
        final DatabaseEvent deviceExistsSnapshot = await deviceExistsRef.once();

        if (deviceExistsSnapshot.snapshot.value != null) {
          // Nếu thiết bị tồn tại trong nút devices chung, thêm nó vào danh sách của người dùng
          await userDevicesRef.set({"status": "on"});
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId added successfully!')));
        } else {
          // Nếu thiết bị không tồn tại trong nút devices chung, hiển thị thông báo lỗi
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId does not exist.')));
        }
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
