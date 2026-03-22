import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:rumble/src/rust/api/opus.dart';

// Opus Constants
const int opusOk = 0;
const int opusApplicationVoip = 2048;
const int opusApplicationAudio = 2049;
const int opusApplicationLowDelay = 2051;

/// A wrapper around a FFI-allocated Int16List that is managed manually.
class FfiInt16Buffer {
  final int capacity;
  late final Pointer<Int16> pointer;
  late final Int16List list;

  FfiInt16Buffer(this.capacity) {
    pointer = malloc.allocate<Int16>(capacity * Int16List.bytesPerElement);
    list = pointer.asTypedList(capacity);
  }

  void dispose() {
    malloc.free(pointer);
  }
}

/// A wrapper around a FFI-allocated Uint8List that is managed manually.
class FfiUint8Buffer {
  final int capacity;
  late final Pointer<Uint8> pointer;
  late final Uint8List list;

  FfiUint8Buffer(this.capacity) {
    pointer = malloc.allocate<Uint8>(capacity);
    list = pointer.asTypedList(capacity);
  }

  void dispose() {
    malloc.free(pointer);
  }
}

class MumbleOpusDecoder {
  RustOpusDecoder? _decoder;
  final int sampleRate;
  final int channels;

  // Persistent FFI buffers
  late final FfiInt16Buffer _outputBuffer;
  late final FfiUint8Buffer _inputBuffer;

  static const int _maxFrameSize = 5760;
  static const int _maxInputSize = 4000;

  MumbleOpusDecoder({required this.sampleRate, required this.channels}) {
    _init();
    _outputBuffer = FfiInt16Buffer(_maxFrameSize * channels);
    _inputBuffer = FfiUint8Buffer(_maxInputSize);
  }

  void _init() {
    _decoder = RustOpusDecoder(
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  /// Decodes opus data into the internal FFI buffer and returns a VIEW of it.
  Int16List decode(Uint8List opusData, int frameSize) {
    if (_decoder == null) return Int16List(0);

    final inputLen = opusData.length.clamp(0, _maxInputSize);
    _inputBuffer.list.setRange(0, inputLen, opusData);

    final samples = _decoder!.decodeRaw(
      opusPtr: BigInt.from(_inputBuffer.pointer.address),
      opusLen: inputLen,
      outputPtr: BigInt.from(_outputBuffer.pointer.address),
      frameSize: frameSize,
    );

    if (samples <= 0) return Int16List(0);
    return _outputBuffer.list.buffer.asInt16List(0, samples * channels);
  }

  void dispose() {
    _decoder = null;
    _outputBuffer.dispose();
    _inputBuffer.dispose();
  }
}

class MumbleOpusEncoder {
  RustOpusEncoder? _encoder;
  final int sampleRate;
  final int channels;

  // Persistent FFI buffers
  late final FfiUint8Buffer _outputBuffer;
  late final FfiInt16Buffer _inputBuffer;

  static const int _maxOutputSize = 4000;
  static const int _maxInputSize = 5760;

  MumbleOpusEncoder({
    required this.sampleRate,
    required this.channels,
    int application = opusApplicationVoip,
  }) {
    _init(application);
    _outputBuffer = FfiUint8Buffer(_maxOutputSize);
    _inputBuffer = FfiInt16Buffer(_maxInputSize);
  }

  void _init(int application) {
    _encoder = RustOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: application,
    );
    setBitrate(48000);
    setComplexity(5);
    setVbr(true);
    setInbandFec(true);
  }

  void setBitrate(int bitrate) {
    _encoder?.setBitrate(bitrateBps: bitrate);
  }

  void setComplexity(int complexity) {
    _encoder?.setComplexity(complexity: complexity);
  }

  void setVbr(bool vbr) {
    _encoder?.setVbr(vbr: vbr);
  }

  void setInbandFec(bool enabled) {
    _encoder?.setInbandFec(enabled: enabled);
  }

  void setPacketLossPercentage(int percentage) {
    _encoder?.setPacketLossPerc(percentage: percentage);
  }

  /// Encodes PCM data into the internal FFI buffer and returns a VIEW of it.
  Uint8List encode(Int16List pcmData, int frameSize) {
    if (_encoder == null) return Uint8List(0);

    final inputLen = pcmData.length.clamp(0, _maxInputSize);
    _inputBuffer.list.setRange(0, inputLen, pcmData);

    final len = _encoder!.encodeRaw(
      pcmPtr: BigInt.from(_inputBuffer.pointer.address),
      pcmLen: inputLen,
      outputPtr: BigInt.from(_outputBuffer.pointer.address),
      outputCapacity: _maxOutputSize,
    );

    if (len <= 0) return Uint8List(0);
    return _outputBuffer.list.buffer.asUint8List(0, len);
  }

  void dispose() {
    _encoder = null;
    _outputBuffer.dispose();
    _inputBuffer.dispose();
  }
}
