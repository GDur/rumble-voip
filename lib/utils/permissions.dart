import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter_macos_permissions/flutter_macos_permissions.dart';

class PermissionUtils {
  // Request microphone permission and return true if granted
  static Future<bool> requestMicrophonePermission() async {
    if (Platform.isMacOS) {
      // flutter_macos_permissions 2.0.8 API
      final status = await FlutterMacosPermissions.microphoneStatus();
      if (status == 'authorized') {
        return true;
      }
      
      return await FlutterMacosPermissions.requestMicrophone();
    } else {
      // Use standard permission_handler for other platforms
      final status = await ph.Permission.microphone.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await ph.Permission.microphone.request();
      return result.isGranted;
    }
  }

  // Check if microphone permission is already granted
  static Future<bool> isMicrophonePermissionGranted() async {
    if (Platform.isMacOS) {
      final status = await FlutterMacosPermissions.microphoneStatus();
      return status == 'authorized';
    } else {
      return await ph.Permission.microphone.isGranted;
    }
  }
}
