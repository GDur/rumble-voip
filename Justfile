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

# Release a new patch version (increments Z in X.Y.Z)
release-patch message="":
    @VERSION=$(grep "^version: " pubspec.yaml | awk '{print $2}' | cut -d'+' -f1); \
    NEW_VERSION=$(echo $VERSION | awk -F. '{printf("%d.%d.%d", $1, $2, $3+1)}'); \
    just release $NEW_VERSION {{ quote(message) }}

# Release a new minor version (increments Y in X.Y.Z and resets Z to 0)
release-minor message="":
    @VERSION=$(grep "^version: " pubspec.yaml | awk '{print $2}' | cut -d'+' -f1); \
    NEW_VERSION=$(echo $VERSION | awk -F. '{printf("%d.%d.%d", $1, $2+1, 0)}'); \
    just release $NEW_VERSION {{ quote(message) }}

# Release a new version (e.g., just release 0.20.0 "Changelog message")
release version message="":
    ./scripts/version-management.sh {{ version }} {{ quote(message) }}

# Build for a specific platform or all platforms (e.g., just build macos)
build platform:
    {{ if platform == "all" { "just build-all" } else { "just build-" + platform } }}

# Build for macOS
build-macos:
    flutter build macos --release

# Build for iOS
build-ios:
    flutter build ios --release

# Build for Android
build-android:
    flutter build apk --release

# Build for Linux - experimental
build-linux:
    flutter build linux --release

# Build for Windows - experimental
build-windows:
    flutter build windows --release

# Build all platforms
build-all:
    just build-macos
    just build-ios
    just build-android
    # just build-web
    # experimental
    just build-linux
    # experimental
    build-windows
