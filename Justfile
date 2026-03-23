# Justfile for Rumble (Flutter + Rust)

# Default task: list all commands
default:
    @just --list

# Regenerate the Flutter-Rust bridge code
gen:
    flutter_rust_bridge_codegen generate

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
