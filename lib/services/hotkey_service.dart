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
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      return;
    }

    await hotKeyManager.unregisterAll();

    if (settings.pttKey != PttKey.none) {
      // Standalone modifiers are handled via native monitors on macOS/Windows
      if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows) {
        return;
      }
      
      // Fallback for Linux (X11)
      final key = _mapPttKeyToPhysicalKey(settings.pttKey);
      if (key == null) return;
      _currentHotKey = HotKey(key: key, scope: HotKeyScope.system);
      await hotKeyManager.register(_currentHotKey!, 
        keyDownHandler: (_) => mumbleService.startPushToTalk(),
        keyUpHandler: (_) => mumbleService.stopPushToTalk(),
      );
      return;
    }

    if (settings.customHotkey != null) {
      if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
         return; // Handled by native
      }

      // Linux/Generic Custom Hotkey
      try {
        // In a real app we'd need a robust string -> PhysicalKeyboardKey mapper
        // for hotkey_manager fallback on Linux.
      } catch (e) {
        debugPrint('HotkeyService: Error registering custom hotkey: $e');
      }
    }
  }

  void _handleNativeModifierFlags(int flags) {
    final settings = _settingsService;
    if (settings.pttKey == PttKey.none) return;

    bool isPressed = false;
    switch (settings.pttKey) {
      case PttKey.control: isPressed = (flags & (1 << 18)) != 0; break;
      case PttKey.shift: isPressed = (flags & (1 << 17)) != 0; break;
      case PttKey.alt: isPressed = (flags & (1 << 19)) != 0; break;
      case PttKey.command: isPressed = (flags & (1 << 20)) != 0; break;
      case PttKey.capsLock: isPressed = (flags & (1 << 16)) != 0; break;
      default: break;
    }

    if (isPressed) {
      _mumbleService.startPushToTalk();
    } else {
      _mumbleService.stopPushToTalk();
    }
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
      final bool granted = await _permissionsChannel.invokeMethod('checkAccessibility');
      hasAccessibilityPermission.value = granted;
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
