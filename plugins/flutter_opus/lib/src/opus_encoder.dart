import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'constants/opus_constants.dart';

/// FFI type definition for creating an Opus encoder (native signature).
typedef OpusEncoderCreateNative = Pointer Function(
    Int32 sampleRate, Int32 channels, Int32 application, Pointer<Int32> error);

/// Dart function type for creating an Opus encoder.
typedef OpusEncoderCreate = Pointer Function(
    int sampleRate, int channels, int application, Pointer<Int32> error);

/// FFI type definition for encoding PCM data to Opus format (native signature).
typedef OpusEncodeNative = Int32 Function(Pointer encoder, Pointer<Int16> pcm,
    Int32 frameSize, Pointer<Uint8> data, Int32 maxDataBytes);

/// Dart function type for encoding PCM data.
typedef OpusEncode = int Function(Pointer encoder, Pointer<Int16> pcm,
    int frameSize, Pointer<Uint8> data, int maxDataBytes);

/// FFI type definition for destroying an Opus encoder (native signature).
typedef OpusEncoderDestroyNative = Void Function(Pointer encoder);

/// Dart function type for destroying an Opus encoder.
typedef OpusEncoderDestroy = void Function(Pointer encoder);

/// FFI type definition for configuring an Opus encoder via control API.
typedef OpusEncoderCtlNative = Int32 Function(
    Pointer encoder, Int32 request, Int32 value);

/// Dart function type for controlling encoder parameters.
typedef OpusEncoderCtl = int Function(Pointer encoder, int request, int value);

/// A Dart wrapper for the Opus encoder using FFI.
///
/// Provides methods to create, configure, and encode audio data using the native libopus encoder.
class OpusEncoder {
  /// Loads the platform-specific dynamic library for Opus.
  static DynamicLibrary _loadOpusLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libopus.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static final DynamicLibrary _lib = _loadOpusLibrary();

  static final OpusEncoderCreate _opusEncoderCreate = _lib
      .lookup<NativeFunction<OpusEncoderCreateNative>>('opus_encoder_create')
      .asFunction();

  static final OpusEncode _opusEncode =
      _lib.lookup<NativeFunction<OpusEncodeNative>>('opus_encode').asFunction();

  static final OpusEncoderDestroy _opusEncoderDestroy = _lib
      .lookup<NativeFunction<OpusEncoderDestroyNative>>('opus_encoder_destroy')
      .asFunction();

  static final OpusEncoderCtl _opusEncoderCtl = _lib
      .lookup<NativeFunction<OpusEncoderCtlNative>>('opus_encoder_ctl')
      .asFunction();

  /// Pointer to the native Opus encoder instance.
  Pointer? _encoder;

  /// The sample rate in Hz (e.g. 16000, 48000).
  final int sampleRate;

  /// Number of channels (1 for mono, 2 for stereo).
  final int channels;

  /// Opus application mode (e.g. `OPUS_APPLICATION_AUDIO`).
  final int application;

  /// Private constructor used by the static `create` method.
  OpusEncoder._({
    required this.sampleRate,
    required this.channels,
    required this.application,
  });

  /// Creates and initializes an [OpusEncoder] instance.
  ///
  /// Returns `null` if encoder creation fails.
  ///
  /// [sampleRate] must be one of the Opus-supported values (8000, 12000, 16000, 24000, 48000).
  /// [channels] must be 1 or 2.
  /// [application] determines the encoding mode, default is [opusApplicationAudio].
  static OpusEncoder? create({
    required int sampleRate,
    required int channels,
    int application = 2049, // OPUS_APPLICATION_AUDIO
  }) {
    final errorPtr = malloc<Int32>();

    try {
      final encoder =
          _opusEncoderCreate(sampleRate, channels, application, errorPtr);
      final error = errorPtr.value;

      if (error != opusOk || encoder == nullptr) {
        throw Exception('Failed to create Opus encoder, error code: $error');
      }

      final opusEncoder = OpusEncoder._(
        sampleRate: sampleRate,
        channels: channels,
        application: application,
      );
      opusEncoder._encoder = encoder;
      return opusEncoder;
    } finally {
      malloc.free(errorPtr);
    }
  }

  /// Sets the bitrate (in bits per second) for the encoder.
  ///
  /// Throws [StateError] if the encoder is already disposed.
  void setBitrate(int bitrate) {
    if (_encoder == null) throw StateError('Encoder has been disposed');
    _opusEncoderCtl(_encoder!, opusSetBitrateRequest, bitrate);
  }

  /// Sets the complexity level (0–10) of the encoder.
  ///
  /// Higher values increase CPU usage and potentially improve quality.
  void setComplexity(int complexity) {
    if (_encoder == null) throw StateError('Encoder has been disposed');
    _opusEncoderCtl(_encoder!, opusSetComplexityRequest, complexity);
  }

  /// Encodes raw PCM audio data ([pcmData]) to Opus format.
  ///
  /// [frameSize] is the number of samples per channel.
  ///
  /// Returns a [Uint8List] containing the encoded Opus frame, or `null` if encoding fails.
  ///
  /// Throws an [Exception] if the native encode call fails.
  Uint8List? encode(Int16List pcmData, int frameSize) {
    if (_encoder == null) throw StateError('Encoder has been disposed');

    final inputPtr = malloc<Int16>(pcmData.length);
    final maxOutputSize = 4000; // Max output size in bytes
    final outputPtr = malloc<Uint8>(maxOutputSize);

    try {
      final inputList = inputPtr.asTypedList(pcmData.length);
      inputList.setAll(0, pcmData);

      final bytesEncoded =
          _opusEncode(_encoder!, inputPtr, frameSize, outputPtr, maxOutputSize);
      if (bytesEncoded < 0) {
        throw Exception('Opus encode failed with error: $bytesEncoded');
      }

      return outputPtr.asTypedList(bytesEncoded);
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  /// Frees the native encoder and releases its resources.
  void dispose() {
    if (_encoder != null) {
      _opusEncoderDestroy(_encoder!);
      _encoder = null;
    }
  }

  /// Whether the encoder has been disposed.
  bool get isDisposed => _encoder == null;
}
