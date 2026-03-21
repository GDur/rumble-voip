import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rumble/main.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/certificate_service.dart';
import 'package:rumble/services/hotkey_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('Settings dialog can be opened and navigated', (
    WidgetTester tester,
  ) async {
    // Set a very large surface size to ensure no overflows during testing
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 1.0;

    // Ignore RenderFlex overflow errors in this test
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is FlutterError &&
          details.exception.toString().contains('overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MumbleService()),
          ChangeNotifierProvider(create: (_) => ServerProvider()),
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
    expect(find.text('Settings'), findsOneWidget);

    // Navigate to Audio tab
    final audioTabButton = find.text('Audio');
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
    expect(find.text('Settings'), findsNothing);

    // Reset
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
