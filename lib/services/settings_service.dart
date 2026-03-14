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

  final SharedPreferences _prefs;

  PttKey _pttKey;
  bool _pttSuppress;
  ThemeMode _themeMode;

  SettingsService(this._prefs)
      : _pttKey = PttKey.values[_prefs.getInt(_kPttKey) ?? 0],
        _pttSuppress = _prefs.getBool(_kPttSuppress) ?? true,
        _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 2]; // Default to dark (2)

  PttKey get pttKey => _pttKey;
  bool get pttSuppress => _pttSuppress;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setPttKey(PttKey key) async {
    _pttKey = key;
    await _prefs.setInt(_kPttKey, key.index);
    notifyListeners();
  }

  Future<void> setPttSuppress(bool suppress) async {
    _pttSuppress = suppress;
    await _prefs.setBool(_kPttSuppress, suppress);
    notifyListeners();
  }
}
