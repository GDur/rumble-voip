import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Opus Constants
const int opusOk = 0;
const int opusApplicationVoip = 2048;
const int opusApplicationAudio = 2049;

const int opusSetBitrateRequest = 4002;
const int opusSetComplexityRequest = 4010;
const int opusSetVbrRequest = 4006;
const int opusSetInbandFecRequest = 4012;
const int opusSetPacketLossPercRequest = 4014;
const int opusSetSignalRequest = 4024;
const int opusSignalVoice = 3001;

/// -------------------- Native FFI Type Definitions --------------------

typedef OpusDecoderCreateNative = Pointer Function(Int32 sampleRate, Int32 channels, Pointer<Int32> error);
typedef OpusDecoderCreate = Pointer Function(int sampleRate, int channels, Pointer<Int32> error);

typedef OpusDecodeNative = Int32 Function(
    Pointer decoder, Pointer<Uint8> data, Int32 len, Pointer<Int16> pcm, Int32 frameSize, Int32 decodeFec);
typedef OpusDecode = int Function(
    Pointer decoder, Pointer<Uint8> data, int len, Pointer<Int16> pcm, int frameSize, int decodeFec);

typedef OpusDecoderDestroyNative = Void Function(Pointer decoder);
typedef OpusDecoderDestroy = void Function(Pointer decoder);

typedef OpusEncoderCreateNative = Pointer Function(
    Int32 sampleRate, Int32 channels, Int32 application, Pointer<Int32> error);
typedef OpusEncoderCreate = Pointer Function(
    int sampleRate, int channels, int application, Pointer<Int32> error);

typedef OpusEncodeNative = Int32 Function(Pointer encoder, Pointer<Int16> pcm,
    Int32 frameSize, Pointer<Uint8> data, Int32 maxDataBytes);
typedef OpusEncode = int Function(Pointer encoder, Pointer<Int16> pcm,
    int frameSize, Pointer<Uint8> data, int maxDataBytes);

typedef OpusEncoderDestroyNative = Void Function(Pointer encoder);
typedef OpusEncoderDestroy = void Function(Pointer encoder);

typedef OpusEncoderCtlNative = Int32 Function(Pointer encoder, Int32 request, Int32 value);
typedef OpusEncoderCtl = int Function(Pointer encoder, int request, int value);

/// -------------------- MumbleAudioCodec --------------------

class MumbleAudioCodec {
  static DynamicLibrary? _lib;

