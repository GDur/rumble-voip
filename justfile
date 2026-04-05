# Justfile for Rumble (Flutter + Rust)

# Default task: list all commands
default:
    @just --list

go:
    just clean
    flutter pub get

# Regenerate the Flutter-Rust bridge code
gen:
    rm -rf lib/src/rust && flutter_rust_bridge_codegen generate

# Clean Flutter and Rust build artifacts
clean:
    flutter clean
    cd rust && cargo clean

# Run all tests
test:
    flutter test
    cd rust && cargo test

fmt:
    cd rust && cargo fmt --all

lint:
    cd rust && cargo clippy --fix --allow-dirty

upgrade-deps:
    cd rust && cargo upgrade --incompatible

# Build for a specific platform or all platforms (e.g., just release macos)
release platform:
    {{ if platform == "all" { "just release-all" } else { "just release-" + platform } }}

# Build for macOS
release-macos:
    flutter build macos --release

# Build for iOS
release-ios:
    flutter build ios --release

# Build for Android
release-android:
    flutter build apk --release

# Build for Web - technically not possible to have mumble in the web
# release-web:
#     flutter build web --release

# Build for Linux - experimental
release-linux:
    flutter build linux --release

# Build for Windows - experimental
release-windows:
    flutter build windows --release

# Build all platforms
release-all:
    just release-macos
    just release-ios
    just release-android
    # just release-web
    # experimental
    just release-linux
    # experimental
    just release-windows
