import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/hotkey_action.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/components/settings/tabs/audio_input_tab.dart';
import 'package:rumble/components/settings/tabs/audio_output_tab.dart';
import 'package:rumble/components/settings/tabs/general_tab.dart';
import 'package:rumble/components/settings/tabs/hotkey_tab.dart';
import 'package:rumble/components/settings/tabs/certificate_tab.dart';
import 'package:rumble/components/settings/tabs/about_tab.dart';
import 'package:rumble/components/ptt_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Component: settings-dialog
class SettingsDialog extends StatefulWidget {
  final SettingsService settings;
  final MumbleService mumbleService;
  final Function(BuildContext, SettingsService, {HotkeyAction? action})
  onShowHotkeyRecorder;

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
  String _version = '';

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  void initState() {
    super.initState();
    // Refresh devices whenever the dialog is opened to catch new ones
    widget.mumbleService.refreshInputDevices();
    widget.mumbleService.refreshOutputDevices();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isMobile = _isMobile(context);

    final sideBarItems = [
      (id: 'general', label: 'General', icon: LucideIcons.settings),
      (id: 'hotkeys', label: 'Hotkeys', icon: LucideIcons.keyboard),
      (id: 'audioInput', label: 'Audio Input', icon: LucideIcons.mic),
      (id: 'audioOutput', label: 'Audio Output', icon: LucideIcons.volume2),
      (
        id: 'certificates',
        label: 'Certificates',
        icon: LucideIcons.shieldCheck,
      ),
      (id: 'about', label: 'About', icon: LucideIcons.info),
    ];

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

    final dialogHeight = isMobile
        ? (MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom) *
            0.9
        : MediaQuery.of(context).size.height * 0.8;

    return ShadDialog(
      padding: EdgeInsets.zero,
      radius: const BorderRadius.all(Radius.circular(16)),
      removeBorderRadiusWhenTiny: false,
      closeIconPosition: const ShadPosition(top: 12, right: 12),
      constraints: BoxConstraints(
        maxWidth: isMobile
            ? MediaQuery.of(context).size.width * 0.95
            : MediaQuery.of(context).size.width * 0.6,
        maxHeight: dialogHeight,
      ),
      child: SafeArea(
        top: isMobile,
        bottom: isMobile,
        child: SizedBox(
          height: dialogHeight,
          child: Stack(
            children: [
              Column(
                children: [
                  title, // Headline is now fixed within this column
                  Expanded(
                    child: isMobile
                        ? _buildMobileContent(effectiveTab, sideBarItems)
                        : _buildDesktopContent(effectiveTab, sideBarItems),
                  ),
                  _buildFooter(theme), // Footer is now fixed within this column
                ],
              ),
              if (isMobile && widget.mumbleService.isConnected)
                Positioned(
                  bottom: 110,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PushToTalkButton(
                      service: widget.mumbleService,
                      width: 180,
                      height: 48,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(
    String? effectiveTab,
    List<({IconData icon, String id, String label})> sideBarItems,
  ) {
    final theme = ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: theme.colorScheme.border),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: sideBarItems.map((item) {
                final isSelected = effectiveTab == item.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ShadButton.ghost(
                    onPressed: () => setState(() => _currentTab = item.id),
                    width: double.infinity,
                    gap: 12,
                    mainAxisAlignment: MainAxisAlignment.start,
                    backgroundColor: isSelected
                        ? theme.colorScheme.accent
                        : Colors.transparent,
                    pressedBackgroundColor: theme.colorScheme.accent,
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
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(effectiveTab!),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_version.isNotEmpty)
            Text(
              'Rumble v$_version',
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            )
          else
            const SizedBox.shrink(),
          ShadButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(
    String? effectiveTab,
    List<({IconData icon, String id, String label})> sideBarItems,
  ) {
    if (effectiveTab == null) {
      // Category List
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sideBarItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = sideBarItems[index];
          return ShadButton.ghost(
            onPressed: () => setState(() => _currentTab = item.id),
            size: ShadButtonSize.lg,
            width: double.infinity,
            gap: 16,
            mainAxisAlignment: MainAxisAlignment.start,
            leading: Icon(item.icon, size: 20),
            trailing: const Icon(LucideIcons.chevronRight, size: 16),
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 16),
            ),
          );
        },
      );
    } else {
      // Tab Detail
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildTabContent(effectiveTab),
      );
    }
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'audioInput':
        return AudioInputTab(
          settings: widget.settings,
          mumbleService: widget.mumbleService,
          onUpdate: setState,
        );
      case 'audioOutput':
        return AudioOutputTab(
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
