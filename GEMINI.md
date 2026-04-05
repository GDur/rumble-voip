# Rumble: Mumble-Compatible Client

Rumble is a high-performance Mumble client utilizing a Flutter-based user interface and a specialized Rust-based audio engine for low-latency communication.

**Supported Platforms:** macOS, Windows, iOS, and Android.

## Architecture and Integration

- **Frontend (Dart/Flutter)**: Manages the UI, server state, and Mumble control protocol via the `dumble` library.
- **Audio Engine (Rust)**: Located in `./rust`, this component handles hardware-level audio capture/playback, Opus encoding/decoding, and high-speed UDP voice packet transmission.
- **Bridge**: Integration is facilitated by `flutter_rust_bridge`, providing type-safe communication between Dart and Rust.

## Technical Stack

- **Dart/Flutter**:
  - `dumble`: Mumble protocol implementation.
  - `provider`: Application state management.
- **Rust Core**:
  - `cpal`: Cross-platform hardware audio access.
  - `sonora`: WebRTC-based audio processing (AEC3, Noise Suppression, AGC2, HPF).
  - `opus`: High-quality, low-latency audio codec (strictly Opus only).
  - `ringbuf` & `crossbeam-channel`: Lock-free communication between hardware and processing threads.

## Development Standards

### Flutter/Dart Conventions

- **Syntax**: Avoid semicolons unless syntactically mandatory.
- **Documentation**: Place all code comments on the line immediately ABOVE the target code.
- **Icons**: Utilize the `LucideIcons` package for all UI elements.
- **State Management**: Adhere to the Service pattern. Core logic resides in `MumbleService` (connection/audio), `SettingsService` (persistence), and `CertificateService` (identity).

### Security

- **Credentials**: Never log or commit user certificates (.p12) or private keys. Rigorously protect the `CertificateService` implementation and any sensitive memory in the Rust core.

## Workflow Automation (Justfile)

Common development tasks are managed via the `just` command, as defined in `Justfile`:

- `just gen`: Regenerate the Flutter-Rust bridge bindings (required after modifying Rust API).
- `just go`: Clean workspace and fetch all dependencies.
- `just test`: Execute both Flutter widget/unit tests and Rust crate tests.
- `just lint`: Run Rust clippy with automatic fixes.
- `just release-[platform]`: Build production binaries (e.g., `just release-macos`, `just release-windows`, `just release-ios`, `just release-android`).

## Documentation Index

- [AUDIO_DOC.md](./AUDIO_DOC.md): Details on the audio pipeline, jitter buffer strategy, and hardware considerations.
- [DESIGN.md](./DESIGN.md): UI/UX principles, component guidelines, and branding.
- [SPECIFICATION.md](./SPECIFICATION.md): Technical requirements and Mumble protocol implementation details.
- [rust/GEMINI.md](./rust/GEMINI.md): Mandates for the Rust audio engine and performance-critical code.

---

Note: This project strictly supports the Opus codec. Support for older Mumble codecs (CELT, Speex) is intentionally omitted.
