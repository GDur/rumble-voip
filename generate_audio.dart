import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:logging/logging.dart';

final _logger = Logger('GenerateAudio');

void main() async {
  // Setup logging for CLI output
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) => stdout.writeln(record.message));

  _logger.info('--- GENERATING TEST AUDIO ---');

  const sampleRate = 48000;
  const durationSeconds = 3;
  const totalSamples = sampleRate * durationSeconds;

  final originalSamples = Int16List(totalSamples);
  for (int i = 0; i < totalSamples; i++) {
    // 440Hz Sine Wave (Standard A4 note)
    const freq = 440.0;
    final double t = i / sampleRate;
    originalSamples[i] = (16000 * math.sin(2 * math.pi * freq * t)).toInt();
  }

  final originalBytes = originalSamples.buffer.asUint8List();
  final originalFile = File('test_original.pcm');
  await originalFile.writeAsBytes(originalBytes);

  _logger.info('✅ Saved: ${originalFile.absolute.path}');
  _logger.info('Size: ${originalFile.lengthSync()} bytes');
  _logger.info('\nTo play this on macOS with FFmpeg 8.x:');
  _logger.info('ffplay -f s16le -ar 48000 -channels 1 test_original.pcm');
}
