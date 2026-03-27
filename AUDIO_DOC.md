# Audio Pipeline Documentation

The Rumble application now uses a Rust-based Mumble client (`RustMumbleClient`) to handle all aspects of the Mumble protocol, including low-latency audio capture and playback.

## Recording & Sending (Outgoing)

- **Library**: Handled by the Rust core via `CapturePipeline`.
- **PTT**: Controlled via `RustMumbleClient.setPtt()`.
- **Devices**: Input devices are listed via `listAudioInputDevices()`.

## Receiving & Playing (Incoming)

- **Library**: Handled by the Rust core via `PlaybackMixer` and `UserVoiceStream`.
- **Mechanism**: The Rust client manages its own audio output buffers and streams, interfacing directly with the system's audio drivers for minimum latency.
- **Jitter Buffer**: Software-level buffering before decoding, controlled by `incomingJitterBufferMs`. Implementation uses a proactive notification strategy from the hardware callback to avoid starvation.
- **Output Delay (Hardware Buffer)**: Low-level OS buffer size (`playbackHwBufferSize`). Increasing this helps avoid clicks on high-latency mobile hardware.
- **Devices**: Output devices are listed via `listAudioOutputDevices()`.

## Key Implementation Lessons

- **Proactive Filling**: The decode thread should be notified to fill the ring buffer on **every** hardware callback, not just when empty. Waiting for an empty buffer causes a "click" due to the tiny processing delay (Opus decode) before audio resumes.
- **Graceful Overflows**: Clock drift between devices can cause buffer pileup. Implementation uses a "tail-drop" strategy for the jitter buffer—dropping the oldest packet instead of panicking when full.
- **Android Binary Size**: Debugging over Flutter on high-end Android devices (like Samsung S24) may fail with `invalid shdr offset` if the debug Rust `.so` is too large (>100MB). **Profile/Release builds** or setting `android:extractNativeLibs="true"` in `AndroidManifest.xml` are required for stability.
- **Ring Buffer Headroom**: The internal output ring buffer should have significant headroom (at least 500ms+) compared to the user's jitter setting to accommodate bursts and prevent clipping.

## Benefits of the Rust Implementation

- **Low Latency**: Bypassing the Flutter-to-Native bridge for audio samples significantly reduces latency.
- **Mixed Streams**: Rust handles mixing multiple user audio streams efficiently.
- **Protocol Fidelity**: Full Mumble protocol support including Opus encoding/decoding is managed within the same context as the network packets.
