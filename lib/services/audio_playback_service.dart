import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm_sound;
import 'package:flutter_soloud/flutter_soloud.dart';

/// Abstract service to handle low-latency PCM audio playback across platforms.
/// Uses flutter_pcm_sound on Mobile/macOS and flutter_soloud on Windows/Linux.
///
/// Refactored to support multiple concurrent voices for Mumble users.
class AudioPlaybackService {
  static final AudioPlaybackService _instance =
      AudioPlaybackService._internal();
  factory AudioPlaybackService() => _instance;
  AudioPlaybackService._internal();

  bool _initialized = false;

  // Single stream for mobile (flutter_pcm_sound)
  // TODO: Mix multiple users for mobile if needed, for now it's shared.

  // Multi-stream support for Desktop (SoLoud)
  final Map<int, AudioSource> _soloudSources = {};
  final Map<int, bool> _soloudPlaying = {};
  final Map<int, double> _sessionVolumes = {};

  double _outputVolume = 1.0;
  int _sampleRate = 48000;
  int _channels = 1;

  bool get isInitialized => _initialized;

  Future<void> initialize({
    int sampleRate = 48000,
    int channels = 1,
    double volume = 1.0,
    String? deviceId,
  }) async {
    if (_initialized) return;
    _outputVolume = volume;
    _sampleRate = sampleRate;
    _channels = channels;

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await pcm_sound.FlutterPcmSound.setup(
          sampleRate: sampleRate,
          channelCount: channels,
          iosAudioCategory: pcm_sound.IosAudioCategory.playAndRecord,
        );
        // Reduced feed threshold for lower latency
        await pcm_sound.FlutterPcmSound.setFeedThreshold(1024 * 2);
        _initialized = true;
        debugPrint('[AudioPlaybackService] Initialized with flutter_pcm_sound');
      } catch (e) {
        debugPrint(
          '[AudioPlaybackService] Error initializing flutter_pcm_sound: $e',
        );
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final devices = SoLoud.instance.listPlaybackDevices();
        dynamic targetDevice;
        if (deviceId != null) {
          for (final dev in devices) {
            if (dev.id.toString() == deviceId) {
              targetDevice = dev;
              break;
            }
          }
        }

        // Initializing with smaller buffer size for low latency
        await SoLoud.instance.init(
          device: targetDevice,
          bufferSize: 512, // ~10ms at 48kHz
        );

        _initialized = true;
        debugPrint(
          '[AudioPlaybackService] Initialized with flutter_soloud (Desktop)',
        );
      } catch (e) {
        debugPrint(
          '[AudioPlaybackService] Error initializing flutter_soloud: $e',
        );
      }
    }
  }

  /// Create a new audio source for a specific user session if it doesn't exist.
  AudioSource? _getOrCreateSource(int sessionId) {
    if (!_initialized) return null;
    if (_soloudSources.containsKey(sessionId)) {
      return _soloudSources[sessionId];
    }

    try {
      final source = SoLoud.instance.setBufferStream(
        sampleRate: _sampleRate,
        channels: _channels == 1 ? Channels.mono : Channels.stereo,
        format: BufferType.s16le,
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.05, // Drastically reduce latency
      );
      _soloudSources[sessionId] = source;
      _soloudPlaying[sessionId] = false;
      return source;
    } catch (e) {
      debugPrint(
        '[AudioPlaybackService] Error creating source for session $sessionId: $e',
      );
      return null;
    }
  }

  void start() {
    // Legacy start method - mostly for mobile or global start
    if (!_initialized) return;
    if (Platform.isAndroid || Platform.isIOS) {
      pcm_sound.FlutterPcmSound.start();
    }
  }

  void startSession(int sessionId) {
    if (!_initialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final source = _getOrCreateSource(sessionId);
      if (source != null && !(_soloudPlaying[sessionId] ?? false)) {
        final volume = (_sessionVolumes[sessionId] ?? 1.0) * _outputVolume;
        SoLoud.instance.play(source, volume: volume);
        _soloudPlaying[sessionId] = true;
      }
    } else {
      start();
    }
  }

  void setSessionVolume(int sessionId, double volume) {
    _sessionVolumes[sessionId] = volume;
    // If it's already playing, we should ideally update the volume of the active voice.
    // For now, it will apply to the next burst or next feed.
  }

  void setOutputVolume(double volume) {
    _outputVolume = volume;
    if (!_initialized) return;
    // For SoLoud we'd ideally iterate and update all active voices.
    // In this singleton, we'll apply it to future calls and the global Soloud volume.
  }

  void feed(int sessionId, Int16List samples) {
    if (!_initialized) return;

    // Apply volume manually for pcm_sound platforms (and temporarily for SoLoud if needed)
    final sessionVolume = _sessionVolumes[sessionId] ?? 1.0;
    final totalVolume = sessionVolume * _outputVolume;

    Int16List processedSamples = samples;
    if (totalVolume != 1.0) {
      processedSamples = Int16List(samples.length);
      for (int i = 0; i < samples.length; i++) {
        processedSamples[i] = (samples[i] * totalVolume).round().clamp(
          -32768,
          32767,
        );
      }
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile currently uses a shared stream - samples from multiple users will interleave
      // TODO: Implement Dart-side mixing for mobile
      pcm_sound.FlutterPcmSound.feed(
        pcm_sound.PcmArrayInt16.fromList(processedSamples),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final source = _getOrCreateSource(sessionId);
      if (source != null) {
        final bytes = processedSamples.buffer.asUint8List();
        SoLoud.instance.addAudioDataStream(source, bytes);

        if (!(_soloudPlaying[sessionId] ?? false)) {
          startSession(sessionId);
        }
      }
    }
  }

  void stopSession(int sessionId) {
    if (!_initialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final source = _soloudSources.remove(sessionId);
      _soloudPlaying.remove(sessionId);
      if (source != null) {
        // Signal that the stream data is ended for this burst.
        // With BufferingType.released, the source will automatically dispose when it finishes playing.
        SoLoud.instance.setDataIsEnded(source);
      }
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    if (Platform.isAndroid || Platform.isIOS) {
      await pcm_sound.FlutterPcmSound.release();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      for (final source in _soloudSources.values) {
        SoLoud.instance.setDataIsEnded(source);
      }
      SoLoud.instance.deinit();
      _soloudPlaying.clear();
      _soloudSources.clear();
    }
    _initialized = false;
  }

  Future<List<dynamic>> getOutputDevices() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        if (!SoLoud.instance.isInitialized) {
          debugPrint(
            '[AudioPlaybackService] SoLoud not initialized, cannot list devices',
          );
          return [];
        }
        return SoLoud.instance.listPlaybackDevices();
      } catch (e) {
        debugPrint('[AudioPlaybackService] Error listing output devices: $e');
      }
    }
    return [];
  }
}
