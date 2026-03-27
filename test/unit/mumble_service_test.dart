import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MumbleService initialization', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);

    final mumbleService = MumbleService();
    await mumbleService.initialize(
      settingsService,
      1.0,
      1.0,
      null,
      null,
    );
    
    expect(mumbleService.isConnected, isFalse);
    expect(mumbleService.isTalking, isFalse);
  });
}
