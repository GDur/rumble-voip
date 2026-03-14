import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';

class HotkeyService with WidgetsBindingObserver {
  final MumbleService _mumbleService;
  final SettingsService _settingsService;
  HotKey? _currentHotKey;

  final ValueNotifier<bool> hasAccessibilityPermission = ValueNotifier<bool>(true);

  HotkeyService(this._mumbleService, this._settingsService) {
    _settingsService.addListener(_updateHotKey);
    WidgetsBinding.instance.addObserver(this);
    
    // Handle native modifier events for macOS
    _permissionChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFlagsChanged') {
        _handleNativeModifierFlags(call.arguments as int);
      }
    });

    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermission();
    }
  }

  Future<void> _init() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await checkPermission();
    }
    await hotKeyManager.unregisterAll();
    _updateHotKey();
  }

  static const _permissionChannel = MethodChannel('com.rumble.app/permissions');

  Future<void> checkPermission() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final bool wasTrusted = hasAccessibilityPermission.value;
        final bool hasPermission = await _permissionChannel.invokeMethod('checkAccessibility');
        
        if (hasPermission != wasTrusted) {
          hasAccessibilityPermission.value = hasPermission;
          debugPrint('[HotkeyService] Accessibility permission changed: $hasPermission');
          
          // If we just gained permission, we need to re-register the hotkeys
          if (hasPermission) {
            _updateHotKey();
          }
        }
      } catch (e) {
        debugPrint('[HotkeyService] Error checking permission: $e');
      }
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        await _permissionChannel.invokeMethod('openAccessibility');
      } catch (e) {
        debugPrint('[HotkeyService] Error opening accessibility settings: $e');
      }
    }
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
      modifiers: [],
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(
        _currentHotKey!,
        keyDownHandler: (hotKey) {
          debugPrint('[HotkeyService] EVENT: Key Down ($pttKey)');
          _mumbleService.startPushToTalk();
        },
        keyUpHandler: (hotKey) {
          debugPrint('[HotkeyService] EVENT: Key Up ($pttKey)');
          _mumbleService.stopPushToTalk();
        },
      );
      debugPrint('[HotkeyService] Successfully registered global hotkey: $pttKey');
    } catch (e) {
      debugPrint('[HotkeyService] CRITICAL Error registering hotkey: $e');
    }
  }

  void _handleNativeModifierFlags(int rawFlags) {
    final pttKey = _settingsService.pttKey;
    if (pttKey == PttKey.none) return;

    bool isKeyPressed = false;
    
    // macOS NSEvent.modifierFlags bitmasks
    const maskCapsLock = 1 << 16;
    const maskShift = 1 << 17;
    const maskControl = 1 << 18;
    const maskAlt = 1 << 19;
    const maskCommand = 1 << 20;

    switch (pttKey) {
      case PttKey.shift:
        isKeyPressed = (rawFlags & maskShift) != 0;
        break;
      case PttKey.control:
        isKeyPressed = (rawFlags & maskControl) != 0;
        break;
      case PttKey.alt:
        isKeyPressed = (rawFlags & maskAlt) != 0;
        break;
      case PttKey.command:
        isKeyPressed = (rawFlags & maskCommand) != 0;
        break;
      case PttKey.capsLock:
        isKeyPressed = (rawFlags & maskCapsLock) != 0;
        break;
      default:
        return;
    }

    if (isKeyPressed) {
      if (!_mumbleService.isTalking) {
        debugPrint('[HotkeyService] Native Modifier Down: $pttKey');
        _mumbleService.startPushToTalk();
      }
    } else {
      if (_mumbleService.isTalking) {
        debugPrint('[HotkeyService] Native Modifier Up: $pttKey');
        _mumbleService.stopPushToTalk();
      }
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
    WidgetsBinding.instance.removeObserver(this);
    hotKeyManager.unregisterAll();
  }
}
