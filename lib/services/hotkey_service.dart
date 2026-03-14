import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';

class HotkeyService {
  final MumbleService _mumbleService;
  final SettingsService _settingsService;
  HotKey? _currentHotKey;

  HotkeyService(this._mumbleService, this._settingsService) {
    _settingsService.addListener(_updateHotKey);
    _init();
  }

  Future<void> _init() async {
    await hotKeyManager.unregisterAll();
    _updateHotKey();
  }

  void _updateHotKey() async {
    // Unregister existing
    if (_currentHotKey != null) {
      await hotKeyManager.unregister(_currentHotKey!);
      _currentHotKey = null;
    }

    final pttKey = _settingsService.pttKey;
    if (pttKey == PttKey.none) return;

    final physicalKey = _mapPttKeyToPhysicalKey(pttKey);
    if (physicalKey == null) return;

    _currentHotKey = HotKey(
      key: physicalKey,
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(
        _currentHotKey!,
        keyDownHandler: (hotKey) {
          debugPrint('[HotkeyService] Key Down: $pttKey');
          _mumbleService.startPushToTalk();
        },
        keyUpHandler: (hotKey) {
          debugPrint('[HotkeyService] Key Up: $pttKey');
          _mumbleService.stopPushToTalk();
        },
      );
      debugPrint('[HotkeyService] Registered global hotkey: $pttKey');
    } catch (e) {
      debugPrint('[HotkeyService] Error registering hotkey: $e');
    }
  }

  PhysicalKeyboardKey? _mapPttKeyToPhysicalKey(PttKey key) {
    switch (key) {
      case PttKey.control:
        return PhysicalKeyboardKey.controlLeft;
      case PttKey.shift:
        return PhysicalKeyboardKey.shiftLeft;
      case PttKey.alt:
        return PhysicalKeyboardKey.altLeft;
      case PttKey.command:
        return PhysicalKeyboardKey.metaLeft;
      case PttKey.capsLock:
        return PhysicalKeyboardKey.capsLock;
      default:
        return null;
    }
  }

  void dispose() {
    _settingsService.removeListener(_updateHotKey);
    hotKeyManager.unregisterAll();
  }
}
