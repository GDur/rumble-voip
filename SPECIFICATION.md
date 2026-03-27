# Rumble: Technical & UI/UX Specification

This document defines the expected behaviors and implementation standards for the Rumble Mumble client. Maintain these standards when migrating between protocol cores (e.g., `dumble` vs. Rust-based cores).

## 1. Data Model Integrity
- **Model Immutability**: All server and user models should be immutable.
- **Copy Propagation**: The `copyWith` pattern must explicitly handle transient/optional fields like `ping`, `userCount`, and `maxUsers`. Failing to do so causes "flickering" or missing data in the UI after updates.
- **Equality Logic**: Model equality checks must include ephemeral fields (like ping/talking state) if they are used for UI list updates.

## 2. Server Capacity & Presence
- **User Counts**: Always display the occupancy status as `[Current]/[Max] Users` (e.g., `12/50 Users`).
- **Ping Data**: Server list cards must show both the latency (ping) and the occupancy.
- **Header Status**: When connected, the current server's occupancy should be visible in the application header/title bar for immediate visibility.

## 3. User State & Identification
- **Self-Identification**: The current user should be clearly marked with a suffix like `(You)` in the channel tree.
- **Local Echo / Reactivity**: Local actions (Toggle Mute, Toggle Deafen, Set Notice) must trigger **immediate** UI updates. Do not wait for the server to echo the state change back, as Mumble servers may aggregate or delay these heartbeats.
- **Talking Indicators**:
    - **Blue**: Talking (Transmitting voice).
    - **Brand Green (Color 0xFF64FFDA)**: Idle / Online (Available).
    - **Red (Destructive)**: Restricted (Muted, Suppressed, or Deafened).

## 4. Mumble Protocol Implementation Quirks
- **Notice (Comment) Fetching**: Mumble servers often send a `commentHash` (SHA1) instead of the full text to save bandwidth.
    - **Requirement**: If a user update contains a hash but `comment` is null/empty, the client **must** automatically trigger a `RequestBlob` (or `requestUserComment`) for that hash.
- **Handshake Sync**: Ensure listeners are attached to the `Self` user and all existing channel/user objects immediately after the `ServerSync` message.
- **Mute/Deaf Mappings**: `isMuted` should account for both `selfMute` (local) and `mute` (server-enforced).

## 5. UI/UX Preferences
- **PTT Display**: The Push-To-Talk button must reflect the actual "Talking" state of the local user, not just the physical button press.
- **Notice Icons**: Users with a comment/notice should have a visible icon (e.g., `LucideIcons.stickyNote`) that opens the notice view.
