import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/hotkey_service.dart';

// Component: hotkey-tab
class HotkeyTab extends StatelessWidget {
  final SettingsService settings;
  final StateSetter onUpdate;
  final Function(BuildContext, SettingsService) onShowHotkeyRecorder;

  const HotkeyTab({
    super.key,
    required this.settings,
    required this.onUpdate,
    required this.onShowHotkeyRecorder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PTT Hotkey',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              children: [
                Expanded(
                  child: ShadSelect<PttKey>(
                    placeholder: const Text('Select a key'),
                    initialValue: settings.pttKey,
                    onChanged: (value) {
                      if (value != null) {
                        settings.setPttKey(value);
                        onUpdate(() {});
                      }
                    },
                    options: [
                      ...PttKey.values.map((k) {
                        String label = k.name.toUpperCase();
                        if (k == PttKey.none) label = 'DISABLED';
                        return ShadOption(value: k, child: Text(label));
                      }),
                    ],
                    selectedOptionBuilder: (context, value) {
                      if (value == PttKey.none &&
                          settings.customHotkey != null) {
                        return Text(
                          'CUSTOM: ${settings.customHotkey!['label'] ?? 'Unknown'}',
                        );
                      }
                      return Text(value.name.toUpperCase());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: () => onShowHotkeyRecorder(context, settings),
                  child: const Text('Record...'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (settings.pttKey != PttKey.none ||
              settings.customHotkey != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Suppress original key function',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadTooltip(
                        builder: (context) => Text(
                          'If enabled, the key will not perform its original duty (e.g. CapsLock LED won\'t toggle).',
                          style: TextStyle(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.info,
                          size: 14,
                          color: ShadTheme.of(
                            context,
                          ).colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ShadSwitch(
                  value: settings.pttSuppress,
                  onChanged: (val) {
                    settings.setPttSuppress(val);
                    onUpdate(() {});
                  },
                ),
              ],
            ),
          ],
          if (Theme.of(context).platform == TargetPlatform.macOS) ...[
            const SizedBox(height: 32),
            const Text(
              'macOS Permissions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ShadTheme.of(
                  context,
                ).colorScheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ShadTheme.of(context).colorScheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Accessibility Access',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<bool>(
                        valueListenable: HotkeyService.of(
                          context,
                        ).hasAccessibilityPermission,
                        builder: (context, granted, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: granted
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: granted
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              granted ? 'GRANTED' : 'REQUIRED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: granted ? Colors.green : Colors.orange,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Global hotkeys (PTT while app is hidden) require Accessibility permission. If it still shows as "Required" after you enabled it, please press "Refresh Status" or restart Rumble.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => HotkeyService.of(
                          context,
                        ).openAccessibilitySettings(),
                        child: const Text('Open System Settings'),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () =>
                            HotkeyService.of(context).checkPermission(),
                        child: const Text('Refresh Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
