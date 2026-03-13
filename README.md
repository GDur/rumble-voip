# Rumble 🎙️

**Rumble** is Mumble reloaded. A modern, high-performance voice chat client built with [Flutter](https://flutter.dev), designed to bring the power of the Mumble protocol to every device with a premium UI/UX.

## Philosophy
The goal of Rumble is to take the rock-solid reliability of Mumble and wrap it in a world-class user experience. No more clunky interfaces—just high-quality voice chat that looks and feels great.

## Key Features
- **Modern UI**: Powered by **shadcn_ui** for Flutter, providing a sleek, accessible, and customizable interface.
- **Cross-Platform**: A single codebase targeting all your devices.
- **High Performance**: Low-latency audio streaming using the Mumble protocol.

## Platform Support Matrix

| Platform | Works | Does not work |
| :--- | :---: | :---: |
| 📱 Android | x | |
| 🍎 iOS | | x |
| 💻 macOS | x | |
| 🪟 Windows | | x |
| 🌐 Web | | x |


## Tech Stack
- **Framework**: Flutter
- **UI System**: shadcn_ui (Flutter implementation)
- **Protocol**: Mumble

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Dart SDK

### Running the Project
```bash
# Get dependencies
flutter pub get

# Run on your preferred device
flutter run
```

### Building for Production
```bash
# Android
flutter build apk

# iOS
flutter build ios

# macOS
flutter build macos
```
