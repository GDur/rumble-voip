# 🚀 Dockerized Build & Development Guide for Rumble

This setup provides a consistent environment for building and testing **Rumble** (Flutter + Rust) for **Android**, **Linux**, and **Web**.

> [!IMPORTANT]
> **macOS** and **iOS** apps must still be built on a physical Mac using Xcode. **Windows** apps must be built on a Windows host. Docker provides the environment for everything else.

---

## 🛠 1. Moving Docker Storage to External Drive (4TB)

Since you have limited space on your main drive (10GB), you **MUST** move Docker's data storage to your external hard drive before building the image (which can be >5GB).

### On macOS (Docker Desktop):
1.  Connect your external hard drive.
2.  Open **Docker Desktop Settings**.
3.  Navigate to **Settings** > **Resources** > **Disk image location**.
4.  Click **Move** and select a folder on your external drive.
5.  Docker will restart and move all existing containers/images/volumes there.

### On Windows (Docker Desktop):
1.  Connect your external hard drive.
2.  Open **Docker Desktop Settings**.
3.  Navigate to **Settings** > **Resources** > **Advanced**.
4.  Change the **Disk image location** to your external drive.
5.  Apply and Restart.

---

## 📦 2. Getting Started

Once Docker is pointed to the external drive, run the following:

```bash
# Build the dev environment image
docker-compose build

# Start the builder container in the background
docker-compose up -d
```

---

## 🏗 3. Building Release Versions

You can now use the container to build Android APKs or Linux binaries without cluttering your main OS.

### Build Android APK:
```bash
docker-compose exec builder flutter build apk --release
```

### Build Linux Desktop:
```bash
docker-compose exec builder flutter build linux --release
```

### Build Web:
```bash
docker-compose exec builder flutter build web --release --base-href /rumble/
```

---

## 🐞 4. Debugging & Tools

You can also run analyzer, tests, and code generation from within the container to ensure they work in a clean environment.

```bash
# Generate Rust bridges
docker-compose exec builder just gen

# Run tests
docker-compose exec builder just test

# Enter the shell for manual debugging
docker-compose exec builder bash
```

---

## 💾 5. Why use Docker?

-   **Zero Installation**: Other developers only need Docker to start building/testing.
-   **No "Works on my machine"**: The build environment is identical for everyone.
-   **CI/CD Ready**: This same Dockerfile can be used in GitHub Actions or GitLab CI.
-   **Offloads Space**: All caches (Flutter packages, Cargo dependencies, Rust build artifacts) are stored in Docker volumes on your **External Drive**.
