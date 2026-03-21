# Design Patterns & Aesthetics Reference

This document outlines the visual and architectural patterns established for the **Rumble** (Mumble) application to ensure UI consistency and a premium feel.

## 1. Glassmorphism & Translucency
To create a clean, modern aesthetic with depth, use a combination of semi-transparent backgrounds and **BackdropFilter**.

### Chat Sidebar Implementation
*   **Background**: Use the theme's background color with reduced alpha.
    ```dart
    backgroundColor: theme.colorScheme.background.withValues(alpha: 0.6)
    ```
*   **Blur**: Wrap the content in a `BackdropFilter` to blur the UI underneath the sheet.
    ```dart
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: const YourViewContent(),
    )
    ```
*   **Note**: Ensure `sigma` values are high enough (e.g., 10+) for a "frosted glass" effect.

## 2. Modal Aesthetics
### Rounded Corners
All modals (Dialogs, Sheets) should follow a consistent corner radius to match button roundness and avoid "sharp" industrial looks.
*   **Standard Radius**: `16px`.
*   **Implementation**: 
    ```dart
    return ShadDialog(
      radius: const BorderRadius.all(Radius.circular(16)),
      ...
    )
    ```

## 3. Navigation & Button Alignment
Consistency in how menu items are balanced across Desktop and Mobile is key.

### Desktop Sidebar Buttons
Desktop navigators should be simple and weighted to the left.
*   **Style**: `ShadButton.ghost`.
*   **Alignment**: `MainAxisAlignment.start`.
*   **Icon + Label**: Grouped together on the left.
*   **Chevrons**: Omitted for a cleaner "side-bar" look.

### Mobile Menu Lists
Mobile lists act as "drill-down" menus and require navigation cues.
*   **Layout**: `[Icon] [Text] ................ [Chevron]`
*   **Implementation**:
    - `expands: true` on `ShadButton`.
    - `trailing: Icon(LucideIcons.chevronRight)`.
    - `child: Container(alignment: Alignment.centerLeft, child: Text(label))`.
    - This ensures the text stays on the left (adjacent to the icon) while the chevron stays pinned to the far right edge.

## 4. Layout Constraints
*   **Wide Dialogs**: On Desktop, allow dialogs to breathe by using percentage-based widths (e.g., **69%** of parent width) with reasonable `min`/`max` limits.
*   **Responsive Widths**:
    - Desktop Max: `1200px`.
    - Desktop Min: `700px`.

## 5. Input Field Handling
To streamline user interaction, especially on desktop:
*   **Autofocus**: Any modal or sidebar that contains a primary input field (e.g., Add Server, Chat, Edit Notice) MUST have `autofocus: true` set on that field.
*   **Auto-selection**: If an input field is opened with existing text (e.g., editing a server or changing a nickname), the entire text should be automatically selected so the user can immediately overwrite or delete it.
*   **Implementation**:
    ```dart
    onInit: () {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
    ```
