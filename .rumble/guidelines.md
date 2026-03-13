# Rumble UI Guidelines

## Notifications
- **Always use `ShadSonner`** instead of `ShadToaster`.
- Access the sonner using `ShadSonner.of(context)`.
- Use `ShadToast.destructive` for errors and standard `ShadToast` for information.
- Example usage:
  ```dart
  final sonner = ShadSonner.of(context);
  sonner.show(
    ShadToast(
      title: const Text('Success'),
      description: const Text('Action completed.'),
    ),
  );
  ```

## Accessibility & Responsiveness
- Use `MediaQuery` or `LayoutBuilder` to adapt the UI for mobile/desktop.
- Ensure all interactive icons have tooltips on smaller screens where labels are hidden.

## Coding Style
- Prefer `LucideIcons` for a modern look.
- Use `ShadButton.ghost` for icon-only action buttons.
- Avoid `EdgeInsets.zero` on buttons to prevent layout shift (ShiftBox) errors.
