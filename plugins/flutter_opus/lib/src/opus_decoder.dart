import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'constants/opus_constants.dart';

/// -------------------- Native FFI Type Definitions --------------------

/// Native function signature for creating an Opus decoder.
typedef OpusDecoderCreateNative = Pointer Function(Int32 sampleRate, Int32 channels, Pointer<Int32> error);

/// Dart function signature for creating an Opus decoder.
typedef OpusDecoderCreate = Pointer Function(int sampleRate, int channels, Pointer<Int32> error);

/// Native function signature for decoding Opus packets.
typedef OpusDecodeNative = Int32 Function(
    Pointer decoder, Pointer<Uint8> data, Int32 len, Pointer<Int16> pcm, Int32 frameSize, Int32 decodeFec);

/// Dart function signature for decoding Opus packets.
typedef OpusDecode = int Function(
    Pointer decoder, Pointer<Uint8> data, int len, Pointer<Int16> pcm, int frameSize, int decodeFec);

/// Native function signature for destroying an Opus decoder.
typedef OpusDecoderDestroyNative = Void Function(Pointer decoder);

/// Dart function signature for destroying an Opus decoder.
typedef OpusDecoderDestroy = void Function(Pointer decoder);

/// Native function signature for getting the libopus version string.
typedef OpusGetVersionStringNative = Pointer<Utf8> Function();

/// Dart function signature for getting the libopus version string.
typedef OpusGetVersionString = Pointer<Utf8> Function();

/// -------------------- OpusDecoder Class --------------------

/// A Dart wrapper around the native Opus decoder using FFI.
///
/// Provides methods to create, decode, and destroy an Opus decoder.
class OpusDecoder {
  /// The dynamically loaded native libopus library.
  static final DynamicLibrary _lib = _loadOpusLibrary();

  static final OpusDecoderCreate _opusDecoderCreate =
      _lib.lookup<NativeFunction<OpusDecoderCreateNative>>('opus_decoder_create').asFunction();

  static final OpusDecode _opusDecode = _lib.lookup<NativeFunction<OpusDecodeNative>>('opus_decode').asFunction();

  static final OpusDecoderDestroy _opusDecoderDestroy =
      _lib.lookup<NativeFunction<OpusDecoderDestroyNative>>('opus_decoder_destroy').asFunction();

  static final OpusGetVersionString _opusGetVersionString =
      _lib.lookup<NativeFunction<OpusGetVersionStringNative>>('opus_get_version_string').asFunction();

  /// Pointer to the native decoder instance.
  Pointer? _decoder;

  /// Audio sample rate in Hz (e.g., 16000, 48000).
  final int sampleRate;

  /// Number of audio channels (1 = mono, 2 = stereo).
  final int channels;

  /// Private constructor. Use [OpusDecoder.create] to instantiate.
  OpusDecoder._({required this.sampleRate, required this.channels});

  /// Creates a new [OpusDecoder] instance using libopus.
  ///
  /// Returns `null` if the native decoder could not be created.
  ///
  /// [sampleRate] must be a supported Opus sample rate (8000, 12000, 16000, 24000, or 48000).
  /// [channels] must be 1 (mono) or 2 (stereo).
  static OpusDecoder? create({required int sampleRate, required int channels}) {
    final errorPtr = malloc<Int32>();
    try {
      final decoderPtr = _opusDecoderCreate(sampleRate, channels, errorPtr);
      final error = errorPtr.value;

      if (error != opusOk || decoderPtr == nullptr) {
        return null;
      }

      final decoder = OpusDecoder._(sampleRate: sampleRate, channels: channels);
      decoder._decoder = decoderPtr;
      return decoder;
    } finally {
      malloc.free(errorPtr);
    }
  }

  /// Decodes a single Opus packet into 16-bit little-endian PCM data.
  ///
  /// [opusData] is the raw Opus-encoded input.
  /// [frameSize] is the number of samples per channel to decode.
  ///
  /// Returns a [Uint8List] containing interleaved PCM data (2 bytes per sample).
  ///
  /// Throws a [StateError] if the decoder has already been disposed,
  /// or an [Exception] if decoding fails.
  Uint8List? decode(Uint8List opusData, int frameSize) {
    if (_decoder == null) {
      throw StateError('Decoder has been disposed');
    }

    final inputPtr = malloc<Uint8>(opusData.length);
    final outputPtr = malloc<Int16>(frameSize * channels);
    try {
      final input = inputPtr.asTypedList(opusData.length);
      input.setAll(0, opusData);

      final samplesDecoded = _opusDecode(
        _decoder!,
        inputPtr,
        opusData.length,
        outputPtr,
        frameSize,
        0, // decodeFec = false
      );

      if (samplesDecoded < 0) {
        throw Exception('Opus decode failed with error: $samplesDecoded');
      }

      final pcmBytes = Uint8List(samplesDecoded * channels * 2);
      final pcmView = outputPtr.asTypedList(samplesDecoded * channels);
      for (int i = 0; i < pcmView.length; i++) {
        final sample = pcmView[i];
        pcmBytes[i * 2] = sample & 0xFF;
        pcmBytes[i * 2 + 1] = (sample >> 8) & 0xFF;
      }

      return pcmBytes;
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  /// Returns the version string of the underlying libopus library.
  ///
  /// Example: `"libopus 1.3.1"`
  static String getVersion() {
    return _opusGetVersionString().toDartString();
  }

  /// Disposes the decoder and frees all native resources.
  ///
  /// Safe to call multiple times.
  void dispose() {
    if (_decoder != null) {
      _opusDecoderDestroy(_decoder!);
      _decoder = null;
    }
  }

  /// Returns `true` if the decoder has already been disposed.
  bool get isDisposed => _decoder == null;

  /// Loads the appropriate dynamic library depending on the platform.
  ///
  /// - Android: loads `libopus.so`
  /// - iOS: uses `DynamicLibrary.process()` for prelinked frameworks
  static DynamicLibrary _loadOpusLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libopus.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      return DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
