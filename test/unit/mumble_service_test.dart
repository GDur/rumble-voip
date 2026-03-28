import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() async {
    await setupTestDependencies();
  });

  testWidgets('MumbleService initialization', (WidgetTester tester) async {
    final mockRustEngine = MockRustAudioEngine();
    final mockDeviceLister = MockDeviceLister();
    
    // Mock audio engine methods
    when(() => mockRustEngine.getEventStream()).thenAnswer((_) => const Stream.empty());
    when(() => mockRustEngine.setConfig(config: any(named: 'config'))).thenAnswer((_) async {});
    when(() => mockRustEngine.setInputGain(gain: any(named: 'gain'))).thenAnswer((_) async {});
    when(() => mockRustEngine.setOutputVolume(volume: any(named: 'volume'))).thenAnswer((_) async {});

    // Mock device lister methods
    when(() => mockDeviceLister.listInputDevices()).thenAnswer((_) async => []);
    when(() => mockDeviceLister.listOutputDevices()).thenAnswer((_) async => []);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);

    final mumbleService = MumbleService(
      rustEngine: mockRustEngine,
      deviceLister: mockDeviceLister,
    );
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

  test('MumbleService toggle methods (disconnected)', () async {
    final mockRustEngine = MockRustAudioEngine();
    final mockDeviceLister = MockDeviceLister();
    
    final mumbleService = MumbleService(
      rustEngine: mockRustEngine,
      deviceLister: mockDeviceLister,
    );
    
    // Should not crash and should remain false if not connected
    expect(mumbleService.isMuted, isFalse);
    mumbleService.toggleMute();
    expect(mumbleService.isMuted, isFalse); 

    expect(mumbleService.isDeafened, isFalse);
    mumbleService.toggleDeafen();
    expect(mumbleService.isDeafened, isFalse);
  });
}
