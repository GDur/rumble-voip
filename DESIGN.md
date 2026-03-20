# Rumble Design & Component Guidelines

## Core Principles
- **Modern & Premium**: Use dark theme, glassmorphism, smooth animations, and curated color palettes.
- **Rumble Aesthetic**: Focus on the brand colors (`kBrandGreen`) and clean typography (Inter/Outfit).
- **Responsive**: All components should work on both Desktop and Mobile.

## Layout Components

### 1. Global Header (`_buildHeader`)
- **Logo**: 32x32 `assets/icon.png`.
- **Title**: "Rumble" (FontWeight.bold).
- **Subline**: "Mumble Reloaded" (muted, size 10).
- **Global Actions**: Constant Settings Cog and dynamic Exit (LogOut) button when connected.
- **Border**: Subtle bottom border to separate from content.

### 2. Connected Bottom Bar (`_buildBottomBar`)
- **Mic Status**: Mute/Deafen buttons with status colors.
- **Mic Indicator**: Moving circle pulsing with microphone volume (`MumbleService.currentVolume`).
- **PTT Button**: Fixed dimensions (180x48) to prevent layout shifting. Uses gradient backgrounds for states (Talking/Suppressed/Hold).

### 3. Server List (`_buildServerList`)
- **Cards**: `ServerCard` with rounded corners (16px) and subtle borders.
- **Stats**: Real-time Ping (ms) and User Count/Capacity (e.g., 3/100).
- **Status Colors**: Green for low ping, Orange/Red for high latency.

## Coding Conventions
- **No Semicolons**: Avoid semicolons unless syntactically necessary.
- **Comments Above**: Always place code comments on the line ABOVE the target code.
- **HTML/Widget Classes**: When defining container divs/widgets, the first class name should match the component name (e.g., `<div class="server-card ..."`).
- **Iconography**: Standardize on `LucideIcons`.

## State Management
- **MumbleService**: Central logic for connection, audio, and client state.
- **ServerProvider**: Manage server list, pings, and persistence.
- **SettingsService**: Application-wide settings (PTT, Window, Devices).
- **CertificateService**: User identity management.
