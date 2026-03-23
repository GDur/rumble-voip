import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

// Initialize the global logger configuration
void setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: ${record.stackTrace}');
      }
    }
  });
}

// Named logger for specific features
Logger getLogger(String name) => Logger(name);
