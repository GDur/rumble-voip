import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_opus/flutter_opus.dart';

// export the OpusDemoPage
class OpusDemoPage extends StatefulWidget {
  const OpusDemoPage({super.key});

  @override
  State<OpusDemoPage> createState() => _OpusDemoPageState();
}

class _OpusDemoPageState extends State<OpusDemoPage> {
  String _log = '';

  void _appendLog(String text) {
    setState(() {
      _log += '$text\n';
    });
  }

  Future<void> _runTest() async {
    setState(() {
      _log = 'Running Opus encode/decode test...\n';
    });

    const sampleRate = 16000;
    const channels = 1;
    const frameSize = 320; // 20ms frame @ 16kHz

    // 1. 创建编码器
    final encoder =
        OpusEncoder.create(sampleRate: sampleRate, channels: channels);
    if (encoder == null) {
      _appendLog('Failed to create encoder');
      return;
    }
    encoder.setBitrate(64000);
    encoder.setComplexity(5);
    _appendLog('Encoder created.');

    // 2. 创建解码器
    final decoder =
        OpusDecoder.create(sampleRate: sampleRate, channels: channels);
    if (decoder == null) {
      _appendLog('Failed to create decoder');
      encoder.dispose();
      return;
    }
    _appendLog('Decoder created.');

    // 3. 准备 PCM 数据 (简单正弦波)
    final Int16List pcmData = Int16List(frameSize * channels);
    const frequency = 440; // 440Hz A音符
    for (int i = 0; i < pcmData.length; i++) {
      pcmData[i] = (sin(2 * pi * frequency * i / sampleRate) * 32767).toInt();
    }
    _appendLog('PCM data prepared.');

    try {
      // 4. 编码
      final encodedData = encoder.encode(pcmData, frameSize);
      if (encodedData == null) {
        _appendLog('Encoding failed');
        return;
      }
      _appendLog('Encoded data length: ${encodedData.length} bytes');

      // 5. 解码
      final decodedPcm = decoder.decode(encodedData, frameSize);
      if (decodedPcm == null) {
        _appendLog('Decoding failed');
        return;
      }
      _appendLog('Decoded PCM length: ${decodedPcm.length} bytes');

      // 6. 打印前10个样本值
      _appendLog('First 10 decoded samples:');
      for (int i = 0; i < 10 * channels; i++) {
        int sample =
            decodedPcm[i * 2] | (decodedPcm[i * 2 + 1] << 8); // Little-endian
        _appendLog('Sample $i: $sample');
      }
    } catch (e) {
      _appendLog('Error during encode/decode: $e');
    } finally {
      // 7. 释放资源
      encoder.dispose();
      decoder.dispose();
      _appendLog('Resources disposed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opus Encode/Decode Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _runTest,
              child: const Text('Run Test'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
