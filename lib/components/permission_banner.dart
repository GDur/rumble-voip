import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/hotkey_service.dart';
import 'package:rumble/services/settings_service.dart';

// Component: permission-banner
class PermissionBanner extends StatefulWidget {
  const PermissionBanner({super.key});

  @override
  State<PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends State<PermissionBanner> {
  bool _showSuccessBanner = false;

  @override
  Widget build(BuildContext context) {
    final hotkeyService = Provider.of<HotkeyService>(context);
    final settings = Provider.of<SettingsService>(context);

    if (settings.pttKey == PttKey.none && settings.customHotkey == null) {
      return const SizedBox.shrink();
    }

    if (settings.ignoreAccessibility) {
      return const SizedBox.shrink();
    }

    if (_showSuccessBanner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.green.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(LucideIcons.check, color: Colors.green, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Access granted successfully! Try using your hotkey now for PTT.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ShadIconButton.ghost(
              width: 32,
              height: 32,
              padding: EdgeInsets.zero,
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () => setState(() => _showSuccessBanner = false),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: hotkeyService.hasAccessibilityPermission,
      builder: (context, hasPermission, _) {
        if (hasPermission) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: ShadTheme.of(context).colorScheme.destructive.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(
                LucideIcons.info,
                color: ShadTheme.of(context).colorScheme.destructive,
                size: 20,
              ),
              const SizedBox(width: 8),
              ShadIconButton.ghost(
                width: 32,
                height: 32,
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  settings.setIgnoreAccessibility(true);
                  ShadToaster.of(context).show(
                    const ShadToast(
                      title: Text('Banner hidden'),
                      description: Text('You can re-enable this check in General Settings.'),
                    ),
                  );
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Global Hotkeys require Accessibility permissions on macOS to work in the background.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String?>(
                      valueListenable: hotkeyService.appPath,
                      builder: (context, path, _) {
                        if (path == null) return const SizedBox.shrink();
                        return SelectableText(
                          'App Path: $path',
                          style: TextStyle(
                            fontSize: 10,
                            color: ShadTheme.of(context).colorScheme.mutedForeground,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => hotkeyService.openAccessibilitySettings(),
                child: const Text('Open Settings'),
              ),
              const SizedBox(width: 8),
              ShadIconButton.ghost(
                width: 32,
                height: 32,
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                onPressed: () async {
                  await hotkeyService.checkPermission();
                  if (context.mounted) {
                    final granted = hotkeyService.hasAccessibilityPermission.value;
                    if (granted) setState(() => _showSuccessBanner = true);
                    
                    ShadToaster.of(context).show(
                      ShadToast(
                        title: Text(granted ? 'Permission Granted' : 'Status: Permission Required'),
                        description: Text(granted 
                          ? 'Rumble now has full control over hotkeys.' 
                          : 'Check if Rumble is enabled in System Settings.'),
                      ),
                    );
                  }
                },
              ),
              ShadIconButton.ghost(
                width: 32,
                height: 32,
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  settings.setIgnoreAccessibility(true);
                  ShadToaster.of(context).show(
                    const ShadToast(
                      title: Text('Banner hidden'),
                      description: Text('You can re-enable this check in General Settings.'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
