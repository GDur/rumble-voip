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

# Release a new version (e.g., just release 0.20.0). This validates semver, ensures main branch, increments build number, updates pubspec.yaml, commits, and tags for CI/CD.
release version:
    #!/usr/bin/env bash
    set -euo pipefail

    # 1. Validate version format (X.Y.Z)
    if [[ ! "{{ version }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must be in X.Y.Z format (e.g., 0.20.0). Found '{{ version }}'."
        exit 1
    fi

    # 2. Check branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ]; then
        echo "Error: Releases can only be made from the 'main' branch (current: $CURRENT_BRANCH)."
        exit 1
    fi

    # 3. Parse current version and build number from pubspec.yaml
    # We find the line starting with version: and extract the parts
    FULL_VERSION_LINE=$(grep "^version: " pubspec.yaml)
    CURRENT_FULL_VERSION=${FULL_VERSION_LINE#version: }
    CURRENT_VERSION=${CURRENT_FULL_VERSION%+*}
    CURRENT_BUILD=${CURRENT_FULL_VERSION#*+}

    # 4. Compare versions
    # Use a simple function to convert X.Y.Z to a comparable integer
    function version_to_int() {
        echo "$1" | awk -F. '{ printf("%d%03d%03d", $1,$2,$3); }'
    }

    if [ $(version_to_int "{{ version }}") -le $(version_to_int "$CURRENT_VERSION") ]; then
        echo "Error: New version {{ version }} must be greater than current version $CURRENT_VERSION."
        exit 1
    fi

    # 5. Increment build number
    NEW_BUILD=$((CURRENT_BUILD + 1))
    NEW_FULL_VERSION="{{ version }}+$NEW_BUILD"

    echo "Releasing $NEW_FULL_VERSION (Old: $CURRENT_FULL_VERSION)..."

    # 6. Update pubspec.yaml (using perl for cross-platform compatibility without empty strings)
    perl -pi -e "s/^version: .*/version: $NEW_FULL_VERSION/" pubspec.yaml

    # 7. Commit, Tag, and Push
    git add pubspec.yaml
    git commit -m "chore: bump version to $NEW_FULL_VERSION"
    git tag "v{{ version }}"
    git push origin main
    git push origin "v{{ version }}"

    echo "Successfully released $NEW_FULL_VERSION and pushed tag v{{ version }}."

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
