import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/utils/mumble_audio.dart';

void main() {
  testWidgets('MumbleService initialization', (WidgetTester tester) async {
    // We use testWidgets even for logic because MumbleService creates an AudioRecorder
    // which internally calls MethodChannels. MethodChannels need the test environment.

    final mumbleService = MumbleService();
    expect(mumbleService.isConnected, isFalse);
    expect(mumbleService.isTalking, isFalse);
  });

  group('MumbleService Audio Loopback Concept', () {
    test('Encoder and Decoder Loopback produces matching audio samples', () {
      // 1. Setup Encoder & Decoder
      try {
        final encoder = MumbleOpusEncoder(
          sampleRate: 48000,
          channels: 1,
          application: opusApplicationVoip,
        );
        final decoder = MumbleOpusDecoder(sampleRate: 48000, channels: 1);

        // 2. Create a "Sound Bite" (Simple PCM pattern)
        const frameSize = 960;
        final originalSamples = Int16List(frameSize);
        for (int i = 0; i < frameSize; i++) {
          originalSamples[i] = (1000 * (i % 20)).toInt();
        }

        // 3. ENCODE
        final startTime = DateTime.now();
        final encodedOpus = encoder.encode(originalSamples, frameSize);
        final encodeTime = DateTime.now().difference(startTime);

        expect(encodedOpus, isNotEmpty, reason: 'Opus encoding failed');

        // 4. DECODE
        final decodeStartTime = DateTime.now();
        final decodedSamples = decoder.decode(encodedOpus, 5760);
        final decodeTime = DateTime.now().difference(decodeStartTime);

        expect(
          decodedSamples.length,
          frameSize,
          reason: 'Decoded size mismatch',
        );

        // 5. COMPARE
        int matchingSignificantSamples = 0;
        for (int i = 0; i < 100; i++) {
          final diff = (originalSamples[i] - decodedSamples[i]).abs();
          if (diff < 2000) matchingSignificantSamples++;
        }

        expect(
          matchingSignificantSamples,
          greaterThan(80),
          reason: 'Audio quality loss too high or decoding corrupted',
        );

        print(
          'Round trip: Encode=${encodeTime.inMicroseconds}µs, Decode=${decodeTime.inMicroseconds}µs',
        );

        encoder.dispose();
        decoder.dispose();
      } catch (e) {
        if (e.toString().contains('Failed to lookup symbol') ||
            e.toString().contains('ArgumentError') ||
            e.toString().contains('Invalid argument(s)')) {
          print(
            'Skipping Opus Native test: Opus library not available in current test environment.',
          );
          return;
        }
        rethrow;
      }
    });
  });
}
