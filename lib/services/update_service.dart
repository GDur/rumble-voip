import 'dart:io';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  bool _isInitialized = false;

  // Initialize the auto updater with the feed URL from GitHub Releases
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) return;

    // Only support Windows and macOS for now as these are supported by Sparkle/WinSparkle
    if (!Platform.isWindows && !Platform.isMacOS) return;

    // We use the 'latest/download' redirect from GitHub to always point to the most recent appcast.xml
    const String feedURL = 'https://github.com/GDur/rumble-voip/releases/latest/download/appcast.xml';
    
    await autoUpdater.setFeedURL(feedURL);
    
    // Set check interval to 1 hour (3600 seconds)
    await autoUpdater.setScheduledCheckInterval(3600);
    
    _isInitialized = true;
    debugPrint('[UpdateService] Initialized with feed: $feedURL');
  }

  // Manually trigger an update check
  Future<void> checkForUpdates() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    debugPrint('[UpdateService] Checking for updates...');
    await autoUpdater.checkForUpdates();
  }
}
