import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/utils/mumble_audio.dart';

void main() {
  testWidgets('Generate Audio files for comparison', (WidgetTester tester) async {
    // 1. Setup Samples
    const sampleRate = 48000;
    const channels = 1;
    const durationSeconds = 3;
    const totalSamples = sampleRate * durationSeconds;
    
    final originalSamples = Int16List(totalSamples);
    for (int i = 0; i < totalSamples; i++) {
      // Generate a 440Hz Sine Wave (Standard 'A' Note)
      const freq = 440.0;
      final double angle = 2.0 * 3.14159 * freq * i / sampleRate;
      originalSamples[i] = (16000 * (angle % 6.28318 > 3.14159 ? 1 : -1)).toInt(); // Square wave for easier listening
    }

    final originalBytes = originalSamples.buffer.asUint8List();
    final originalFile = File('test_original.pcm');
    await originalFile.writeAsBytes(originalBytes);
    print('Saved Original PCM: ${originalFile.absolute.path}');

    // 2. Perform Round Trip (Encoding & Decoding in 20ms chunks)
    try {
      final encoder = MumbleOpusEncoder(sampleRate: sampleRate, channels: channels);
      final decoder = MumbleOpusDecoder(sampleRate: sampleRate, channels: channels);
      
      final roundTripSamples = Int16List(totalSamples);
      const frameSize = 960; // 20ms
      
      for (int i = 0; i < totalSamples - frameSize; i += frameSize) {
        final chunk = originalSamples.sublist(i, i + frameSize);
        final encoded = encoder.encode(chunk, frameSize);
        final decoded = decoder.decode(encoded, 5760);
        
        for (int j = 0; j < frameSize; j++) {
           roundTripSamples[i + j] = decoded[j];
        }
      }

      final roundTripBytes = roundTripSamples.buffer.asUint8List();
      final roundTripFile = File('test_roundtrip.pcm');
      await roundTripFile.writeAsBytes(roundTripBytes);
      print('Saved Roundtrip PCM: ${roundTripFile.absolute.path}');

      encoder.dispose();
      decoder.dispose();
      
      print('--- FINISHED GENERATING FILES ---');
      print('Use ffplay or Audacity to listen:');
      print('ffplay -f s16le -ar 48000 -ac 1 test_original.pcm');
      print('ffplay -f s16le -ar 48000 -ac 1 test_roundtrip.pcm');
      
    } catch (e) {
      print('Native Opus error: $e');
    }
  });
}
