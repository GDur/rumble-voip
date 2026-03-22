# Audio Pipeline Documentation (Opus & PCM)

This document outlines how the Rumble application handles high-quality, low-latency audio transmission and playback, specifically tailored for Mumble compatibility.

## Summary of Fixes
1.  **Alignment Fix**: Resolved a critical issue where 16-bit PCM bytes were misaligned during conversion, causing "noise" distortion.
2.  **macOS Support**: Created a custom FFI wrapper (`MumbleAudioCodec`) to load `libopus` via `DynamicLibrary.process()`, bypassing package limitations.
3.  **Latency & Choppiness**: Reduced Opus frame size to **10ms (480 samples)** and decreased encoder complexity to **5** to ensure stable performance on mobile devices.
4.  **Reliability**: Enabled **Forward Error Correction (FEC)** and **Variable Bitrate (VBR)** for better handling of network jitter.

---

## ⏺ Recording & Sending (Outgoing)

### 1. Capture (PCM 16-bit)
- **Library**: `record`
- **Config**: 48,000Hz, Mono, `AudioEncoder.pcm16bits`.
- **Workflow**: We start a continuous stream to monitor volume (for UI) but only encode/send data when the PTT button is active.

### 2. Processing (Alignment)
The stream provides a `Uint8List`. To treat these as 16-bit samples safely without `RangeError` (alignment issues):
```dart
final int16data = Uint8List.fromList(data).buffer.asInt16List();
```

### 3. Encoding (Opus)
- **Frame Size**: 480 samples (10ms @ 48kHz). Small frames reduce latency.
- **Complexity**: 5 (Balanced for mobile CPU).
- **Bitrate**: 48kbps (High-fidelity voice).
- **Signal**: Typed as `OPUS_SIGNAL_VOICE`.

---

## 🔊 Receiving & Playing (Incoming)

### 1. Buffering (Jitter Buffer)
Incoming `AudioFrame` streams are buffered per user. We use a **960-sample threshold (20ms)** before starting playback to account for network jitter.

### 2. Decoding (Opus to PCM)
- **Output**: 16-bit PCM samples.
- **Soft Clipping**: The decoder handles output levels to prevent digital distortion.

### 3. Playback (Low Latency)
- **Library**: `flutter_pcm_sound`
- **Mechanism**: Data is "fed" into the native buffer in 960-sample chunks.
- **Device Category**: Set to `playAndRecord` (iOS/macOS) to ensure the mic and speakers don't conflict or lower volume.

---

## 🛠 Native Rust Details
Rumble uses a custom Rust library (`rust_lib_rumble`) for Opus processing to ensure high performance and cross-platform compatibility.

We use `flutter_rust_bridge` to call the Rust methods:
- **Encoder**: Using `opus-rs` to encode PCM 16-bit directly.
- **Decoder**: Using `opus-rs` to decode Opus to PCM 16-bit directly.

We configure the stream in Rust:
- `set_bitrate`: Dynamically updates the bitrate.
- **Truncation**: The decoder output is truncated to the actual number of samples returned by `opus_decode` to prevent "choppy" stuttering caused by silence padding.

---
