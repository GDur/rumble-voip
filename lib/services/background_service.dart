import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Service: background-task-management
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RumbleTaskHandler());
}

class RumbleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Custom logic when service starts
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Periodic tasks if needed
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isUserAction) async {
    // Cleanup
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rumble_foreground_service',
        channelName: 'Rumble Active Connection',
        channelDescription: 'Keeps Rumble active while connected to a Mumble server.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start({String? serverName}) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Request notification permission if needed (Android 13+)
      if (Platform.isAndroid) {
         await FlutterForegroundTask.requestNotificationPermission();
      }

      if (await FlutterForegroundTask.isRunningService) {
         await FlutterForegroundTask.updateService(
          notificationTitle: 'Rumble Connected',
          notificationText: 'Stay active on ${serverName ?? 'server'}',
          notificationIcon: const NotificationIcon(
            metaDataName: 'flutter_foreground_task.notification_icon',
          ),
        );
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Rumble Connected',
          notificationText: 'Stay active on ${serverName ?? 'server'}',
          notificationIcon: const NotificationIcon(
            metaDataName: 'flutter_foreground_task.notification_icon',
          ),
          callback: startCallback,
        );
      }
      
      // Also keep the CPU awake
      await WakelockPlus.enable();
    }
  }

  static Future<void> stop() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterForegroundTask.stopService();
      await WakelockPlus.disable();
    }
  }
}
