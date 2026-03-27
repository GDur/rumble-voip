import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PttKey { none, control, shift, alt, command, capsLock }

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
  static const String _kCaptureDeviceId = 'capture_device_id';
  static const String _kPlaybackDeviceId = 'playback_device_id';
  static const String _kInputGain = 'input_gain';
  static const String _kOutputVolume = 'output_volume';
  static const String _kIgnoreAccessibility = 'ignore_accessibility';
  static const String _kUserVolumes = 'user_volumes';
  static const String _kShowVolumeIndicator = 'show_volume_indicator';
  static const String _kOutgoingAudioBitrate = 'outgoing_audio_bitrate';
  static const String _kOutgoingAudioMsPerPacket = 'outgoing_audio_ms_per_packet';
  static const String _kIncomingJitterBufferMs = 'incoming_jitter_buffer_ms';
  static const String _kPlaybackHwBufferMs = 'playback_hw_buffer_ms';
  static const String _kRememberLastChannel = 'remember_last_channel';

  final SharedPreferences _prefs;

  PttKey _pttKey;
  bool _pttSuppress;
  ThemeMode _themeMode;
  Map<String, dynamic>? _customHotkey;
  bool _reconnectToLastServer;
  String? _lastServerJson;
  String? _captureDeviceId;
  String? _playbackDeviceId;
  double _inputGain;
  double _outputVolume;
  bool _ignoreAccessibility;
  bool _showVolumeIndicator;
  final Map<String, double> _userVolumes;
  int _outgoingAudioBitrate;
  int _outgoingAudioMsPerPacket;
  int _incomingJitterBufferMs;
  int _playbackHwBufferMs;
  bool _rememberLastChannel;

  SettingsService(this._prefs)
    : _pttKey = PttKey.values[_prefs.getInt(_kPttKey) ?? 0],
      _pttSuppress = _prefs.getBool(_kPttSuppress) ?? true,
      _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 2],
      _reconnectToLastServer = _prefs.getBool(_kReconnectToLastServer) ?? false,
      _lastServerJson = _prefs.getString(_kLastServerJson),
      _captureDeviceId = _prefs.getString(_kCaptureDeviceId),
      _playbackDeviceId = _prefs.getString(_kPlaybackDeviceId),
      _inputGain = _prefs.getDouble(_kInputGain) ?? 1.0,
      _outputVolume = _prefs.getDouble(_kOutputVolume) ?? 1.0,
      _ignoreAccessibility = _prefs.getBool(_kIgnoreAccessibility) ?? false,
      _showVolumeIndicator = _prefs.getBool(_kShowVolumeIndicator) ?? true,
      _outgoingAudioBitrate = _prefs.getInt(_kOutgoingAudioBitrate) ?? 72000,
      _outgoingAudioMsPerPacket = _prefs.getInt(_kOutgoingAudioMsPerPacket) ?? 10,
      _incomingJitterBufferMs = _prefs.getInt(_kIncomingJitterBufferMs) ?? 40,
      _playbackHwBufferMs = _prefs.getInt(_kPlaybackHwBufferMs) ?? 0,
      _rememberLastChannel = _prefs.getBool(_kRememberLastChannel) ?? true,
      _userVolumes = {} {
    // Load user volumes
    final List<String>? userVols = _prefs.getStringList(_kUserVolumes);
    if (userVols != null) {
      for (final s in userVols) {
        final parts = s.split(':');
        if (parts.length == 2) {
          final name = parts[0];
          final vol = double.tryParse(parts[1]);
          if (vol != null) {
            _userVolumes[name] = vol;
          }
        }
      }
    }

    final String? customJson = _prefs.getString(_kCustomHotkey);
    if (customJson != null) {
      try {
        _customHotkey = Map<String, dynamic>.from(
          Uri.parse('http://foo?$customJson').queryParameters,
        );
      } catch (_) {}
    }
  }

  PttKey get pttKey => _pttKey;
  bool get pttSuppress => _pttSuppress;
  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic>? get customHotkey => _customHotkey;
  bool get reconnectToLastServer => _reconnectToLastServer;
  String? get lastServerJson => _lastServerJson;
  String? get captureDeviceId => _captureDeviceId;
  String? get playbackDeviceId => _playbackDeviceId;
  double get inputGain => _inputGain;
  double get outputVolume => _outputVolume;
  bool get ignoreAccessibility => _ignoreAccessibility;
  bool get showVolumeIndicator => _showVolumeIndicator;
  int get outgoingAudioBitrate => _outgoingAudioBitrate;
  int get outgoingAudioMsPerPacket => _outgoingAudioMsPerPacket;
  int get incomingJitterBufferMs => _incomingJitterBufferMs;
  int get playbackHwBufferMs => _playbackHwBufferMs;
  bool get rememberLastChannel => _rememberLastChannel;
  Map<String, double> get userVolumes => Map.unmodifiable(_userVolumes);

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
      await _prefs.setString(
        _kCustomHotkey,
        Uri(
          queryParameters: hotkey.map((k, v) => MapEntry(k, v.toString())),
        ).query,
      );
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

  Future<void> setCaptureDeviceId(String? id) async {
    _captureDeviceId = id;
    if (id != null) {
      await _prefs.setString(_kCaptureDeviceId, id);
    } else {
      await _prefs.remove(_kCaptureDeviceId);
    }
    notifyListeners();
  }

  Future<void> setPlaybackDeviceId(String? id) async {
    _playbackDeviceId = id;
    if (id != null) {
      await _prefs.setString(_kPlaybackDeviceId, id);
    } else {
      await _prefs.remove(_kPlaybackDeviceId);
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

  Future<void> setShowVolumeIndicator(bool value) async {
    _showVolumeIndicator = value;
    await _prefs.setBool(_kShowVolumeIndicator, value);
    notifyListeners();
  }

  Future<void> setUserVolume(String name, double volume) async {
    _userVolumes[name] = volume;
    final List<String> userVols =
        _userVolumes.entries.map((e) => '${e.key}:${e.value}').toList();
    await _prefs.setStringList(_kUserVolumes, userVols);
    notifyListeners();
  }

  double getUserVolume(String name) {
    return _userVolumes[name] ?? 1.0;
  }

  Future<void> setOutgoingAudioBitrate(int bitrate) async {
    _outgoingAudioBitrate = bitrate;
    await _prefs.setInt(_kOutgoingAudioBitrate, bitrate);
    notifyListeners();
  }

  Future<void> setOutgoingAudioMsPerPacket(int frameMs) async {
    _outgoingAudioMsPerPacket = frameMs;
    await _prefs.setInt(_kOutgoingAudioMsPerPacket, frameMs);
    notifyListeners();
  }

  Future<void> setIncomingJitterBufferMs(int ms) async {
    _incomingJitterBufferMs = ms;
    await _prefs.setInt(_kIncomingJitterBufferMs, ms);
    notifyListeners();
  }

  Future<void> setPlaybackHwBufferMs(int ms) async {
    _playbackHwBufferMs = ms;
    await _prefs.setInt(_kPlaybackHwBufferMs, ms);
    notifyListeners();
  }
  
  Future<void> setRememberLastChannel(bool value) async {
    _rememberLastChannel = value;
    await _prefs.setBool(_kRememberLastChannel, value);
    notifyListeners();
  }
}
