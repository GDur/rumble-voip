import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/components/settings/tabs/audio_tab.dart';
import 'package:rumble/components/settings/tabs/general_tab.dart';
import 'package:rumble/components/settings/tabs/certificate_tab.dart';
import 'package:rumble/components/settings/tabs/about_tab.dart';

// Component: settings-dialog
class SettingsDialog extends StatefulWidget {
  final SettingsService settings;
  final MumbleService mumbleService;
  final Function(BuildContext, SettingsService) onShowHotkeyRecorder;

  const SettingsDialog({
    super.key,
    required this.settings,
    required this.mumbleService,
    required this.onShowHotkeyRecorder,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String _currentTab = 'general';

  @override
  Widget build(BuildContext context) {
    final sideBarItems = [
      (id: 'audio', label: 'Audio', icon: LucideIcons.volume2),
      (id: 'general', label: 'General', icon: LucideIcons.settings),
      (id: 'certificates', label: 'Certificates', icon: LucideIcons.shieldCheck),
      (id: 'about', label: 'About', icon: LucideIcons.info),
    ];

    return ShadDialog(
      padding: EdgeInsets.zero,
      title: const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Settings'),
      ),
      child: SizedBox(
        width: 700,
        height: 550,
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 180,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: sideBarItems.map((item) {
                  final isSelected = _currentTab == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ShadButton.ghost(
                      onPressed: () => setState(() => _currentTab = item.id),
                      width: double.infinity,
                      mainAxisAlignment: MainAxisAlignment.start,
                      backgroundColor: isSelected 
                        ? ShadTheme.of(context).colorScheme.accent 
                        : Colors.transparent,
                      pressedBackgroundColor: ShadTheme.of(context).colorScheme.accent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 16),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTabContent(_currentTab),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ShadButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'audio':
        return AudioTab(
          settings: widget.settings,
          mumbleService: widget.mumbleService,
          onUpdate: setState,
        );
      case 'general':
        return GeneralTab(
          settings: widget.settings,
          onUpdate: setState,
          onShowHotkeyRecorder: widget.onShowHotkeyRecorder,
        );
      case 'certificates':
        return CertificateTab(
          onUpdate: setState,
        );
      case 'about':
        return const AboutTab();
      default:
        return const SizedBox.shrink();
    }
  }
}
