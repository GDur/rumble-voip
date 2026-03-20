import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';

// Component: general-tab
class GeneralTab extends StatelessWidget {
  final SettingsService settings;
  final StateSetter onUpdate;
  final Function(BuildContext, SettingsService) onShowHotkeyRecorder;

  const GeneralTab({
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
            'Appearance',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: ShadSelect<ThemeMode>(
              placeholder: const Text('Select Theme'),
              initialValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settings.setThemeMode(value);
                  onUpdate(() {});
                }
              },
              options: [
                ShadOption(
                  value: ThemeMode.system,
                  child: const Text('System'),
                ),
                ShadOption(
                  value: ThemeMode.light,
                  child: const Text('Light'),
                ),
                ShadOption(value: ThemeMode.dark, child: const Text('Dark')),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(value.name.toUpperCase()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connection',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reconnect to last server on startup'),
              ShadSwitch(
                value: settings.reconnectToLastServer,
                onChanged: (val) {
                  settings.setReconnectToLastServer(val);
                  onUpdate(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Suppress original key function',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          ShadTooltip(
                            builder: (context) => const Text(
                              'If enabled, the key will not perform its original duty (e.g. CapsLock LED won\'t toggle).',
                            ),
                            child: Icon(
                              LucideIcons.info,
                              size: 14,
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
        ],
      ),
    );
  }
}