  static DynamicLibrary _loadLibrary() {
    if (_lib != null) return _lib!;
    
    if (Platform.isAndroid) {
       _lib = DynamicLibrary.open('libopus.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
       _lib = DynamicLibrary.process();
    } else {
       throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
    return _lib!;
  }

  // Decoders
  static final OpusDecoderCreate _opusDecoderCreate = _loadLibrary()
      .lookup<NativeFunction<OpusDecoderCreateNative>>('opus_decoder_create').asFunction();
  static final OpusDecode _opusDecode = _loadLibrary()
      .lookup<NativeFunction<OpusDecodeNative>>('opus_decode').asFunction();
  static final OpusDecoderDestroy _opusDecoderDestroy = _loadLibrary()
      .lookup<NativeFunction<OpusDecoderDestroyNative>>('opus_decoder_destroy').asFunction();

  // Encoders
  static final OpusEncoderCreate _opusEncoderCreate = _loadLibrary()
      .lookup<NativeFunction<OpusEncoderCreateNative>>('opus_encoder_create').asFunction();
  static final OpusEncode _opusEncode = _loadLibrary()
      .lookup<NativeFunction<OpusEncodeNative>>('opus_encode').asFunction();
  static final OpusEncoderDestroy _opusEncoderDestroy = _loadLibrary()
      .lookup<NativeFunction<OpusEncoderDestroyNative>>('opus_encoder_destroy').asFunction();
  static final OpusEncoderCtl _opusEncoderCtl = _loadLibrary()
      .lookup<NativeFunction<OpusEncoderCtlNative>>('opus_encoder_ctl').asFunction();
}

class MumbleOpusDecoder {
  Pointer? _decoder;
  final int sampleRate;
  final int channels;

  MumbleOpusDecoder({required this.sampleRate, required this.channels}) {
    final errorPtr = malloc<Int32>();
    try {
      _decoder = MumbleAudioCodec._opusDecoderCreate(sampleRate, channels, errorPtr);
      if (errorPtr.value != opusOk || _decoder == nullptr) {
        throw Exception('Failed to create Opus decoder: ${errorPtr.value}');
      }
    } finally {
      malloc.free(errorPtr);
    }
  }

  Int16List decode(Uint8List opusData, int frameSize) {
    if (_decoder == null) throw StateError('Decoder disposed');

    final inputPtr = malloc<Uint8>(opusData.length);
    final outputPtr = malloc<Int16>(frameSize * channels);
    try {
      inputPtr.asTypedList(opusData.length).setAll(0, opusData);

      final samplesDecoded = MumbleAudioCodec._opusDecode(
        _decoder!, inputPtr, opusData.length, outputPtr, frameSize, 0);

      if (samplesDecoded < 0) {
        throw Exception('Opus decode fatal error: $samplesDecoded');
      }

      return Int16List.fromList(outputPtr.asTypedList(samplesDecoded * channels));
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  void dispose() {
    if (_decoder != null) {
      MumbleAudioCodec._opusDecoderDestroy(_decoder!);
      _decoder = null;
    }
  }
}

class MumbleOpusEncoder {
  Pointer? _encoder;
  final int sampleRate;
  final int channels;

  MumbleOpusEncoder({required this.sampleRate, required this.channels, int application = opusApplicationVoip}) {
    final errorPtr = malloc<Int32>();
    try {
      _encoder = MumbleAudioCodec._opusEncoderCreate(sampleRate, channels, application, errorPtr);
      if (errorPtr.value != opusOk || _encoder == nullptr) {
        throw Exception('Failed to create Opus encoder: ${errorPtr.value}');
      }
      
      // Default configurations for quality and reliability
      setBitrate(48000);
      setComplexity(5); // Reduced from 10 to 5 for better mobile performance
      setVbr(true);
      setInbandFec(true);
      setPacketLossPercentage(10);
      setSignal(opusSignalVoice);
    } finally {
      malloc.free(errorPtr);
    }
  }

  void setBitrate(int bitrate) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetBitrateRequest, bitrate);
    }
  }

  void setComplexity(int complexity) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetComplexityRequest, complexity);
    }
  }

  void setVbr(bool vbr) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetVbrRequest, vbr ? 1 : 0);
    }
  }

  void setInbandFec(bool enabled) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetInbandFecRequest, enabled ? 1 : 0);
    }
  }

  void setPacketLossPercentage(int percentage) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetPacketLossPercRequest, percentage);
    }
  }

  void setSignal(int signal) {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderCtl(_encoder!, opusSetSignalRequest, signal);
    }
  }

  Uint8List encode(Int16List pcmData, int frameSize) {
    if (_encoder == null) throw StateError('Encoder disposed');

    final inputPtr = malloc<Int16>(pcmData.length);
    const maxOutputSize = 4000;
    final outputPtr = malloc<Uint8>(maxOutputSize);
    try {
      inputPtr.asTypedList(pcmData.length).setAll(0, pcmData);

      final bytesEncoded = MumbleAudioCodec._opusEncode(
        _encoder!, inputPtr, frameSize, outputPtr, maxOutputSize);

      if (bytesEncoded < 0) {
        throw Exception('Opus encode fatal error: $bytesEncoded');
      }

      return Uint8List.fromList(outputPtr.asTypedList(bytesEncoded));
    } finally {
      malloc.free(inputPtr);
      malloc.free(outputPtr);
    }
  }

  void dispose() {
    if (_encoder != null) {
      MumbleAudioCodec._opusEncoderDestroy(_encoder!);
      _encoder = null;
    }
  }
}
