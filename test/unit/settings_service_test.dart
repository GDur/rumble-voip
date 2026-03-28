import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    test('initializes with default values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      expect(settings.inputGain, 1.0);
      expect(settings.outputVolume, 1.0);
      expect(settings.outgoingAudioBitrate, 72000);
      expect(settings.outgoingAudioMsPerPacket, 10);
      expect(settings.incomingJitterBufferMs, 40);
      expect(settings.rememberLastChannel, true);
      expect(settings.hideEmptyChannels, false);
    });

    test('saves and loads input gain', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      settings.setInputGain(1.5);
      expect(settings.inputGain, 1.5);
      expect(prefs.getDouble('input_gain'), 1.5);

      final newSettings = SettingsService(prefs);
      expect(newSettings.inputGain, 1.5);
    });

    test('saves and loads output volume', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      settings.setOutputVolume(0.8);
      expect(settings.outputVolume, 0.8);
      expect(prefs.getDouble('output_volume'), 0.8);

      final newSettings = SettingsService(prefs);
      expect(newSettings.outputVolume, 0.8);
    });

    test('toggles hide empty channels', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      expect(settings.hideEmptyChannels, false);
      settings.setHideEmptyChannels(true);
      expect(settings.hideEmptyChannels, true);
      expect(prefs.getBool('hide_empty_channels'), true);
    });

    test('manages user volumes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      settings.setUserVolume('user1', 1.2);
      expect(settings.getUserVolume('user1'), 1.2);
      expect(settings.getUserVolume('user2'), 1.0); // Default

      final storedVols = prefs.getStringList('user_volumes');
      expect(storedVols, contains('user1:1.2'));
    });
  });
}
