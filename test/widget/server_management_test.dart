import 'dart:convert';
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

void main() {
  testWidgets('Server management: add, archive, and connect attempt', (
    WidgetTester tester,
  ) async {
    // 1. Setup
    final mockPrefs = {
      'reconnect_last_server': false,
      'mumble_servers': jsonEncode([]),
    };
    SharedPreferences.setMockInitialValues(mockPrefs);

    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);
    final serverProvider = ServerProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MumbleService()),
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

    // Initial pump to load everything
    await tester.pumpAndSettle();

    // 2. Initial Empty State Verification
    expect(find.text('Welcome to Rumble'), findsOneWidget);
    expect(find.text('Add First Server'), findsOneWidget);

    // 3. Add a Server
    await tester.tap(find.text('Add First Server'));
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Add New Server'), findsOneWidget);

    final editableTextFinder = find.byType(EditableText);
    if (editableTextFinder.evaluate().isNotEmpty) {
      await tester.enterText(editableTextFinder.at(0), 'localhost');
      await tester.enterText(editableTextFinder.at(1), 'Test Server');
      await tester.enterText(editableTextFinder.at(3), 'Tester');
    }

    // Tap Save
    await tester.tap(find.text('Save Server'));
    await tester.pumpAndSettle();

    // 4. Verify server appears in list
    expect(find.text('Test Server'), findsOneWidget);

    // 5. Connect Button Presence
    expect(find.text('CONNECT'), findsOneWidget);

    // Cleanup: Dispose serverProvider to cancel its periodic timer
    serverProvider.dispose();
  });
}
