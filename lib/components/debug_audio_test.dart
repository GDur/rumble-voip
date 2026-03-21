import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/audio_playback_service.dart';
import 'package:rumble/services/mumble_service.dart';

class DebugAudioTest extends StatefulWidget {
  const DebugAudioTest({super.key});

  @override
  State<DebugAudioTest> createState() => _DebugAudioTestState();
}

class _DebugAudioTestState extends State<DebugAudioTest> {
  bool _isPlaying = false;

  void _playTestTone() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);

    const int sampleRate = 48000;
    // 440Hz (A4)
    const double frequency = 440.0;
    // 300ms
    const int durationMs = 300;
    const int numSamples = (sampleRate * durationMs ~/ 1000);
    final Int16List samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      // Simple sine wave
      double value = math.sin(2 * math.pi * frequency * t);

      // Add a slight fade in/out to avoid clicks
      double fade = 1.0;
      if (i < 500) fade = i / 500;
      if (i > numSamples - 500) fade = (numSamples - i) / 500;

      samples[i] = (value * 15000 * fade).toInt();
    }

    _handleAudioOutput(samples, durationMs);
  }

  void _playTalkingSimulation() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);

    const int sampleRate = 48000;
    // 1.2 seconds of "talking"
    const int totalDurationMs = 1200;
    const int numSamples = (sampleRate * totalDurationMs ~/ 1000);
    final Int16List samples = Int16List(numSamples);

    final random = math.Random();

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double baseFreq = 150 + (math.sin(t * 10) * 50);
      double signal = 0;
      signal += math.sin(2 * math.pi * baseFreq * t);
      signal += 0.5 * math.sin(2 * math.pi * baseFreq * 2 * t);
      signal += 0.25 * math.sin(2 * math.pi * baseFreq * 3 * t);
      signal += (random.nextDouble() - 0.5) * 0.15;
      double envelope = 0.5 + 0.5 * math.sin(t * 25);
      if (envelope < 0.2) envelope = 0;
      if (i < 1000) signal *= (i / 1000);
      if (i > numSamples - 1000) signal *= (numSamples - i) / 1000;
      samples[i] = (signal * 8000 * envelope).toInt();
    }

    _handleAudioOutput(samples, totalDurationMs);
  }

  void _handleAudioOutput(Int16List samples, int durationMs) {
    // Send to Mumble server if connected
    final mumbleService = Provider.of<MumbleService>(context, listen: false);
    if (mumbleService.isConnected) {
      mumbleService.sendAudioSamples(samples);
    } else {
      // If not connected, we can still play locally for "offline" testing
      AudioPlaybackService().startSession(0);
      AudioPlaybackService().feed(0, samples);
    }

    Future.delayed(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    // debug-audio-test
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadTooltip(
            builder: (context) => const Text('Send Tone to Server'),
            child: ShadIconButton(
              // test-tone-btn
              icon: Icon(
                _isPlaying ? LucideIcons.volume2 : LucideIcons.music,
                size: 16,
                color: Colors.white,
              ),
              backgroundColor: Colors.orange.withValues(alpha: 0.8),
              onPressed: _playTestTone,
            ),
          ),
          const SizedBox(width: 8),
          ShadTooltip(
            builder: (context) => const Text('Send Voice to Server'),
            child: ShadIconButton(
              // test-voice-btn
              icon: Icon(
                _isPlaying ? LucideIcons.audioLines : LucideIcons.userRound,
                size: 16,
                color: Colors.white,
              ),
              backgroundColor: Colors.purple.withValues(alpha: 0.8),
              onPressed: _playTalkingSimulation,
            ),
          ),
        ],
      ),
    );
  }
}
