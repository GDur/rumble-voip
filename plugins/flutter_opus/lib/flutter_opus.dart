library;

import 'package:flutter/services.dart';

export 'src/opus_decoder.dart';
export 'src/opus_encoder.dart';

class FlutterOpus {
  static const MethodChannel _channel = MethodChannel('flutter_opus');

  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
  }
}
