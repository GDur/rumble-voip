# Rumble: Rust Audio Engine Mandates

The Rust component is the performance-critical core of Rumble, responsible for high-fidelity, low-latency audio processing and network synchronization across macOS, Windows, iOS, and Android.

## Performance and Latency Standards

1. **Zero-Allocation Hot Path**
   - The audio hardware callback (`hardware/audio.rs`) and the DSP processing loop (`dsp/capture.rs`, `dsp/playback.rs`) must not perform any memory allocations or deallocations.
   - Utilize `heapless::Vec` or pre-allocated buffers for temporary storage.
   - Initialization-time allocations (using `Box`) are permitted, but these must be completed before the audio stream starts.

2. **Lock-Free Communication**
   - Communication between hardware threads (CPAL) and DSP/Network threads must use lock-free primitives.
   - Use `ringbuf` for PCM data transmission.
   - Use `crossbeam-channel` or `Atomic` types for control signals and metadata.
   - Standard `Mutex` or `RwLock` primitives are strictly prohibited within the audio callback.

3. **Real-Time Thread Integrity**
   - The hardware callback must remain non-blocking. Never perform I/O, networking, or heavy synchronization in the `cpal` callback.
   - The callback should prioritize moving data to/from ring buffers and notifying processing threads via non-blocking channels.

4. **Audio Processing Pipeline (sonora)**
   - **Capture**: Apply WebRTC's AEC3, Noise Suppression (NS), and Automatic Gain Control (AGC2) via the `sonora` crate.
   - **Reference Sync**: The `PlaybackMixer` must provide reference frames to the `CapturePipeline` for effective Acoustic Echo Cancellation (AEC).
   - **Jitter Buffer**: Implement a proactive jitter buffer to mitigate network variance while maintaining low latency. Follow the notification strategy outlined in `AUDIO_DOC.md`.

5. **Codec and Resampling**
   - **Opus Only**: Strictly support the Opus codec at 48kHz.
   - **Resampling**: Use `PushSincResampler` for hardware interfaces requiring sample rates other than the internal 48kHz processing rate.

## Build and Safety Mandates

1. **Android Binary Size Constraint**
   - Debug builds of the Rust library must be monitored. If the .so file exceeds 100MB, it may cause "invalid shdr offset" errors on certain high-end Android devices.
   - Use Profile or Release builds for testing on hardware if this occurs, or ensure `android:extractNativeLibs="true"` is set in the AndroidManifest.xml.

2. **Memory Safety and Unsafe Code**
   - Minimize the use of `unsafe`. Where `unsafe` is required (e.g., for `Send`/`Sync` implementations of `cpal` types), it must be accompanied by a safety comment explaining why the invariant is upheld.

3. **Error Handling**
   - Use `anyhow` for top-level application logic to provide rich context.

## Project Structure

- `src/api/`: Flutter-Rust Bridge (FRB) API definitions. Changes here require running `just gen` from the project root.
- `src/mumble/dsp/`: Core audio processing logic, including mixers and user streams.
- `src/mumble/hardware/`: CPAL integration and device lifecycle management.
- `src/mumble/net/`: Mumble UDP protocol, encryption, and packet handling.
- `src/mumble/codec/`: Opus encoder/decoder abstractions.

## Validation and Maintenance

- **Testing**: Run `cargo test` for DSP logic validation and utilize automated audio integrity tests (frequency analysis).
- **Tooling**: Use `just lint` (clippy) to ensure idiomatic code and strict type safety.
- **Profiling & Platform Support**: Monitor binary size and CPU usage, especially for Android and iOS builds, to ensure the engine remains efficient on mobile hardware. Verify audio hardware compatibility across macOS and Windows via CPAL.
