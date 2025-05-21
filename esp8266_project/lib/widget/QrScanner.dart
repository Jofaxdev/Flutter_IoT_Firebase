import 'dart:async'; // Added for Future.delayed
import 'dart:io'; // Still used for Platform checks potentially, though mobile_scanner handles camera restarts better.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // New import

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  // final GlobalKey qrKey = GlobalKey(debugLabel: 'QR'); // Not needed for mobile_scanner
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false; // To prevent multiple scans at once
  // double _cutOutSize = 300; // mobile_scanner does not use QrScannerOverlayShape directly for cutOutSize animation in the same way.
  // The scan window is a visual guide. We can still implement visual effects if needed.

  late final FirebaseDatabase _database;
  late final FirebaseAuth _auth;

  @override
  void initState() {
    super.initState();
    _database = FirebaseDatabase.instance;
    _auth = FirebaseAuth.instance;
  }

  // reassemble is less critical with mobile_scanner for camera pausing/resuming,
  // but can be kept if other logic depends on it.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      // mobile_scanner handles this internally mostly, but if you face issues:
      // cameraController.stop();
      // cameraController.start();
    } else if (Platform.isIOS) {
      // cameraController.stop();
      // cameraController.start();
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return; // Don't process if already processing

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? deviceId = barcodes.first.rawValue;

      if (deviceId != null && deviceId.isNotEmpty) {
        setState(() {
          _isProcessing = true;
        });

        // Optional: Stop the camera to prevent further scans while processing
        // await cameraController.stop(); // uncomment if you want to stop scanning

        bool isValid = await _checkDeviceValidity(deviceId);

        if (mounted) {
          // Ensure widget is still in the tree
          if (isValid) {
            _addDevice(deviceId, context); // This will pop if successful
            Navigator.pop(context, deviceId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid QR code')),
            );
            // Optional: Restart camera if it was stopped and validation failed
            // await cameraController.start(); // uncomment if you stopped scanning
            setState(() {
              _isProcessing = false; // Allow scanning again
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Good practice to have an AppBar for navigation and context
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // Makes body go behind AppBar
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          MobileScanner(
            controller: cameraController,
            onDetect: _handleBarcode,
            // Fit the camera preview to the screen.
            // fit: BoxFit.cover, // You can experiment with this
            // You can define a scan window. The scanner will only detect QR codes
            // within this window. This also provides a visual cue to the user.
            scanWindow: Rect.fromCenter(
              center: MediaQuery.of(context).size.center(Offset.zero),
              width: 250, // Desired width of the scan window
              height: 250, // Desired height of the scan window
            ),
          ),
          // Custom overlay to draw a border around the scan window
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                scanWindow: Rect.fromCenter(
                  center: MediaQuery.of(context).size.center(Offset.zero),
                  width: 250,
                  height: 250,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            child: Container(
              // Wrap Text with a Container
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4), // Apply padding here
              decoration: BoxDecoration(
                // Apply background color here
                color: Colors.black54,
                borderRadius:
                    BorderRadius.circular(4), // Optional: for rounded corners
              ),
              child: const Text(
                'Add new devices using QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // _onQRViewCreated is replaced by onDetect in MobileScanner

  Future<bool> _checkDeviceValidity(String deviceId) async {
    debugPrint('Scanned device ID: $deviceId');
    return deviceId.startsWith("CongTac") ||
        deviceId.startsWith("CuaCuon") ||
        deviceId.startsWith("CamBienNhietDoAm");
  }

  Future<void> _addDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null && mounted) {
      // Check mounted again
      final DatabaseReference userDevicesRef =
          _database.ref('users/${user.uid}/devices/$deviceId');
      final DataSnapshot userDeviceSnapshot = await userDevicesRef.get();

      if (!mounted) return; // Check after await

      if (userDeviceSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device $deviceId already exists!')));
      } else {
        final DatabaseReference deviceExistsRef =
            _database.ref('devices/$deviceId');
        final DatabaseEvent deviceExistsSnapshot = await deviceExistsRef.once();

        if (!mounted) return; // Check after await

        if (deviceExistsSnapshot.snapshot.value != null) {
          await userDevicesRef.set({"status": "on"});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId added successfully!')));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Device $deviceId does not exist.')));
        }
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose(); // Dispose the MobileScannerController
    super.dispose();
  }
}

// Custom painter for the overlay
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  ScannerOverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Border width

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5); // Semi-transparent background

    // Draw the semi-transparent background
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(scanWindow),
      ),
      backgroundPaint,
    );

    // Draw the white border around the scan window
    canvas.drawRect(scanWindow, borderPaint);

    // Optional: Draw corner lines (like in QrScannerOverlayShape)
    const double cornerLength = 30;
    final Paint cornerPaint = Paint()
      ..color = Colors.white // Or Theme.of(context).primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6; // Thickness of corner lines

    // Top-left corner
    canvas.drawLine(scanWindow.topLeft + const Offset(0, 0),
        scanWindow.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanWindow.topLeft + const Offset(0, 0),
        scanWindow.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Top-right corner
    canvas.drawLine(scanWindow.topRight - const Offset(cornerLength, 0),
        scanWindow.topRight + const Offset(0, 0), cornerPaint);
    canvas.drawLine(scanWindow.topRight + const Offset(0, 0),
        scanWindow.topRight + const Offset(0, cornerLength), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(scanWindow.bottomLeft + const Offset(0, 0),
        scanWindow.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanWindow.bottomLeft - const Offset(0, cornerLength),
        scanWindow.bottomLeft + const Offset(0, 0), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(scanWindow.bottomRight - const Offset(cornerLength, 0),
        scanWindow.bottomRight + const Offset(0, 0), cornerPaint);
    canvas.drawLine(scanWindow.bottomRight - const Offset(0, cornerLength),
        scanWindow.bottomRight + const Offset(0, 0), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Can be optimized if scanWindow changes
  }
}
