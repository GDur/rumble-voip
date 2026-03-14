# flutter_opus

A Flutter plugin for Opus audio codec encoding and decoding using FFI (Foreign Function Interface).

## Features

- ✅ Opus audio decoding
- ✅ Opus audio encoding
- ✅ iOS support with static library
- ✅ macOS support with static library
- ✅ Android support with shared library 
- ✅ Pure Dart API using FFI
- ✅ Memory efficient
- ✅ Low latency

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_opus: ^latest
```

## Usage

### Decoding Opus Data

```dart
import 'package:flutter_opus/flutter_opus.dart';

// Create the decoder
final decoder = OpusDecoder.create(
  sampleRate: 48000,
  channels: 1,
);

// Decode Opus data (Uint8List) to PCM (Uint8List)
final pcmData = decoder?.decode(opusData, frameSize);

decoder?.dispose(); // Dispose decoder when done
```

### Encoding PCM Data

```dart
import 'package:flutter_opus/flutter_opus.dart';

// Create the decoder
final decoder = OpusDecoder.create(
  sampleRate: 48000,
  channels: 1,
);

// Decode Opus data (Uint8List) to PCM (Uint8List)
final pcmData = decoder?.decode(opusData, frameSize);

decoder?.dispose(); // Dispose decoder when done
```

### Get Version

```dart
final version = OpusDecoder.getVersion();
print('Opus version: $version');
```

## Supported Platforms

- ✅ iOS (with Opus static library)
- ✅ Android (coming soon)
- ❌ macOS (coming soon)
- ❌ Windows (coming soon)
- ❌ Linux (coming soon)

## Requirements

### iOS

- iOS 12.0 or later
- Opus static library (`libopus.a`) compiled for iOS architectures

### Android
- Android 5.0 (API 21) or later
- Requires Opus shared library (libopus.so) bundled in the APK

## Example

See the [example](example/) directory for a complete working example.

## API Reference

### OpusDecoder

- `OpusDecoder.create({required int sampleRate, required int channels})` - Create decoder
- `decode(Uint8List opusData, int frameSize)` - Decode Opus data to PCM
- `dispose()` - Free resources
- `OpusDecoder.getVersion()` - Get Opus library version

### OpusEncoder

- `OpusEncoder.create({required int sampleRate, required int channels, int application})` - Create encoder
- `encode(Int16List pcmData, int frameSize)` - Encode PCM data to Opus
- `setBitrate(int bitrate)` - Set encoding bitrate
- `setComplexity(int complexity)` - Set encoding complexity (0-10)
- `dispose()` - Free resources

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.