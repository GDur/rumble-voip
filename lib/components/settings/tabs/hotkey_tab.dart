import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/hotkey_action.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/hotkey_service.dart';

// Component: hotkey-tab
class HotkeyTab extends StatelessWidget {
  final SettingsService settings;
  final StateSetter onUpdate;
  final Function(BuildContext, SettingsService, {HotkeyAction? action})
      onShowHotkeyRecorder;

  const HotkeyTab({
    super.key,
    required this.settings,
    required this.onUpdate,
    required this.onShowHotkeyRecorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final theme = ShadTheme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hotkey Bindings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (isDesktop)
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => _showAddActionMenu(context),
                  leading: const Icon(LucideIcons.plus, size: 16),
                  child: const Text('Add Hotkey'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isDesktop) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.border),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Global hotkeys are currently only available on desktop devices with keyboards.',
                      style: theme.textTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (isDesktop) ...[
            // Legacy/Preset PTT Dropdown
            const Text(
              'Push-To-Talk Preset',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ShadSelect<PttKey>(
                placeholder: const Text('Select a preset key'),
                initialValue: settings.pttKey,
                onChanged: (value) {
                  if (value != null) {
                    settings.setPttKey(value);
                    onUpdate(() {});
                  }
                },
                selectedOptionBuilder: (context, value) {
                  return Text(value.name.toUpperCase());
                },
                options: [
                  ...PttKey.values.map((k) {
                    String label = k.name.toUpperCase();
                    if (k == PttKey.none) label = 'DISABLED';
                    return ShadOption(value: k, child: Text(label));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // List of custom bindings
            if (settings.hotkeyBindings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No custom hotkeys added yet.',
                    style: theme.textTheme.muted,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settings.hotkeyBindings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final binding = settings.hotkeyBindings[index];
                  final action = HotkeyAction.fromName(binding['action'] ?? '');
                  final label = binding['label'] ?? 'Unknown';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.muted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            action.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShadButton.ghost(
                          width: 32,
                          height: 32,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            settings.removeHotkeyBinding(index);
                            onUpdate(() {});
                          },
                          child: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 24),
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
                color: ShadTheme.of(context).colorScheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.border),
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
                        valueListenable: HotkeyService.of(context).hasAccessibilityPermission,
                        builder: (context, granted, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    'Global hotkeys (PTT while app is hidden) require Accessibility permission.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => HotkeyService.of(context).openAccessibilitySettings(),
                        child: const Text('Open System Settings'),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () => HotkeyService.of(context).checkPermission(),
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

  void _showAddActionMenu(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Select Action'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: HotkeyAction.values.map((action) {
              return ShadButton.ghost(
                onPressed: () {
                  Navigator.of(context).pop();
                  onShowHotkeyRecorder(context, settings, action: action);
                },
                width: double.infinity,
                mainAxisAlignment: MainAxisAlignment.start,
                child: Text(action.label),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
