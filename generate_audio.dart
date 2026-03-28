import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:logging/logging.dart';

final _logger = Logger('GenerateAudio');

const sampleRate = 48000;
const toneFreq = 440.0; // Standard A4 note

void main() async {
  // Setup logging for CLI output
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) => stdout.writeln(record.message));

  _logger.info('--- GENERATING TEST AUDIO ---');

  const durationSeconds = 3;
  const totalSamples = sampleRate * durationSeconds;

  // 1. Generate f32 samples (-1.0 to 1.0)
  final f32Samples = Float32List(totalSamples);
  final s16Samples = Int16List(totalSamples);

  for (int i = 0; i < totalSamples; i++) {
    final double t = i / sampleRate;
    final double val = math.sin(2 * math.pi * toneFreq * t);
    
    f32Samples[i] = val.toDouble();
    s16Samples[i] = (val * 32767).toInt();
  }

  // 2. Save s16le (Standard Mumble/PCM)
  final s16File = File('test_original_s16.pcm');
  await s16File.writeAsBytes(s16Samples.buffer.asUint8List());

  // 3. Save f32le (Native Rust format)
  final f32File = File('test_original_f32.pcm');
  await f32File.writeAsBytes(f32Samples.buffer.asUint8List());

  _logger.info('✅ Saved: ${s16File.absolute.path} (s16le)');
  _logger.info('✅ Saved: ${f32File.absolute.path} (f32le)');
  
  _logger.info('\nTo play s16le on macOS:');
  _logger.info('ffplay -f s16le -ar 48000 -channels 1 test_original_s16.pcm');
  
  _logger.info('\nTo play f32le on macOS:');
  _logger.info('ffplay -f f32le -ar 48000 -channels 1 test_original_f32.pcm');
}

/// Verifies that the [recorded] audio contains the [expectedFreq].
/// This is used by the integrity tests to confirm audio is passing through the codec.
bool verifyTonePresence(List<double> samples, double expectedFreq, {double tolerance = 5.0}) {
  if (samples.isEmpty) return false;
  
  // Use a simple zero-crossing frequency estimation
  int crossings = 0;
  for (int i = 1; i < samples.length; i++) {
    if ((samples[i-1] < 0 && samples[i] >= 0) || (samples[i-1] >= 0 && samples[i] < 0)) {
      crossings++;
    }
  }
  
  final duration = samples.length / sampleRate;
  if (duration == 0) return false;
  
  final detectedFreq = (crossings / 2) / duration;
  _logger.info('Detected Frequency: ${detectedFreq.toStringAsFixed(2)} Hz (Expected: $expectedFreq Hz)');
  
  return (detectedFreq - expectedFreq).abs() <= tolerance;
}
