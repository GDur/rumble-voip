import 'package:flutter/foundation.dart';
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

  final SharedPreferences _prefs;

  PttKey _pttKey;
  bool _pttSuppress;

  SettingsService(this._prefs)
      : _pttKey = PttKey.values[_prefs.getInt(_kPttKey) ?? 0],
        _pttSuppress = _prefs.getBool(_kPttSuppress) ?? true;

  PttKey get pttKey => _pttKey;
  bool get pttSuppress => _pttSuppress;

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
