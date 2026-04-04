# Changelog

## [0.19.0] - 2026-04-04
- feat: implement animated avatar zoom on hover in channel tree

- Add ZoomableAvatar widget with Overlay zoom transition
- Show avatar 3x bigger when hovered with easing effect
- Sync status color border with zoomed version

## [0.18.0] - 2026-04-04
- feat: per-server certificate management and user registration flow

- Added certificateId to MumbleServer model
- Added certificate selection to server dialog
- Updated connection logic to prioritize server-specific certificates
- Implemented golden shield indicator for registered users in ChannelTree
- Added 'Register to Server' action with confirmation in context menu
- Extended Rust API with registration status fields and regenerated bridge

## [0.17.0] - 2026-04-04
- feat: per-server certificate management and user registration flow

- Added certificateId to MumbleServer model
- Added certificate selection to server dialog
- Updated connection logic to prioritize server-specific certificates
- Implemented golden shield indicator for registered users in ChannelTree
- Added 'Register to Server' action with confirmation in context menu
- Extended Rust API with registration status fields and regenerated bridge

## [0.16.0] - 2026-04-04
- feat: add 'set/change avatar' to user context menu

## [0.15.1] - 2026-04-03
- fix: test

## [0.15.0] - 2026-04-03
- feat: integrate acoustic echo cancellation into audio pipeline

- Implement WebRTC's AEC3 via sonora library in the Rust audio engine.
- Synchronize playback reference frames with the capture pipeline.
- Expose AEC toggle control in mumble_service and main UI.
- Update Flutter-Rust Bridge generated bindings.

## [0.14.1] - 2026-04-01
- fix: resolve case-sensitive Justfile vs justfile collision in index

## [0.14.0] - 2026-04-01
- feature: easier build commands

## [0.13.3] - 2026-04-01
- fix: resolve markNeedsBuild build-phase error and ensure certs are loaded before autoconnect

## [0.13.2] - 2026-03-31
- docs: add screenshots to README and emphasize open source and free model

## [0.13.1] - 2026-03-31
- fix: certificate p12 import fallback using openssl by disabling debug sandbox and adding error toasts

## [0.13.0] - 2026-03-31
- feat: add markdown chat support, update build docs, and app icons

## [0.12.0] - 2026-03-31
- feat: add 3-second countdown dialog before auto-connecting to last server

## [0.11.0] - 2026-03-28
- feat: implement automated audio integrity testing with Rust debug hooks and frequency analysis

## [0.10.2] - 2026-03-28
- refactor: decouple MumbleService from native audio for testing and expand test suite

- Introduced DeviceLister abstraction to enable audio device mocking.
- Refactored MumbleService for dependency injection of RustAudioEngine and DeviceLister.
- Added SettingsService unit tests for persistence and defaults.
- Added ChannelTree widget tests for hierarchical rendering and filtering.
- Fixed settings_navigation_test.dart and server_management_test.dart stability issues.
- Removed obsolete test/widget_test.dart boilerplate.

## [0.10.1] - 2026-03-28
- fix: configure iOS AVAudioSession for microphone access and improve connection error reporting

## [0.10.0] - 2026-03-28
- feat: standardize tooltips and restructure settings dialog with persistent footer

## [0.9.0] - 2026-03-28
- feat: expand hotkey support with multi-key combinations and native Windows/macOS enhancements

## [0.8.0] - 2026-03-28
- feat: implement chat unread notifications badge

## [0.7.0] - 2026-03-28
- feat: split audio settings into dedicated Input and Output tabs in the settings dialog.

## [0.6.0] - 2026-03-28
- feat: implement immediate channel/user selection using PointerDown and unify hover effects. Refined channel tree layout.

## [0.5.0] - 2026-03-28
- feat: remove bold user labels during voice activity and fix PTT only working once by guarding audio initialization. Request mic permissions at app startup.

## [0.4.1] - 2026-03-28
- fix: reverted permissions because of ptt regression

## [0.4.0] - 2026-03-28
- feat: request microphone permissions immediately at app startup

## [0.3.0] - 2026-03-28
- feat: implement automated versioning system

