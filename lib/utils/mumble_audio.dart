import 'dart:typed_data';
import 'package:rumble/src/rust/api/opus.dart';

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

class MumbleOpusDecoder {
  RustOpusDecoder? _decoder;
  final int sampleRate;
  final int channels;

  MumbleOpusDecoder({required this.sampleRate, required this.channels}) {
    _init();
  }

  void _init() {
    _decoder = RustOpusDecoder(
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  Int16List decode(Uint8List opusData, int frameSize) {
    if (_decoder == null) throw StateError('Decoder not yet initialized');

    final result = _decoder!.decode(
      opusData: opusData,
      frameSize: frameSize,
    );
    return Int16List.fromList(result);
  }

  void dispose() {
    _decoder = null;
  }
}

class MumbleOpusEncoder {
  RustOpusEncoder? _encoder;
  final int sampleRate;
  final int channels;

  MumbleOpusEncoder({
    required this.sampleRate,
    required this.channels,
    int application = opusApplicationVoip,
  }) {
    _init(application);
  }

  void _init(int application) {
    _encoder = RustOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: application,
    );
    // Default configurations
    setBitrate(48000);
  }

  void setBitrate(int bitrate) {
    _encoder?.setBitrate(bitrateBps: bitrate);
  }

  void setComplexity(int complexity) {}
  void setVbr(bool vbr) {}
  void setInbandFec(bool enabled) {}
  void setPacketLossPercentage(int percentage) {}
  void setSignal(int signal) {}

  Uint8List encode(Int16List pcmData, int frameSize) {
    if (_encoder == null) throw StateError('Encoder not yet initialized');

    final result = _encoder!.encode(pcm: pcmData, frameSize: frameSize);
    return Uint8List.fromList(result);
  }

  void dispose() {
    _encoder = null;
  }
}
