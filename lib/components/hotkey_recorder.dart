import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/settings_service.dart';

// Component: hotkey-recorder
class HotkeyRecorder extends StatefulWidget {
  final SettingsService settings;

  const HotkeyRecorder({super.key, required this.settings});

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  bool _hasRegularKey = false;

  void _saveHotkey(LogicalKeyboardKey key, PhysicalKeyboardKey physicalKey) {
    widget.settings.setPttKey(PttKey.none);
    widget.settings.setCustomHotkey({
      'label': key.keyLabel,
      'logical_id': key.keyId,
      'physical_id': physicalKey.usbHidUsage,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Record Hotkey'),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyRepeatEvent) return KeyEventResult.handled;

          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }

          // Modifiers
          bool isMod =
              key == LogicalKeyboardKey.control ||
              key == LogicalKeyboardKey.controlLeft ||
              key == LogicalKeyboardKey.controlRight ||
              key == LogicalKeyboardKey.shift ||
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight ||
              key == LogicalKeyboardKey.alt ||
              key == LogicalKeyboardKey.altLeft ||
              key == LogicalKeyboardKey.altRight ||
              key == LogicalKeyboardKey.meta ||
              key == LogicalKeyboardKey.metaLeft ||
              key == LogicalKeyboardKey.metaRight ||
              key == LogicalKeyboardKey.capsLock;

          if (event is KeyDownEvent) {
            if (!isMod) {
              _hasRegularKey = true;
              _saveHotkey(key, event.physicalKey);
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            // Capture modifier on its release if no regular key was hit
            if (isMod && !_hasRegularKey) {
              _saveHotkey(key, event.physicalKey);
              return KeyEventResult.handled;
            }
          }

          setState(() {});
          return KeyEventResult.handled;
        },
        child: Container(
          width: 300,
          height: 150,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCurrentHotkeyPrompt(),
              const SizedBox(height: 12),
              const Text(
                'Press any key or combination',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Single modifiers (Shift, Ctrl) are supported.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text(
                'Press ESC to cancel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentHotkeyPrompt() {
    final custom = widget.settings.customHotkey;
    final pttKey = widget.settings.pttKey;

    String current = 'NONE';
    if (pttKey != PttKey.none) {
      current = pttKey.name.toUpperCase();
    } else if (custom != null) {
      current = 'CUSTOM: ${custom['label'] ?? 'Unknown'}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        current,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
