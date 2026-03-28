import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';

// Component: general-tab
class GeneralTab extends StatelessWidget {
  final SettingsService settings;
  final StateSetter onUpdate;

  const GeneralTab({super.key, required this.settings, required this.onUpdate});

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
                ShadOption(value: ThemeMode.light, child: const Text('Light')),
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
              const Expanded(
                child: Text('Reconnect to last server on startup'),
              ),
              const SizedBox(width: 8),
              ShadSwitch(
                value: settings.reconnectToLastServer,
                onChanged: (val) {
                  settings.setReconnectToLastServer(val);
                  onUpdate(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Remember last channel')),
              const SizedBox(width: 8),
              ShadSwitch(
                value: settings.rememberLastChannel,
                onChanged: (val) {
                  settings.setRememberLastChannel(val);
                  onUpdate(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Hide empty channels')),
              const SizedBox(width: 8),
              ShadSwitch(
                value: settings.hideEmptyChannels,
                onChanged: (val) {
                  settings.setHideEmptyChannels(val);
                  onUpdate(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
