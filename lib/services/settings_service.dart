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
  static const String _kWindowWidth = 'window_width';
  static const String _kWindowHeight = 'window_height';
  static const String _kWindowX = 'window_x';
  static const String _kWindowY = 'window_y';
  static const String _kReconnectToLastServer = 'reconnect_last_server';
  static const String _kLastServerJson = 'last_server_json';
  static const String _kInputDeviceId = 'input_device_id';
  static const String _kOutputDeviceId = 'output_device_id';
  static const String _kInputGain = 'input_gain';
  static const String _kOutputVolume = 'output_volume';
  static const String _kIgnoreAccessibility = 'ignore_accessibility';

  final SharedPreferences _prefs;

  PttKey _pttKey;
  bool _pttSuppress;
  ThemeMode _themeMode;
  Map<String, dynamic>? _customHotkey;
  bool _reconnectToLastServer;
  String? _lastServerJson;
  String? _inputDeviceId;
  String? _outputDeviceId;
  double _inputGain;
  double _outputVolume;
  bool _ignoreAccessibility;

  SettingsService(this._prefs)
      : _pttKey = PttKey.values[_prefs.getInt(_kPttKey) ?? 0],
        _pttSuppress = _prefs.getBool(_kPttSuppress) ?? true,
        _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 2],
        _reconnectToLastServer = _prefs.getBool(_kReconnectToLastServer) ?? false,
        _lastServerJson = _prefs.getString(_kLastServerJson),
        _inputDeviceId = _prefs.getString(_kInputDeviceId),
        _outputDeviceId = _prefs.getString(_kOutputDeviceId),
        _inputGain = _prefs.getDouble(_kInputGain) ?? 1.0,
        _outputVolume = _prefs.getDouble(_kOutputVolume) ?? 1.0,
        _ignoreAccessibility = _prefs.getBool(_kIgnoreAccessibility) ?? false {
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
  bool get reconnectToLastServer => _reconnectToLastServer;
  String? get lastServerJson => _lastServerJson;
  String? get inputDeviceId => _inputDeviceId;
  String? get outputDeviceId => _outputDeviceId;
  double get inputGain => _inputGain;
  double get outputVolume => _outputVolume;
  bool get ignoreAccessibility => _ignoreAccessibility;

  double? get windowWidth => _prefs.getDouble(_kWindowWidth);
  double? get windowHeight => _prefs.getDouble(_kWindowHeight);
  double? get windowX => _prefs.getDouble(_kWindowX);
  double? get windowY => _prefs.getDouble(_kWindowY);

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

  Future<void> setWindowSize(Size size) async {
    await _prefs.setDouble(_kWindowWidth, size.width);
    await _prefs.setDouble(_kWindowHeight, size.height);
  }

  Future<void> setWindowPosition(Offset position) async {
    await _prefs.setDouble(_kWindowX, position.dx);
    await _prefs.setDouble(_kWindowY, position.dy);
  }

  Future<void> setReconnectToLastServer(bool value) async {
    _reconnectToLastServer = value;
    await _prefs.setBool(_kReconnectToLastServer, value);
    notifyListeners();
  }

  Future<void> setLastServerJson(String? json) async {
    _lastServerJson = json;
    if (json != null) {
      await _prefs.setString(_kLastServerJson, json);
    } else {
      await _prefs.remove(_kLastServerJson);
    }
    notifyListeners();
  }

  Future<void> setInputDeviceId(String? id) async {
    _inputDeviceId = id;
    if (id != null) {
      await _prefs.setString(_kInputDeviceId, id);
    } else {
      await _prefs.remove(_kInputDeviceId);
    }
    notifyListeners();
  }

  Future<void> setOutputDeviceId(String? id) async {
    _outputDeviceId = id;
    if (id != null) {
      await _prefs.setString(_kOutputDeviceId, id);
    } else {
      await _prefs.remove(_kOutputDeviceId);
    }
    notifyListeners();
  }

  Future<void> setInputGain(double gain) async {
    _inputGain = gain;
    await _prefs.setDouble(_kInputGain, gain);
    notifyListeners();
  }

  Future<void> setOutputVolume(double volume) async {
    _outputVolume = volume;
    await _prefs.setDouble(_kOutputVolume, volume);
    notifyListeners();
  }

  Future<void> setIgnoreAccessibility(bool value) async {
    _ignoreAccessibility = value;
    await _prefs.setBool(_kIgnoreAccessibility, value);
    notifyListeners();
  }
}
