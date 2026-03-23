# Audio Pipeline Documentation

The Rumble application now uses a Rust-based Mumble client (`RustMumbleClient`) to handle all aspects of the Mumble protocol, including low-latency audio capture and playback.

## Recording & Sending (Outgoing)

- **Library**: Handled by the Rust core.
- **PTT**: Controlled via `RustMumbleClient.setPtt()`.
- **Devices**: Input devices are listed via `listAudioInputDevices()`.

## Receiving & Playing (Incoming)

- **Library**: Handled by the Rust core.
- **Mechanism**: The Rust client manages its own audio output buffers and streams, interfacing directly with the system's audio drivers for minimum latency.
- **Devices**: Output devices are listed via `listAudioOutputDevices()`.

## Benefits of the Rust Implementation
- **Low Latency**: Bypassing the Flutter-to-Native bridge for audio samples significantly reduces latency.
- **Mixed Streams**: Rust handles mixing multiple user audio streams efficiently.
- **Protocol Fidelity**: Full Mumble protocol support including Opus encoding/decoding is managed within the same context as the network packets.
