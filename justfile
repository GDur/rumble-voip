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
# --- Full Project Orchestration ---

# Build everything (Host, Docker/Colima, and VM/Quickemu) - THE HOLY GRAIL
build-all:
    @echo "🚀 Starting Full Project Build for ALL platforms..."
    @echo "📦 [1/4] Building macOS release..."
    just release-macos
    @echo "🐳 [2/4] Building Android & Linux in Docker (Colima)..."
    just docker-release apk
    just docker-release linux
    @echo "🪟 [3/4] Triggering Windows VM build (if running)..."
    @echo "Note: Windows build requires the VM to be running and SSH enabled."
    # just windows-vm-build
    @echo "✅ Build complete! Check 'build/' on both Host and VMs."

# --- VM Management ---

# Start all build environments
vms-up:
    colima start --cpu 4 --memory 8 --vm-type vz --vz-rosetta
    cd "/Volumes/Raid 1 4TB/vms/windows" && quickemu --vm windows-11-arm64.conf --display none &

# Stop all build environments
vms-down:
    colima stop
    # killall qemu-system-aarch64 # or manage quickemu properly

# --- Docker Commands ---

# Build the Docker image (ensure Docker storage is on external drive!)
docker-build:
    docker-compose build

# Start the Docker builder container
docker-up:
    docker-compose up -d

# Stop the Docker builder container
docker-down:
    docker-compose down

# Open a shell in the builder container
docker-shell:
    docker-compose exec builder bash

# Build a release platform inside Docker (supported: android, linux, web)
docker-release platform:
    docker-compose exec builder flutter build {{ platform }} --release
