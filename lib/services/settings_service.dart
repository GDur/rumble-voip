import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PttKey {
  none,
  control,
  shift,
  alt,
  command,
  capsLock,
}

class SettingsService extends ChangeNotifier {
  static const String _kPttKey = 'ptt_key';
  static const String _kPttSuppress = 'ptt_suppress';
  static const String _kThemeMode = 'theme_mode';
  static const String _kCustomHotkey = 'custom_hotkey';

  final SharedPreferences _prefs;

  PttKey _pttKey;
  bool _pttSuppress;
  ThemeMode _themeMode;
  Map<String, dynamic>? _customHotkey;

  SettingsService(this._prefs)
      : _pttKey = PttKey.values[_prefs.getInt(_kPttKey) ?? 0],
        _pttSuppress = _prefs.getBool(_kPttSuppress) ?? true,
        _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 2] {
    final String? customJson = _prefs.getString(_kCustomHotkey);
    if (customJson != null) {
      try {
        _customHotkey = Map<String, dynamic>.from(Uri.parse('http://foo?$customJson').queryParameters);
      } catch (_) {}
    }
  }

  PttKey get pttKey => _pttKey;
  bool get pttSuppress => _pttSuppress;
  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic>? get customHotkey => _customHotkey;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setPttKey(PttKey key) async {
    _pttKey = key;
    await _prefs.setInt(_kPttKey, key.index);
    if (key != PttKey.none) {
      _customHotkey = null; // Clear custom when preset is chosen
      await _prefs.remove(_kCustomHotkey);
    }
    notifyListeners();
  }

  Future<void> setPttSuppress(bool suppress) async {
    _pttSuppress = suppress;
    await _prefs.setBool(_kPttSuppress, suppress);
    notifyListeners();
  }

  Future<void> setCustomHotkey(Map<String, dynamic>? hotkey) async {
    _customHotkey = hotkey;
    if (hotkey != null) {
      _pttKey = PttKey.none; // Clear preset when custom is chosen
      await _prefs.setInt(_kPttKey, PttKey.none.index);
      await _prefs.setString(_kCustomHotkey, Uri(queryParameters: hotkey.map((k, v) => MapEntry(k, v.toString()))).query);
    } else {
      await _prefs.remove(_kCustomHotkey);
    }
    notifyListeners();
  }
}
