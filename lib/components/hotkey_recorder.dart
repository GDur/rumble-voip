import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/hotkey_action.dart';
import 'package:rumble/services/settings_service.dart';

// Component: hotkey-recorder
class HotkeyRecorder extends StatefulWidget {
  final SettingsService settings;
  final HotkeyAction action;

  const HotkeyRecorder({
    super.key,
    required this.settings,
    this.action = HotkeyAction.pushToTalk,
  });

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  bool _hasRegularKey = false;

  void _saveHotkey(LogicalKeyboardKey key, PhysicalKeyboardKey physicalKey, {bool isModifierOnly = false}) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final List<String> modifiers = [];
    
    // Check for modifiers being held down
    if (!isModifierOnly) {
      if (pressed.contains(LogicalKeyboardKey.shiftLeft) || pressed.contains(LogicalKeyboardKey.shiftRight)) modifiers.add('shift');
      if (pressed.contains(LogicalKeyboardKey.controlLeft) || pressed.contains(LogicalKeyboardKey.controlRight)) modifiers.add('control');
      if (pressed.contains(LogicalKeyboardKey.altLeft) || pressed.contains(LogicalKeyboardKey.altRight)) modifiers.add('alt');
      if (pressed.contains(LogicalKeyboardKey.metaLeft) || pressed.contains(LogicalKeyboardKey.metaRight)) modifiers.add('meta');
    }

    // Attempt to use a cleaner label from the physical key if it's a simple key
    String baseLabel = key.keyLabel;
    if (physicalKey.debugName != null) {
      final debugName = physicalKey.debugName!;
      // Simple physical names like "Key A", "Digit 3", "F13"
      if (debugName.startsWith('Key ')) {
        baseLabel = debugName.replaceFirst('Key ', '');
      } else if (debugName.startsWith('Digit ')) {
        baseLabel = debugName.replaceFirst('Digit ', '');
      } else if (debugName.startsWith('F') && debugName.length > 1) {
        baseLabel = debugName;
      }
    }

    String fullLabel = baseLabel;
    if (modifiers.isNotEmpty) {
      fullLabel = '${modifiers.map((m) => m[0].toUpperCase() + m.substring(1)).join(' + ')} + $baseLabel';
    }

    widget.settings.addHotkeyBinding({
      'action': widget.action.name,
      'label': fullLabel,
      'key_label': baseLabel,
      'logical_id': key.keyId,
      'physical_id': physicalKey.usbHidUsage,
      'modifiers': modifiers,
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

          // Always use the physical key for the identifier, but logical for the "modifier-only" case
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }

          // Check if it's a modifier key
          final physicalKey = event.physicalKey;
          bool isMod = 
              physicalKey == PhysicalKeyboardKey.controlLeft ||
              physicalKey == PhysicalKeyboardKey.controlRight ||
              physicalKey == PhysicalKeyboardKey.shiftLeft ||
              physicalKey == PhysicalKeyboardKey.shiftRight ||
              physicalKey == PhysicalKeyboardKey.altLeft ||
              physicalKey == PhysicalKeyboardKey.altRight ||
              physicalKey == PhysicalKeyboardKey.metaLeft ||
              physicalKey == PhysicalKeyboardKey.metaRight ||
              physicalKey == PhysicalKeyboardKey.capsLock;

          if (event is KeyDownEvent) {
            if (!isMod) {
              _hasRegularKey = true;
              _saveHotkey(key, event.physicalKey, isModifierOnly: false);
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            // Capture modifier on its release if no regular key was hit
            if (isMod && !_hasRegularKey) {
              _saveHotkey(key, event.physicalKey, isModifierOnly: true);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ShadTheme.of(context).colorScheme.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Recording for: ${widget.action.label}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
