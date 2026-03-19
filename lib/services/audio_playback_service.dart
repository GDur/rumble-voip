import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm_sound;
import 'package:flutter_soloud/flutter_soloud.dart';

/// Abstract service to handle low-latency PCM audio playback across platforms.
/// Uses flutter_pcm_sound on Mobile/macOS and flutter_soloud on Windows/Linux.
class AudioPlaybackService {
  static final AudioPlaybackService _instance = AudioPlaybackService._internal();
  factory AudioPlaybackService() => _instance;
  AudioPlaybackService._internal();

  bool _initialized = false;
  AudioSource? _soloudSource;
  bool _soloudPlaying = false;
  double _outputVolume = 1.0;

  bool get isInitialized => _initialized;

  Future<void> initialize({
    int sampleRate = 48000,
    int channels = 1,
    double volume = 1.0,
  }) async {
    if (_initialized) return;
    _outputVolume = volume;

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      try {
        await pcm_sound.FlutterPcmSound.setup(
          sampleRate: sampleRate,
          channelCount: channels,
          iosAudioCategory: pcm_sound.IosAudioCategory.playAndRecord,
        );
        await pcm_sound.FlutterPcmSound.setFeedThreshold(1024 * 4);
        _initialized = true;
        debugPrint('[AudioPlaybackService] Initialized with flutter_pcm_sound');
      } catch (e) {
        debugPrint('[AudioPlaybackService] Error initializing flutter_pcm_sound: $e');
      }
    } else if (Platform.isWindows || Platform.isLinux) {
      try {
        await SoLoud.instance.init();
        // Updated API for flutter_soloud 3.x
        _soloudSource = SoLoud.instance.setBufferStream(
          sampleRate: sampleRate, // Now an int
          channels: channels == 1 ? Channels.mono : Channels.stereo,
          format: BufferType.s16le, // 16-bit signed little endian
          bufferingType: BufferingType.released, // Free memory after playing
        );
        _initialized = true;
        debugPrint('[AudioPlaybackService] Initialized with flutter_soloud');
      } catch (e) {
        debugPrint('[AudioPlaybackService] Error initializing flutter_soloud: $e');
      }
    }
  }

  void start() {
    if (!_initialized) return;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      pcm_sound.FlutterPcmSound.start();
    } else if (Platform.isWindows || Platform.isLinux) {
      if (_soloudSource != null && !_soloudPlaying) {
        SoLoud.instance.play(_soloudSource!, volume: _outputVolume);
        _soloudPlaying = true;
      }
    }
  }

  void setOutputVolume(double volume) {
    _outputVolume = volume;
    if (!_initialized) return;
    // For soloud we can adjust volume of the playing handle if we had it, 
    // but for now we'll just set the global soloud volume or future play calls.
    if (Platform.isWindows || Platform.isLinux) {
      // soloud.setGlobalVolume(volume) could be used if we wanted to affect everything
    }
    // pcm_sound doesn't have a direct volume control for the stream, 
    // so we apply it to the samples manually in feed().
  }

  void feed(Int16List samples) {
    if (!_initialized) return;

    // Apply volume manually for pcm_sound platforms
    Int16List processedSamples = samples;
    if (_outputVolume != 1.0) {
      processedSamples = Int16List(samples.length);
      for (int i = 0; i < samples.length; i++) {
        processedSamples[i] = (samples[i] * _outputVolume).round().clamp(-32768, 32767);
      }
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      pcm_sound.FlutterPcmSound.feed(pcm_sound.PcmArrayInt16.fromList(processedSamples));
    } else if (Platform.isWindows || Platform.isLinux) {
      if (_soloudSource != null) {
        // flutter_soloud addAudioDataStream expects Uint8List (raw bytes)
        final bytes = processedSamples.buffer.asUint8List();
        SoLoud.instance.addAudioDataStream(_soloudSource!, bytes);
        
        if (!_soloudPlaying) {
          start();
        }
      }
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await pcm_sound.FlutterPcmSound.release();
    } else if (Platform.isWindows || Platform.isLinux) {
      if (_soloudSource != null) {
        SoLoud.instance.setDataIsEnded(_soloudSource!);
      }
      // deinit/shutdown is void in 3.x
      SoLoud.instance.deinit();
      _soloudPlaying = false;
      _soloudSource = null;
    }
    _initialized = false;
  }
}
