import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/components/settings/tabs/audio_tab.dart';
import 'package:rumble/components/settings/tabs/general_tab.dart';
import 'package:rumble/components/settings/tabs/hotkey_tab.dart';
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
  String? _currentTab;

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  void initState() {
    super.initState();
    // Refresh devices whenever the dialog is opened to catch new ones
    widget.mumbleService.refreshInputDevices();
    widget.mumbleService.refreshOutputDevices();
  }

  @override
  Widget build(BuildContext context) {
    final sideBarItems = [
      (id: 'general', label: 'General', icon: LucideIcons.settings),
      (id: 'hotkeys', label: 'Hotkeys', icon: LucideIcons.keyboard),
      (id: 'audio', label: 'Audio', icon: LucideIcons.volume2),
      (
        id: 'certificates',
        label: 'Certificates',
        icon: LucideIcons.shieldCheck,
      ),
      (id: 'about', label: 'About', icon: LucideIcons.info),
    ];

    final isMobile = _isMobile(context);
    final effectiveTab = _currentTab ?? (!isMobile ? 'general' : null);

    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          if (isMobile && effectiveTab != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ShadIconButton.ghost(
                onPressed: () => setState(() => _currentTab = null),
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
              ),
            ),
          Text(
            effectiveTab != null && isMobile
                ? sideBarItems.firstWhere((i) => i.id == effectiveTab).label
                : 'Settings',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    return ShadDialog(
      padding: EdgeInsets.zero,
      radius: const BorderRadius.all(Radius.circular(16)),
      closeIconPosition: const ShadPosition(top: 12, right: 12),
      constraints: isMobile
          ? null
          : BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
      title: title,
      child: SafeArea(
        top: isMobile,
        bottom: isMobile,
        child: SizedBox(
          width: isMobile
              ? MediaQuery.of(context).size.width * 0.95
              : (MediaQuery.of(context).size.width * 0.69).clamp(700, 1200),
          height: isMobile ? MediaQuery.of(context).size.height * 0.7 : 600,
          child: isMobile
              ? _buildMobileContent(effectiveTab, sideBarItems)
              : Row(
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
                          final isSelected = effectiveTab == item.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ShadButton.ghost(
                              onPressed: () =>
                                  setState(() => _currentTab = item.id),
                              width: double.infinity,
                              gap: 12,
                              mainAxisAlignment: MainAxisAlignment.start,
                              backgroundColor: isSelected
                                  ? ShadTheme.of(context).colorScheme.accent
                                  : Colors.transparent,
                              pressedBackgroundColor: ShadTheme.of(
                                context,
                              ).colorScheme.accent,
                              leading: Icon(item.icon, size: 16),
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
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
                            Expanded(child: _buildTabContent(effectiveTab!)),
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
      ),
    );
  }

  Widget _buildMobileContent(
    String? effectiveTab,
    List<({IconData icon, String id, String label})> sideBarItems,
  ) {
    if (effectiveTab == null) {
      // Category List
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: sideBarItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ShadButton.ghost(
                      onPressed: () => setState(() => _currentTab = item.id),
                      size: ShadButtonSize.lg,
                      width: MediaQuery.of(context).size.width * 0.85,
                      expands: true,
                      gap: 16,
                      mainAxisAlignment: MainAxisAlignment.start,
                      leading: Icon(item.icon, size: 20),
                      trailing: Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: ShadTheme.of(
                          context,
                        ).colorScheme.mutedForeground,
                      ),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.label,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ShadButton(
              onPressed: () => Navigator.of(context).pop(),
              width: MediaQuery.of(context).size.width * 0.85,
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      // Tab Detail
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildTabContent(effectiveTab)),
            const SizedBox(height: 16),
            ShadButton.outline(
              onPressed: () => setState(() => _currentTab = null),
              width: MediaQuery.of(context).size.width * 0.85,
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      );
    }
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
        return GeneralTab(settings: widget.settings, onUpdate: setState);
      case 'hotkeys':
        return HotkeyTab(
          settings: widget.settings,
          onUpdate: setState,
          onShowHotkeyRecorder: widget.onShowHotkeyRecorder,
        );
      case 'certificates':
        return CertificateTab(onUpdate: setState);
      case 'about':
        return const AboutTab();
      default:
        return const SizedBox.shrink();
    }
  }
}
