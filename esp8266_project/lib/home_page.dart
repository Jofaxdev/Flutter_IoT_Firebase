import 'dart:async';
import 'dart:math'; // Thêm import này để tạo ID ngẫu nhiên
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'package:esp8266_project/login_pages.dart';
import 'package:esp8266_project/widget/QrScanner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Hàm tạo ID ngẫu nhiên ngắn
String _generateShortId() {
  const String chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  Random rnd = Random();
  return String.fromCharCodes(
      Iterable.generate(3, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}

class HomePage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController deviceController = TextEditingController();
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  final GoogleSignIn googleSignIn = GoogleSignIn();

  HomePage({Key? key}) : super(key: key);

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String deviceId, String customName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
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
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text('XÓA',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteDevice(deviceId, context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDevice(String deviceId, BuildContext context) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _databaseReference
            .child('users/${user.uid}/devices/$deviceId')
            .remove();
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
        Map<String, dynamic> defaultMoistureBased = {
          "en": 0,
          "d": 30,
          "th": 50
        };
        Map<String, dynamic> defaultScheduled = {"en": 0, "sc": []};

        Map<dynamic, dynamic> currentGlobalDeviceData =
            globalDeviceSnapshotEvent.snapshot.value
                    as Map<dynamic, dynamic>? ??
                {};

        if (currentGlobalDeviceData['t'] == null) {
          initialGlobalDataForDeviceUpdate['t'] = 0.0;
        }
        if (currentGlobalDeviceData['hm'] == null) {
          initialGlobalDataForDeviceUpdate['hm'] = 0;
        }
        if (currentGlobalDeviceData['sm'] == null) {
          initialGlobalDataForDeviceUpdate['sm'] = 0;
        }
        if (currentGlobalDeviceData['r1'] == null) {
          initialGlobalDataForDeviceUpdate['r1'] = 0;
        }
        if (currentGlobalDeviceData['r2'] == null) {
          initialGlobalDataForDeviceUpdate['r2'] = 0;
        }
        if (currentGlobalDeviceData['r3'] == null) {
          initialGlobalDataForDeviceUpdate['r3'] = 0;
        }
        if (currentGlobalDeviceData['wp'] == null) {
          initialGlobalDataForDeviceUpdate['wp'] = 0;
        }

        if (currentGlobalDeviceData['mbw'] == null) {
          initialGlobalDataForDeviceUpdate['mbw'] = defaultMoistureBased;
        } else {
          Map<dynamic, dynamic> currentMoistureData =
              currentGlobalDeviceData['mbw'] as Map<dynamic, dynamic>? ?? {};
          if (currentMoistureData['en'] == null) {
            initialGlobalDataForDeviceUpdate['mbw/en'] = 0;
          }
          if (currentMoistureData['d'] == null) {
            initialGlobalDataForDeviceUpdate['mbw/d'] = 30;
          }
          if (currentMoistureData['th'] == null) {
            initialGlobalDataForDeviceUpdate['mbw/th'] = 50;
          }
        }

        if (currentGlobalDeviceData['sw'] == null) {
          initialGlobalDataForDeviceUpdate['sw'] = defaultScheduled;
        } else {
          Map<dynamic, dynamic> currentScheduledData =
              currentGlobalDeviceData['sw'] as Map<dynamic, dynamic>? ?? {};
          if (currentScheduledData['en'] == null) {
            initialGlobalDataForDeviceUpdate['sw/en'] = 0;
          }
          if (currentScheduledData['sc'] == null) {
            initialGlobalDataForDeviceUpdate['sw/sc'] = [];
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
          MaterialPageRoute(builder: (context) => const LoginPage()));
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
                const SizedBox(width: 12),
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
                  const SizedBox(height: 24),
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
                      contentPadding: const EdgeInsets.symmetric(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_link_rounded, size: 22),
                label: const Text('KẾT NỐI',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
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
        context, MaterialPageRoute(builder: (context) => const QrScanner()));
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
    bool
        isActiveOldStructure, // For old structure like CongTac (e.g., 'D1' status)
    int relayStatusNewStructure, // For new structure (0 or 1) like CamBien relays (e.g., 'r1' status)
    IconData iconData, {
    bool isManuallyDisabledByAutomation = false,
  }) {
    bool currentStatusIsOn;
    String firebaseRelayKeyToUpdate;
    VoidCallback? onTapAction;

    bool isCamBienDevice = deviceId.startsWith("CamBienNhietDoAm");

    if (isCamBienDevice) {
      currentStatusIsOn = relayStatusNewStructure == 1;
      firebaseRelayKeyToUpdate = relayKey; // 'r1', 'r2', 'r3', 'wp'
    } else {
      currentStatusIsOn = isActiveOldStructure;
      firebaseRelayKeyToUpdate = relayKey; // 'D1', 'D2', etc.
    }

    // This variable determines if THIS SPECIFIC TILE (the pump) should be programmatically disabled.
    bool thisRelayIsProgrammaticallyDisabled =
        isCamBienDevice && relayKey == 'wp' && isManuallyDisabledByAutomation;

    // Determine the card color based on its on/off state, regardless of automation lock for visual consistency.
    Color cardColor = currentStatusIsOn
        ? Theme.of(context).primaryColor // Color when 'ON'
        : Theme.of(context).cardColor; // Default card color when 'OFF'

    // Icon color depends on the relay's actual on/off state
    Color iconColor =
        currentStatusIsOn ? Colors.white : Theme.of(context).primaryColorDark;

    // Text color for relay name also depends on actual on/off state
    Color relayNameTextColor = currentStatusIsOn
        ? Colors.white
        : Theme.of(context).textTheme.titleMedium?.color ?? Colors.black;

    // Text color for status text ("ĐANG BẬT"/"ĐANG TẮT")
    Color statusTextColor = currentStatusIsOn
        ? Colors.white.withOpacity(0.9)
        : Colors.grey.shade500;

    if (thisRelayIsProgrammaticallyDisabled) {
      onTapAction = () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Bơm Chính tạm khóa khi chế độ tưới tự động đang hoạt động.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 3),
          ),
        );
      };
    } else {
      onTapAction = () {
        dynamic newValue;
        if (isCamBienDevice) {
          newValue = currentStatusIsOn ? 0 : 1;
        } else {
          newValue = currentStatusIsOn ? 'off' : 'on';
        }
        dbRef
            .child('devices/$deviceId/$firebaseRelayKeyToUpdate')
            .set(newValue);
      };
    }

    Widget relayCardContent = Card(
      elevation: currentStatusIsOn ? 6 : 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap:
            onTapAction, // onTapAction handles the disabled state (shows SnackBar) or toggles
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: currentStatusIsOn
                          ? Colors.white.withOpacity(0.2)
                          : Theme.of(context).primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, size: 26, color: iconColor),
                  ),
                  // Switch is always visible but might be non-interactive due to InkWell's onTap
                  Switch(
                    value: currentStatusIsOn,
                    onChanged: thisRelayIsProgrammaticallyDisabled
                        ? null
                        : (value) {
                            // Disable switch interaction if programmatically locked
                            if (onTapAction != null) onTapAction();
                          },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.4),
                    // inactiveThumbColor:
                    //     Colors.grey.shade400, // Darker thumb when disabled
                    // inactiveTrackColor:
                    //     Colors.grey.shade200, // Darker track when disabled
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                ],
              ),
              const SizedBox(height: 8),
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
                          color: relayNameTextColor)),
                  const SizedBox(height: 3),
                  Text(currentStatusIsOn ? "ĐANG BẬT" : "ĐANG TẮT",
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: statusTextColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (thisRelayIsProgrammaticallyDisabled) {
      return Opacity(opacity: 0.7, child: relayCardContent);
    } else {
      return relayCardContent;
    }
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

  void _showEditDialog(BuildContext context, String deviceId,
      String currentCustomName, Color currentColor) {
    final TextEditingController nameController =
        TextEditingController(text: currentCustomName);
    final User? user = _auth.currentUser;
    Color selectedColor = currentColor;
    const int maxNameLength = 20;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                  const SizedBox(width: 10),
                  const Text(
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'Nhập tên tùy chỉnh (tối đa $maxNameLength ký tự)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        counterText:
                            "${nameController.text.length}/$maxNameLength",
                      ),
                      maxLength: maxNameLength,
                      onChanged: (text) {
                        setStateDialog(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Chọn Màu:",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
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
                            context, const Color(0xFF7E60BF), selectedColor,
                            () {
                          setStateDialog(() {
                            selectedColor = const Color(0xFF7E60BF);
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
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Tên thiết bị quá dài (tối đa $maxNameLength ký tự).')));
                        }
                        return;
                      }

                      await _databaseReference
                          .child('users/${user.uid}/devices/$deviceId')
                          .update({
                        'customName': newName,
                        'color': selectedColor.value
                      });

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } else if (newName.isEmpty) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Tên thiết bị không được để trống.')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child:
                      const Text('Lưu', style: TextStyle(color: Colors.white)),
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
    const Color oceanBlueDark = Color.fromARGB(255, 10, 139, 238);
    const Color oceanBlueMedium = Color.fromARGB(255, 85, 200, 239);
    const Color appBarContentColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 3.0,
        title: Text(
          'Tim',
          style: GoogleFonts.nunitoSans(
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
            bottom: Radius.circular(25),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                oceanBlueDark,
                oceanBlueMedium,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: oceanBlueDark.withOpacity(0.3),
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
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _getDevices(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
                          const SizedBox(height: 20),
                          Text('Không có thiết bị nào được kết nối.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 17, color: Colors.grey[600])),
                          const SizedBox(height: 10),
                          Text('Thêm thiết bị mới bằng menu ở góc trên.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500])),
                        ],
                      ));
                    }
                    final deviceKeys = devicesMap.keys.toList();

                    return GridView.builder(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16),
                      itemCount: deviceKeys.length,
                      itemBuilder: (context, index) {
                        final deviceId = deviceKeys[index] as String;
                        final deviceData =
                            devicesMap[deviceId] as Map<dynamic, dynamic>;
                        final userDeviceListStatus =
                            deviceData['status'] as String? ?? "off";

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

                        bool isActiveInUserList = userDeviceListStatus == 'on';

                        return GestureDetector(
                          onTap: () =>
                              _showControlSheet(context, deviceId, customName),
                          onLongPress: () => _showEditDialog(
                              context, deviceId, customName, color),
                          child: Card(
                            elevation: isActiveInUserList ? 6.0 : 2.5,
                            shadowColor: isActiveInUserList
                                ? color.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0)),
                            color: isActiveInUserList
                                ? color
                                : Theme.of(context).cardColor.withOpacity(0.85),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                            isActiveInUserList ? 12 : 10),
                                        decoration: BoxDecoration(
                                          color: isActiveInUserList
                                              ? Colors.white.withOpacity(0.25)
                                              : color.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(deviceIcon,
                                            size: isActiveInUserList ? 44 : 40,
                                            color: isActiveInUserList
                                                ? Colors.white
                                                : color.computeLuminance() > 0.5
                                                    ? Colors.black87
                                                    : Colors.white70),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        customName,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.openSans(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                            color: isActiveInUserList
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.color),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isActiveInUserList
                                            ? "Đang hoạt động"
                                            : "Ngoại tuyến",
                                        style: GoogleFonts.mulish(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isActiveInUserList
                                              ? Colors.white.withOpacity(0.85)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          _showDeleteConfirmationDialog(
                                              context, deviceId, customName),
                                      borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(20.0),
                                          bottomLeft: Radius.circular(12.0)),
                                      splashColor: Colors.red.withOpacity(0.3),
                                      highlightColor:
                                          Colors.red.withOpacity(0.1),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: isActiveInUserList
                                              ? Colors.white.withOpacity(0.8)
                                              : Colors.grey.shade700,
                                          size: 20,
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

class _DeviceControlSheetContent extends StatefulWidget {
  final String deviceId;
  final String customName;
  final DatabaseReference databaseReference;
  final User? currentUser;
  final Widget Function(
      BuildContext context,
      String deviceId,
      User? user,
      DatabaseReference dbRef,
      String relayName,
      String relayKey,
      bool isActiveOldStructure,
      int relayStatusNewStructure,
      IconData iconData,
      {bool isManuallyDisabledByAutomation}) buildRelayControlTileCallback;

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

  TextEditingController? _moistureThresholdController;
  TextEditingController? _moisturePumpDurationController;
  double _moistureSliderValue = 50.0;
  bool _moistureBasedEnabled = false;
  bool _scheduledWateringEnabled = false;
  bool _isPumpManuallyDisabledByAutomation = false;

  final List<Map<String, dynamic>> _sensorRelaysInfo = [
    {'key': 'r1', 'name': 'Đèn', 'icon': Icons.lightbulb_outline_rounded},
    {'key': 'r2', 'name': 'Quạt', 'icon': FontAwesomeIcons.fan},
    {'key': 'r3', 'name': 'Phun Sương', 'icon': Icons.water_drop_outlined},
    {'key': 'wp', 'name': 'Bơm Chính', 'icon': Icons.water_outlined},
  ];

  @override
  void initState() {
    super.initState();
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
              final moistureData =
                  _deviceData?['mbw'] as Map<dynamic, dynamic>? ?? {};
              _moistureBasedEnabled = (moistureData['en'] as int? ?? 0) == 1;

              dynamic rawMoistureThreshold = moistureData['th'];
              int currentMoistureThresholdInt = 50;
              if (rawMoistureThreshold is int) {
                currentMoistureThresholdInt = rawMoistureThreshold;
              } else if (rawMoistureThreshold is double) {
                currentMoistureThresholdInt = rawMoistureThreshold.round();
              } else if (rawMoistureThreshold is String) {
                currentMoistureThresholdInt =
                    int.tryParse(rawMoistureThreshold) ?? 50;
              }
              _moistureSliderValue = currentMoistureThresholdInt.toDouble();
              _moistureThresholdController ??= TextEditingController();
              if (_moistureThresholdController!.text !=
                  currentMoistureThresholdInt.toString()) {
                _moistureThresholdController!.text =
                    currentMoistureThresholdInt.toString();
              }

              dynamic rawMoisturePumpDuration = moistureData['d'];
              int currentMoisturePumpDuration = 30;
              if (rawMoisturePumpDuration is int) {
                currentMoisturePumpDuration = rawMoisturePumpDuration;
              } else if (rawMoisturePumpDuration is String) {
                currentMoisturePumpDuration =
                    int.tryParse(rawMoisturePumpDuration) ?? 30;
              } else if (rawMoisturePumpDuration is double) {
                currentMoisturePumpDuration = rawMoisturePumpDuration.toInt();
              }
              _moisturePumpDurationController ??= TextEditingController();
              if (_moisturePumpDurationController!.text !=
                  currentMoisturePumpDuration.toString()) {
                _moisturePumpDurationController!.text =
                    currentMoisturePumpDuration.toString();
              }

              final scheduledData =
                  _deviceData?['sw'] as Map<dynamic, dynamic>? ?? {};
              _scheduledWateringEnabled =
                  (scheduledData['en'] as int? ?? 0) == 1;

              _isPumpManuallyDisabledByAutomation =
                  _moistureBasedEnabled || _scheduledWateringEnabled;
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
    _moistureThresholdController?.dispose();
    _moisturePumpDurationController?.dispose();
    super.dispose();
  }

  Widget _buildTitlePlaceholder(
      {bool isActuallyLoading = false, double fontSize = 22}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
      child: Container(
        height: 31,
        alignment: Alignment.center,
        child: isActuallyLoading
            ? _buildPlaceholderContainer(fontSize * 0.8,
                width: 200 + (widget.customName.length * 2.0),
                radius: 6,
                color: Colors.grey[300]!)
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
      Color? color,
      double radius = 18.0,
      EdgeInsetsGeometry? margin}) {
    Widget placeholder = Container(
      height: height,
      width: width ?? double.infinity,
      margin: margin,
      decoration: BoxDecoration(
          color: color ?? Colors.grey[300]!,
          borderRadius: BorderRadius.circular(radius)),
    );

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
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 1.1,
            children: List.generate(4, (index) {
              return Card(
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
                          const SizedBox(height: 4),
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCuaCuonSkeleton() {
    double titlePlaceholderFontSize = 22;
    double upDownButtonHeight = 75;
    double upDownButtonWidth = MediaQuery.of(context).size.width * 0.38;
    double stopButtonPlaceholderHeight = 78;
    double stopButtonPlaceholderWidth = 220;

    return SingleChildScrollView(
      key: ValueKey('CuaCuonSkeletonScrollContainer-${widget.deviceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        key: ValueKey('CuaCuonSkeletonColumn-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTitlePlaceholder(
              isActuallyLoading: true, fontSize: titlePlaceholderFontSize),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPlaceholderContainer(upDownButtonHeight,
                  width: upDownButtonWidth,
                  radius: 20,
                  color: Colors.grey[300]),
              const SizedBox(width: 16),
              _buildPlaceholderContainer(upDownButtonHeight,
                  width: upDownButtonWidth,
                  radius: 20,
                  color: Colors.grey[300]),
            ],
          ),
          const SizedBox(height: 25),
          _buildPlaceholderContainer(stopButtonPlaceholderHeight,
              width: stopButtonPlaceholderWidth,
              radius: 20,
              color: Colors.grey[300]),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildCamBienNhietDoAmSkeleton() {
    double titleFontSize = 22;
    double sectionTitleFontSize = 19;
    double cardTitleFontSize = 18;
    double regularTextFontSize = 16;
    double cardInnerPaddingAll = 16.0;

    return SingleChildScrollView(
      key: ValueKey('CamBienNhietDoAmSkeletonScroll-${widget.deviceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        key: ValueKey('CamBienNhietDoAmSkeleton-${widget.deviceId}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitlePlaceholder(
              isActuallyLoading: true, fontSize: titleFontSize),
          const SizedBox(height: 10),
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
                    const SizedBox(height: 12),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 200, radius: 3, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 220, radius: 3, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 180, radius: 3, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildPlaceholderContainer(sectionTitleFontSize * 1.2,
                width: 180, radius: 4, color: Colors.grey[300]),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: List.generate(
                  4,
                  (index) => Card(
                        elevation: 2.0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        color: Theme.of(context).cardColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPlaceholderContainer(36,
                                      width: 36,
                                      radius: 18,
                                      color: Colors.grey[200]),
                                  _buildPlaceholderContainer(20,
                                      width: 45,
                                      radius: 10,
                                      color: Colors.grey[200]),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPlaceholderContainer(15 * 1.2,
                                      width: 80,
                                      radius: 3,
                                      color: Colors.grey[200]),
                                  const SizedBox(height: 3),
                                  _buildPlaceholderContainer(11.5 * 1.2,
                                      width: 60,
                                      radius: 3,
                                      color: Colors.grey[200]),
                                ],
                              )
                            ],
                          ),
                        ),
                      )),
            ),
          ),
          Divider(
              height: 30,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildPlaceholderContainer(sectionTitleFontSize * 1.2,
                width: 200, radius: 4, color: Colors.grey[300]),
          ),
          const SizedBox(height: 10),
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
                    Row(children: [
                      Expanded(
                          child: _buildPlaceholderContainer(
                              regularTextFontSize * 1.2,
                              width: double.infinity,
                              radius: 4,
                              color: Colors.grey[300])),
                      const SizedBox(width: 8),
                      _buildPlaceholderContainer(20,
                          width: 45, radius: 10, color: Colors.grey[300])
                    ]),
                    const SizedBox(height: 16),
                    _buildPlaceholderContainer(regularTextFontSize * 1.2,
                        width: 200, radius: 3, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    _buildPlaceholderContainer(48.0 - 28,
                        width: double.infinity,
                        radius: 4,
                        color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _buildPlaceholderContainer(60.0 - 28,
                              radius: 6, color: Colors.grey[300])),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildPlaceholderContainer(60.0 - 28,
                              radius: 6, color: Colors.grey[300]))
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Divider(
              height: 30,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: Colors.grey[300]),
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
          const SizedBox(height: 6.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Card(
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0)),
              color: Theme.of(context).cardColor,
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
                        const SizedBox(height: 4),
                        _buildPlaceholderContainer(13 * 1.2,
                            width: 150, radius: 3, color: Colors.grey[200]),
                      ],
                    ),
                  )),
            ),
          ),
          const SizedBox(height: 6.0),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildPlaceholderContainer(40.0,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              const SizedBox(height: 5),
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

  Widget _buildScheduledWateringList(
      BuildContext context, List<dynamic>? schedulesList) {
    if (schedulesList == null || schedulesList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Center(
            child: Column(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text("Chưa có lịch tưới nào được thiết lập.",
                style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700])),
          ],
        )),
      );
    }

    schedulesList.sort((a, b) {
      final scheduleA = a as Map<dynamic, dynamic>? ?? {};
      final scheduleB = b as Map<dynamic, dynamic>? ?? {};
      final timeA = scheduleA['t'] as String?;
      final timeB = scheduleB['t'] as String?;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null)
        return -1; // Sort nulls to the beginning or end as desired
      if (timeB == null) return 1;
      return timeA.compareTo(timeB);
    });

    List<Widget> scheduleWidgets = [];
    for (var scheduleData in schedulesList) {
      // Ensure scheduleData is a Map
      if (scheduleData is! Map) continue;
      final details = Map<String, dynamic>.from(scheduleData);

      // Use the 'id' field from the schedule data itself
      final String? scheduleItemId = details['id'] as String?;
      if (scheduleItemId == null) {
        // If 'id' is missing, skip or log this item, as it can't be reliably managed.
        // For robustness, you might want to assign a temporary ID or handle this case.
        // For now, we'll skip it to avoid errors.
        print("Warning: Schedule item missing 'id': $details");
        continue;
      }

      final bool itemIsActive = (details['act'] as int? ?? 1) == 1;
      final bool itemCheckSoil = (details['csm'] as int? ?? 0) == 1;
      final int itemThreshold = details['th'] as int? ?? 30;

      scheduleWidgets.add(Card(
          elevation: itemIsActive ? 2.0 : 1.0,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: itemIsActive
              ? Theme.of(context).cardColor
              : Theme.of(context).cardColor.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 4.0, 0.0),
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
                        size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${details['t'] ?? 'N/A'}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: itemIsActive
                                      ? Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.color
                                      : Colors.grey.shade700)),
                          const SizedBox(height: 1),
                          Text("Bơm: ${details['d'] ?? '--'} giây.",
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: itemIsActive
                                      ? Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.8)
                                      : Colors.grey.shade600)),
                          if (itemCheckSoil)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                "Ngưỡng ẩm: $itemThreshold%",
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: itemIsActive
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withOpacity(0.7)
                                        : Colors.grey.shade500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_calendar_outlined,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 18),
                          tooltip: "Sửa lịch",
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _showAddEditScheduleDialog(context, widget.deviceId,
                                widget.databaseReference,
                                scheduleId:
                                    scheduleItemId, // Pass the item's 'id'
                                initialData: details);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever_outlined,
                              color: Colors.redAccent.shade100, size: 18),
                          tooltip: "Xóa lịch",
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Xác nhận xóa lịch"),
                                content: Text(
                                    "Bạn có chắc muốn xóa lịch tưới lúc ${details['t'] ?? ''}?"),
                                actions: [
                                  TextButton(
                                      child: const Text("Hủy"),
                                      onPressed: () => Navigator.of(ctx).pop()),
                                  TextButton(
                                    child: const Text("Xóa",
                                        style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      final currentSchedules =
                                          List<Map<dynamic, dynamic>>.from(
                                              _deviceData?['sw']?['sc']
                                                      as List<dynamic>? ??
                                                  []);

                                      // Remove based on the schedule item's ID
                                      currentSchedules.removeWhere((s) =>
                                          (s as Map)['id'] == scheduleItemId);

                                      widget.databaseReference
                                          .child(
                                              'devices/${widget.deviceId}/sw/sc')
                                          .set(currentSchedules);
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
                        contentPadding:
                            const EdgeInsets.only(left: 0, right: -8),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text("Kích hoạt",
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        value: itemIsActive,
                        onChanged: (bool? value) {
                          if (value != null) {
                            final currentSchedules =
                                List<Map<dynamic, dynamic>>.from(
                                    _deviceData?['sw']?['sc']
                                            as List<dynamic>? ??
                                        []);

                            // Find and update the item by ID
                            int itemIndex = currentSchedules.indexWhere(
                                (s) => (s as Map)['id'] == scheduleItemId);
                            if (itemIndex != -1) {
                              currentSchedules[itemIndex]['act'] =
                                  value ? 1 : 0;
                              widget.databaseReference
                                  .child('devices/${widget.deviceId}/sw/sc')
                                  .set(currentSchedules);
                            }
                          }
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 0, right: 0),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text("Theo độ ẩm",
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        value: itemCheckSoil,
                        onChanged: (bool? value) {
                          if (value != null) {
                            final currentSchedules =
                                List<Map<dynamic, dynamic>>.from(
                                    _deviceData?['sw']?['sc']
                                            as List<dynamic>? ??
                                        []);
                            int itemIndex = currentSchedules.indexWhere(
                                (s) => (s as Map)['id'] == scheduleItemId);
                            if (itemIndex != -1) {
                              currentSchedules[itemIndex]['csm'] =
                                  value ? 1 : 0;
                              widget.databaseReference
                                  .child('devices/${widget.deviceId}/sw/sc')
                                  .set(currentSchedules);
                            }
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
    BuildContext context,
    String deviceId,
    DatabaseReference dbRef, {
    String? scheduleId, // This is the 'id' field of the schedule item
    Map<dynamic, dynamic>? initialData,
    @Deprecated('Use scheduleId to find item in list instead')
    int?
        scheduleIndex, // Kept for compatibility, but logic should prefer scheduleId
  }) {
    final formKey = GlobalKey<FormState>();
    TimeOfDay? selectedTime;
    String dialogTitle =
        initialData == null ? "Thêm Lịch Tưới Mới" : "Chỉnh Sửa Lịch Tưới";

    bool initialIsActive = true;
    bool initialCheckSoil = false;
    int initialSoilThreshold = 30;
    String? currentScheduleId =
        scheduleId; // Use the passed scheduleId if editing

    if (initialData != null) {
      // currentScheduleId should already be set if initialData is not null
      if (initialData['t'] != null) {
        try {
          final parts = (initialData['t'] as String).split(':');
          selectedTime =
              TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (e) {
          selectedTime = TimeOfDay.now();
        }
      } else {
        selectedTime = TimeOfDay.now();
      }
      initialIsActive = (initialData['act'] as int? ?? 1) == 1;
      initialCheckSoil = (initialData['csm'] as int? ?? 0) == 1;
      initialSoilThreshold = initialData['th'] as int? ?? 30;
    } else {
      selectedTime = const TimeOfDay(hour: 6, minute: 0);
      // For new schedules, currentScheduleId will be null initially,
      // and a new one will be generated on save.
    }

    final TextEditingController durationSecondsController =
        TextEditingController(text: initialData?['d']?.toString() ?? '30');

    final TextEditingController scheduleThresholdController =
        TextEditingController(text: initialSoilThreshold.toString());

    bool currentIsActive = initialIsActive;
    bool currentCheckSoil = initialCheckSoil;
    double currentScheduleSliderValue = initialSoilThreshold.toDouble();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            title: Text(dialogTitle,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
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
                      const SizedBox(height: 8),
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
                            padding: const EdgeInsets.symmetric(
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
                                    style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w500)),
                                Icon(Icons.arrow_drop_down_circle_outlined,
                                    color: Colors.grey.shade700, size: 22),
                              ],
                            ),
                          )),
                      const SizedBox(height: 18),
                      Text("Thời lượng bơm (giây):",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: durationSecondsController,
                        decoration: InputDecoration(
                            hintText: "VD: 30",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14.0, horizontal: 16.0),
                            prefixIcon:
                                const Icon(Icons.timer_outlined, size: 20)),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Không được để trống';
                          }
                          final n = int.tryParse(value);
                          if (n == null || n <= 0) return 'Phải là số dương';
                          if (n > 600) return 'Tối đa 600 giây (10 phút)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 0),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 0),
                        dense: true,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      if (currentCheckSoil) ...[
                        const SizedBox(height: 12),
                        Text(
                            "Ngưỡng ẩm cho lịch này: ${currentScheduleSliderValue.round()}%",
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color)),
                        Slider(
                          value: currentScheduleSliderValue,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: "${currentScheduleSliderValue.round()}%",
                          activeColor: Theme.of(context).primaryColor,
                          inactiveColor:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          onChanged: (double value) {
                            setStateDialog(() {
                              currentScheduleSliderValue = value;
                              scheduleThresholdController.text =
                                  value.round().toString();
                            });
                          },
                        ),
                        TextFormField(
                          controller: scheduleThresholdController,
                          decoration: InputDecoration(
                            labelText: "Ngưỡng ẩm lịch (%)",
                            hintText: "0-100",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (String value) {
                            double? typedValue = double.tryParse(value);
                            if (typedValue != null &&
                                typedValue >= 0 &&
                                typedValue <= 100) {
                              if (currentScheduleSliderValue.round() !=
                                  typedValue.round()) {
                                setStateDialog(() {
                                  currentScheduleSliderValue = typedValue;
                                });
                              }
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nhập ngưỡng';
                            }
                            final n = int.tryParse(value);
                            if (n == null || n < 0 || n > 100) return '0-100';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                      ]
                    ],
                  ),
                )),
            actionsAlignment: MainAxisAlignment.end,
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10)),
                  child: Text("HỦY",
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.of(ctx).pop()),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: const Text("LƯU LỊCH",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (formKey.currentState!.validate() &&
                      selectedTime != null) {
                    final duration = int.parse(durationSecondsController.text);
                    final scheduleThreshold =
                        int.parse(scheduleThresholdController.text);

                    final Map<String, dynamic> newScheduleData = {
                      // 'id' will be handled below
                      't':
                          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                      'd': duration,
                      'act': currentIsActive ? 1 : 0,
                      'csm': currentCheckSoil ? 1 : 0,
                      'th': currentCheckSoil
                          ? scheduleThreshold
                          : (initialData?['th'] ?? 30),
                    };

                    dbRef
                        .child('devices/$deviceId/sw/sc')
                        .once()
                        .then((snapshot) {
                      List<dynamic> currentSchedulesDynamic = [];
                      if (snapshot.snapshot.value != null &&
                          snapshot.snapshot.value is List) {
                        currentSchedulesDynamic =
                            snapshot.snapshot.value as List<dynamic>;
                      }
                      List<Map<dynamic, dynamic>> currentSchedules =
                          List<Map<dynamic, dynamic>>.from(
                              currentSchedulesDynamic.map((item) {
                        if (item is Map) {
                          return Map<String, dynamic>.from(
                              item.map((k, v) => MapEntry(k.toString(), v)));
                        }
                        return {}; // Should not happen if data is correct
                      }).where((item) => item.isNotEmpty));

                      if (currentScheduleId != null) {
                        // Editing existing schedule
                        newScheduleData['id'] =
                            currentScheduleId; // Preserve original ID
                        int existingIndex = currentSchedules.indexWhere(
                            (s) => (s as Map)['id'] == currentScheduleId);
                        if (existingIndex != -1) {
                          currentSchedules[existingIndex] = newScheduleData;
                        } else {
                          // ID not found, treat as new? Or error? For now, add.
                          newScheduleData['id'] =
                              _generateShortId(); // Should not happen if currentScheduleId was from a valid item
                          currentSchedules.add(newScheduleData);
                        }
                      } else {
                        // Adding new schedule
                        newScheduleData['id'] = _generateShortId();
                        currentSchedules.add(newScheduleData);
                      }
                      dbRef
                          .child('devices/$deviceId/sw/sc')
                          .set(currentSchedules);
                    });
                    Navigator.of(ctx).pop();
                  } else if (selectedTime == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Vui lòng chọn giờ tưới.")));
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
            const SizedBox(
              height: 250,
              width: double.infinity,
              child: Center(child: CircularProgressIndicator()),
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
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 50),
                const SizedBox(height: 15),
                const Text('Đã xảy ra lỗi',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                const SizedBox(height: 15),
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
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 1.1,
                children: List.generate(4, (index) {
                  final switchId = 'D${index + 1}';
                  final switchStatus = deviceData[switchId] == 'on';
                  return widget.buildRelayControlTileCallback(
                    context,
                    widget.deviceId,
                    widget.currentUser,
                    widget.databaseReference,
                    'Thiết bị ${index + 1}',
                    switchId,
                    switchStatus,
                    0, // Not applicable for CongTac
                    Icons.power_settings_new_rounded,
                  );
                }),
              ),
              const SizedBox(height: 10),
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
                  const SizedBox(width: 16.0),
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
                icon: const Icon(Icons.stop_screen_share_rounded,
                    color: Colors.white, size: 34),
                label: const Text("DỪNG",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      stopStatus ? Colors.red.shade600 : Colors.red.shade400,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
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
        final List<dynamic>? schedulesListRaw = (_deviceData?['sw']
            as Map<dynamic, dynamic>?)?['sc'] as List<dynamic>?;
        final List<dynamic> schedulesList = schedulesListRaw ?? [];

        content = SingleChildScrollView(
          key: ValueKey('CamBien-${widget.deviceId}'),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitlePlaceholder(),
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
                          const SizedBox(height: 12),
                          Row(children: [
                            const Icon(FontAwesomeIcons.thermometerHalf,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Nhiệt độ: ${deviceData['t'] ?? '--'} °C",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)))
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(FontAwesomeIcons.water,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Độ ẩm không khí: ${deviceData['hm'] ?? '--'} %",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)))
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(FontAwesomeIcons.seedling,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "Độ ẩm đất: ${deviceData['sm'] ?? '--'} %",
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Text("Điều khiển Relay Thủ Công",
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor)),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: _sensorRelaysInfo.map((relayInfo) {
                  final String relayKey = relayInfo['key'];
                  final String relayName = relayInfo['name'];
                  final IconData relayIcon = relayInfo['icon'];
                  int relayStatus = 0;
                  if (_deviceData != null && _deviceData![relayKey] != null) {
                    if (_deviceData![relayKey] is int) {
                      relayStatus = _deviceData![relayKey] as int;
                    } else if (_deviceData![relayKey] is bool) {
                      relayStatus = (_deviceData![relayKey] as bool) ? 1 : 0;
                    } else if (_deviceData![relayKey] is String) {
                      relayStatus = (_deviceData![relayKey] == 'on' ||
                              _deviceData![relayKey] == '1')
                          ? 1
                          : 0;
                    }
                  }
                  bool disableThisRelayByAutomation =
                      (relayKey == 'wp' && _isPumpManuallyDisabledByAutomation);

                  return widget.buildRelayControlTileCallback(
                      context,
                      widget.deviceId,
                      widget.currentUser,
                      widget.databaseReference,
                      relayName,
                      relayKey,
                      false,
                      relayStatus,
                      relayIcon,
                      isManuallyDisabledByAutomation:
                          disableThisRelayByAutomation);
                }).toList(),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Tưới Tự Động",
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor)),
              ),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Theo Độ Ẩm Đất",
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color)),
                          Switch(
                            value: _moistureBasedEnabled,
                            onChanged: (bool value) {
                              widget.databaseReference
                                  .child('devices/${widget.deviceId}/mbw/en')
                                  .set(value ? 1 : 0);
                            },
                            activeColor: Theme.of(context).primaryColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      if (_moistureBasedEnabled) ...[
                        const SizedBox(height: 8),
                        Text(
                            "Ngưỡng kích hoạt: ${_moistureSliderValue.round()}%",
                            style: TextStyle(
                                fontSize: 14.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color)),
                        Slider(
                          value: _moistureSliderValue,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: "${_moistureSliderValue.round()}%",
                          activeColor: Theme.of(context).primaryColor,
                          inactiveColor:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          onChanged: (double value) {
                            setState(() {
                              _moistureSliderValue = value;
                              _moistureThresholdController?.text =
                                  value.round().toString();
                            });
                          },
                          onChangeEnd: (double value) {
                            int finalThreshold = value.round();
                            widget.databaseReference
                                .child('devices/${widget.deviceId}/mbw/th')
                                .set(finalThreshold);
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _moistureThresholdController,
                                decoration: InputDecoration(
                                  labelText: "Ngưỡng (%)",
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                onChanged: (String value) {
                                  double? typedValue = double.tryParse(value);
                                  if (typedValue != null &&
                                      typedValue >= 0 &&
                                      typedValue <= 100) {
                                    if (_moistureSliderValue.round() !=
                                        typedValue.round()) {
                                      setState(() {
                                        _moistureSliderValue = typedValue;
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
                                            'devices/${widget.deviceId}/mbw/th')
                                        .set(threshold);
                                    if (_moistureSliderValue.round() !=
                                        threshold) {
                                      setState(() {
                                        _moistureSliderValue =
                                            threshold.toDouble();
                                      });
                                    }
                                  } else {
                                    _moistureThresholdController?.text =
                                        _moistureSliderValue.round().toString();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Ngưỡng ẩm không hợp lệ (0-100).")));
                                    }
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Nhập';
                                  }
                                  final n = int.tryParse(value);
                                  if (n == null || n < 0 || n > 100) {
                                    return '0-100';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _moisturePumpDurationController,
                                decoration: InputDecoration(
                                  labelText: "Bơm (giây)",
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                onFieldSubmitted: (String value) {
                                  int? duration = int.tryParse(value);
                                  final currentDurationOnFirebase =
                                      (_deviceData?['mbw'] as Map?)?['d']
                                              as int? ??
                                          30;
                                  if (duration != null &&
                                      duration > 0 &&
                                      duration <= 600) {
                                    widget.databaseReference
                                        .child(
                                            'devices/${widget.deviceId}/mbw/d')
                                        .set(duration);
                                  } else {
                                    _moisturePumpDurationController?.text =
                                        currentDurationOnFirebase.toString();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Thời gian bơm không hợp lệ (1-600 giây).")));
                                    }
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Nhập';
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
                ),
              ),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Theo Lịch Trình",
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.color)),
                          Switch(
                            value: _scheduledWateringEnabled,
                            onChanged: (bool value) {
                              widget.databaseReference
                                  .child('devices/${widget.deviceId}/sw/en')
                                  .set(value ? 1 : 0);
                            },
                            activeColor: Theme.of(context).primaryColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      if (_scheduledWateringEnabled) ...[
                        const SizedBox(height: 8),
                        _buildScheduledWateringList(context, schedulesList),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.10),
                                foregroundColor:
                                    Theme.of(context).primaryColorDark,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.add_alarm_rounded, size: 16),
                            label: const Text("Thêm Lịch",
                                style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w500)),
                            onPressed: () {
                              _showAddEditScheduleDialog(context,
                                  widget.deviceId, widget.databaseReference);
                            },
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
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
