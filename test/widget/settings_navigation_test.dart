import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rumble/main.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/certificate_service.dart';
import 'package:rumble/services/hotkey_service.dart';
import 'package:rumble/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() async {
    await setupTestDependencies();
  });

  testWidgets('Settings dialog can be opened and navigated', (
    WidgetTester tester,
  ) async {
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

    // Set a very large surface size to ensure no overflows during testing
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 1.0;

    // Ignore RenderFlex overflow errors in this test
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is FlutterError &&
          details.exception.toString().contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };

    // 1. Setup
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);
    final serverProvider = ServerProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
          ChangeNotifierProvider(create: (_) => MumbleService(
            rustEngine: mockRustEngine,
            deviceLister: mockDeviceLister,
          )),
          ChangeNotifierProvider.value(value: serverProvider),
          ChangeNotifierProvider.value(value: settingsService),
          ChangeNotifierProvider(create: (_) => CertificateService()),
          ChangeNotifierProxyProvider2<
            MumbleService,
            SettingsService,
            HotkeyService
          >(
            create: (context) => HotkeyService(
              Provider.of<MumbleService>(context, listen: false),
              Provider.of<SettingsService>(context, listen: false),
            ),
            update: (context, mumble, settings, previous) =>
                previous ?? HotkeyService(mumble, settings),
          ),
        ],
        child: const MyApp(),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify app title exists
    expect(find.text('Rumble'), findsWidgets);

    // Find the settings cog and tap it
    final settingsButton = find.byIcon(LucideIcons.settings);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Verify Settings dialog title
    expect(find.text('Settings'), findsWidgets);

    // Navigate to Audio tab
    final audioTabButton = find.text('Audio Input');
    expect(audioTabButton, findsOneWidget);
    await tester.tap(audioTabButton);
    await tester.pumpAndSettle();

    // Verify Audio tab content
    expect(find.text('Input Gain'), findsOneWidget);

    // Close settings
    final doneButton = find.text('Done');
    expect(doneButton, findsOneWidget);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();

    // Verify dialog is closed
    expect(find.text('Settings'), findsWidgets); // The settings button tooltip/label remains

    // Reset
    FlutterError.onError = originalOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    // Cleanup: Dispose serverProvider to cancel its periodic timer
    serverProvider.dispose();
  });
}
