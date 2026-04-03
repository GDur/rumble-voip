# Base image with build dependencies
FROM ubuntu:24.04 AS developer

# Avoid interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Essential packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk-headless \
    wget \
    # Linux build dependencies
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$PATH
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    flutter precache --linux --android --web

# Install Rust
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH=$CARGO_HOME/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
# Install flutter_rust_bridge_codegen
RUN cargo install flutter_rust_bridge_codegen --version 2.11.1

# Install Android SDK (Command Line Tools)
# This is optional but needed for Android builds.
# Users can point to an external SDK too, but having it here makes it 'portable'.
ENV ANDROID_SDK_ROOT=/opt/android-sdk
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools && \
    mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest && \
    rm cmdline-tools.zip

ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH
# Accept licenses and install platform-tools/build-tools (this can take space!)
# We'll stick to a minimal set.
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Flutter config
RUN flutter config --no-analytics --enable-linux-desktop --enable-android --enable-web

# Entrypoint setup
WORKDIR /app
CMD ["bash"]
