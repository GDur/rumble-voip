import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';

class HotkeyService extends ChangeNotifier with WidgetsBindingObserver {
  final MumbleService _mumbleService;
  final SettingsService _settingsService;
  final _permissionsChannel = const MethodChannel('com.rumble.app/permissions');
  
  final ValueNotifier<bool> hasAccessibilityPermission = ValueNotifier<bool>(true);
  final ValueNotifier<String?> appPath = ValueNotifier<String?>(null);
  HotKey? _currentHotKey;

  HotkeyService(this._mumbleService, this._settingsService) {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _init() async {
    
    _permissionsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onModifierFlagsChanged') {
        _handleNativeModifierFlags(call.arguments as int);
      } else if (call.method == 'onNativeKey') {
        _handleWindowsNativeKey(call.arguments);
      }
    });

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await checkPermission();
      await _fetchAppPath();
    }
    
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await _updateWindowsPttSettings();
    }

    _updateHotKey();
    _settingsService.addListener(_updateHotKey);
    
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _settingsService.addListener(_updateWindowsPttSettings);
    }
  }

  Future<void> _updateWindowsPttSettings() async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    
    final settings = _settingsService;
    int vkCode = 0;
    
    if (settings.pttKey != PttKey.none) {
      switch (settings.pttKey) {
        case PttKey.control: vkCode = 0x11; break; 
        case PttKey.shift: vkCode = 0x10; break;   
        case PttKey.alt: vkCode = 0x12; break;     
        case PttKey.command: vkCode = 0x5B; break; 
        case PttKey.capsLock: vkCode = 0x14; break; 
        default: break;
      }
    } else if (settings.customHotkey != null) {
      vkCode = int.tryParse(settings.customHotkey!['vkCode']?.toString() ?? '0') ?? 0;
    }

    try {
      await _permissionsChannel.invokeMethod('setPttVkCode', {
        'vkCode': vkCode,
        'suppress': settings.pttSuppress,
      });
    } catch (e) {
      debugPrint('HotkeyService: Failed to set Windows PTT VK Code: $e');
    }
  }

  void _handleWindowsNativeKey(dynamic arguments) {
    if (arguments is! Map) return;
    final event = arguments['event'];
    if (event == 'down') {
      _mumbleService.startPushToTalk();
    } else if (event == 'up') {
      _mumbleService.stopPushToTalk();
    }
  }

  Future<void> _updateHotKey() async {
    final settings = _settingsService;
    final mumbleService = _mumbleService;

    // hotkey_manager doesn't support Android/iOS. Skip to avoid MissingPluginException.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }

    await hotKeyManager.unregisterAll();

    if (settings.pttKey != PttKey.none) {
      // Standalone modifiers are handled via native monitors on macOS/Windows
      if (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) {
        return;
      }

      // Fallback for Linux (X11)
      final key = _mapPttKeyToPhysicalKey(settings.pttKey);
      if (key == null) return;
      _currentHotKey = HotKey(key: key, scope: HotKeyScope.system);
      await hotKeyManager.register(
        _currentHotKey!,
        keyDownHandler: (_) => mumbleService.startPushToTalk(),
        keyUpHandler: (_) => mumbleService.stopPushToTalk(),
      );
      return;
    }

    if (settings.customHotkey != null) {
      final usbUsage = int.tryParse(
            settings.customHotkey!['usbHidUsage']?.toString() ?? '',
          ) ??
          0;
      final modsString = settings.customHotkey!['modifiers'] ?? '';

      final key = _findPhysicalKeyByUsbHidUsage(usbUsage);
      if (key != null) {
        // If it's a standalone modifier on macOS/Windows, we handle it via native monitors
        bool isStandaloneModifier =
            modsString.isEmpty && _isModifierKey(key);
        if (isStandaloneModifier &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows)) {
          // Special case for Windows: send the custom VK code to the native hook
          if (defaultTargetPlatform == TargetPlatform.windows) {
            _updateWindowsPttSettings();
          }
          return;
        }

        List<HotKeyModifier> modifiers = [];
        if (modsString.contains('control'))
          modifiers.add(HotKeyModifier.control);
        if (modsString.contains('shift')) modifiers.add(HotKeyModifier.shift);
        if (modsString.contains('alt')) modifiers.add(HotKeyModifier.alt);
        if (modsString.contains('meta')) modifiers.add(HotKeyModifier.meta);

        _currentHotKey = HotKey(
          key: key,
          modifiers: modifiers,
          scope: HotKeyScope.system,
        );

        try {
          await hotKeyManager.register(
            _currentHotKey!,
            keyDownHandler: (_) => mumbleService.startPushToTalk(),
            keyUpHandler: (_) => mumbleService.stopPushToTalk(),
          );
        } catch (e) {
          debugPrint('HotkeyService: Error registering custom hotkey: $e');
        }
      }
    }
  }

  bool _isModifierKey(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight ||
        key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight ||
        key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight ||
        key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight ||
        key == PhysicalKeyboardKey.capsLock;
  }

  PhysicalKeyboardKey? _findPhysicalKeyByUsbHidUsage(int usage) {
    if (usage == 0) return null;

    // Common Alpha Keys (A-Z)
    if (usage >= 0x00070004 && usage <= 0x0007001d) {
      const keys = [
        PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.keyB, PhysicalKeyboardKey.keyC,
        PhysicalKeyboardKey.keyD, PhysicalKeyboardKey.keyE, PhysicalKeyboardKey.keyF,
        PhysicalKeyboardKey.keyG, PhysicalKeyboardKey.keyH, PhysicalKeyboardKey.keyI,
        PhysicalKeyboardKey.keyJ, PhysicalKeyboardKey.keyK, PhysicalKeyboardKey.keyL,
        PhysicalKeyboardKey.keyM, PhysicalKeyboardKey.keyN, PhysicalKeyboardKey.keyO,
        PhysicalKeyboardKey.keyP, PhysicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyR,
        PhysicalKeyboardKey.keyS, PhysicalKeyboardKey.keyT, PhysicalKeyboardKey.keyU,
        PhysicalKeyboardKey.keyV, PhysicalKeyboardKey.keyW, PhysicalKeyboardKey.keyX,
        PhysicalKeyboardKey.keyY, PhysicalKeyboardKey.keyZ,
      ];
      return keys[usage - 0x00070004];
    }
    
    // Numbers (1-0)
    if (usage >= 0x0007001e && usage <= 0x00070027) {
      const keys = [
        PhysicalKeyboardKey.digit1, PhysicalKeyboardKey.digit2, PhysicalKeyboardKey.digit3,
        PhysicalKeyboardKey.digit4, PhysicalKeyboardKey.digit5, PhysicalKeyboardKey.digit6,
        PhysicalKeyboardKey.digit7, PhysicalKeyboardKey.digit8, PhysicalKeyboardKey.digit9,
        PhysicalKeyboardKey.digit0,
      ];
      return keys[usage - 0x0007001e];
    }

    // Function keys (F1-F12)
    if (usage >= 0x0007003a && usage <= 0x00070045) {
      const keys = [
        PhysicalKeyboardKey.f1, PhysicalKeyboardKey.f2, PhysicalKeyboardKey.f3,
        PhysicalKeyboardKey.f4, PhysicalKeyboardKey.f5, PhysicalKeyboardKey.f6,
        PhysicalKeyboardKey.f7, PhysicalKeyboardKey.f8, PhysicalKeyboardKey.f9,
        PhysicalKeyboardKey.f10, PhysicalKeyboardKey.f11, PhysicalKeyboardKey.f12,
      ];
      return keys[usage - 0x0007003a];
    }

    // Other common keys
    switch (usage) {
      case 0x00070028: return PhysicalKeyboardKey.enter;
      case 0x00070029: return PhysicalKeyboardKey.escape;
      case 0x0007002a: return PhysicalKeyboardKey.backspace;
      case 0x0007002b: return PhysicalKeyboardKey.tab;
      case 0x0007002c: return PhysicalKeyboardKey.space;
      case 0x0007004f: return PhysicalKeyboardKey.arrowRight;
      case 0x00070050: return PhysicalKeyboardKey.arrowLeft;
      case 0x00070051: return PhysicalKeyboardKey.arrowDown;
      case 0x00070052: return PhysicalKeyboardKey.arrowUp;
      case 0x00070039: return PhysicalKeyboardKey.capsLock;
      case 0x000700e0: return PhysicalKeyboardKey.controlLeft;
      case 0x000700e1: return PhysicalKeyboardKey.shiftLeft;
      case 0x000700e2: return PhysicalKeyboardKey.altLeft;
      case 0x000700e3: return PhysicalKeyboardKey.metaLeft;
      case 0x000700e4: return PhysicalKeyboardKey.controlRight;
      case 0x000700e5: return PhysicalKeyboardKey.shiftRight;
      case 0x000700e6: return PhysicalKeyboardKey.altRight;
      case 0x000700e7: return PhysicalKeyboardKey.metaRight;
      default: return null;
    }
  }

  void _handleNativeModifierFlags(int flags) {
    final settings = _settingsService;
    bool isPressed = false;

    if (settings.pttKey != PttKey.none) {
      switch (settings.pttKey) {
        case PttKey.control: isPressed = (flags & (1 << 18)) != 0; break;
        case PttKey.shift: isPressed = (flags & (1 << 17)) != 0; break;
        case PttKey.alt: isPressed = (flags & (1 << 19)) != 0; break;
        case PttKey.command: isPressed = (flags & (1 << 20)) != 0; break;
        case PttKey.capsLock: isPressed = (flags & (1 << 16)) != 0; break;
        default: break;
      }
    } else if (settings.customHotkey != null) {
      final usbUsage = int.tryParse(
            settings.customHotkey!['usbHidUsage']?.toString() ?? '',
          ) ??
          0;
      final modsString = settings.customHotkey!['modifiers'] ?? '';
      final key = _findPhysicalKeyByUsbHidUsage(usbUsage);

      // We only handle standalone modifiers here
      if (key != null && modsString.isEmpty && _isModifierKey(key)) {
        isPressed = _checkFlags(flags, key);
      } else {
        return; // Not a standalone modifier custom hotkey
      }
    } else {
      return;
    }

    if (isPressed) {
      _mumbleService.startPushToTalk();
    } else {
      _mumbleService.stopPushToTalk();
    }
  }

  bool _checkFlags(int flags, PhysicalKeyboardKey key) {
    if (key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight) return (flags & (1 << 17)) != 0;
    if (key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight) return (flags & (1 << 18)) != 0;
    if (key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight) return (flags & (1 << 19)) != 0;
    if (key == PhysicalKeyboardKey.metaLeft ||
        key == PhysicalKeyboardKey.metaRight) return (flags & (1 << 20)) != 0;
    if (key == PhysicalKeyboardKey.capsLock) return (flags & (1 << 16)) != 0;
    return false;
  }

  PhysicalKeyboardKey? _mapPttKeyToPhysicalKey(PttKey key) {
    switch (key) {
      case PttKey.control: return PhysicalKeyboardKey.controlLeft;
      case PttKey.shift: return PhysicalKeyboardKey.shiftLeft;
      case PttKey.alt: return PhysicalKeyboardKey.altLeft;
      case PttKey.command: return PhysicalKeyboardKey.metaLeft;
      case PttKey.capsLock: return PhysicalKeyboardKey.capsLock;
      default: return null;
    }
  }

  Future<void> checkPermission() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      // Small delay to let the OS catch up if we just returned from settings
      await Future.delayed(const Duration(milliseconds: 100));
      
      bool granted = await _permissionsChannel.invokeMethod('checkAccessibility');
      
      // If not granted, try once more after a slightly longer delay
      if (!granted) {
        await Future.delayed(const Duration(milliseconds: 500));
        granted = await _permissionsChannel.invokeMethod('checkAccessibility');
      }
      
      hasAccessibilityPermission.value = granted;
      debugPrint('HotkeyService: Accessibility check result: $granted');
    } catch (e) {
      debugPrint('HotkeyService: Error checking accessibility: $e');
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _permissionsChannel.invokeMethod('openAccessibility');
    } catch (e) {
      debugPrint('HotkeyService: Error opening accessibility settings: $e');
    }
  }

  Future<void> _fetchAppPath() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      final String? path = await _permissionsChannel.invokeMethod('getAppPath');
      appPath.value = path;
    } catch (e) {
      debugPrint('HotkeyService: Error fetching app path: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermission();
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_updateHotKey);
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _settingsService.removeListener(_updateWindowsPttSettings);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
