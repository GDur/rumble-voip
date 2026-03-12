import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter_macos_permissions/flutter_macos_permissions.dart';

class PermissionUtils {
  static bool _manuallyGranted = false;

  // Request microphone permission and return true if granted
  static Future<bool> requestMicrophonePermission() async {
    if (Platform.isMacOS) {
      final status = await FlutterMacosPermissions.microphoneStatus();
      if (status.toString().toLowerCase() == 'authorized' || status.toString().toLowerCase() == 'granted') {
        _manuallyGranted = true;
        return true;
      }
      
      final result = await FlutterMacosPermissions.requestMicrophone();
      if (result) _manuallyGranted = true;
      return result;
    } else {
      final status = await ph.Permission.microphone.status;
      if (status.isGranted) {
        _manuallyGranted = true;
        return true;
      }
      
      final result = await ph.Permission.microphone.request();
      if (result.isGranted) _manuallyGranted = true;
      return result.isGranted;
    }
  }

  // Check if microphone permission is already granted
  static Future<bool> isMicrophonePermissionGranted() async {
    if (_manuallyGranted) return true;
    
    if (Platform.isMacOS) {
      final status = await FlutterMacosPermissions.microphoneStatus();
      debugPrint('[PermissionUtils] macOS mic status string: "$status"');
      final s = status.toString().toLowerCase();
      // Allow 'authorized', 'granted', or even '1' (common return values)
      return s == 'authorized' || s == 'granted' || s == '1';
    } else {
      return await ph.Permission.microphone.isGranted;
    }
  }
}
