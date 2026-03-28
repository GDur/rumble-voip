import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() async {
    await setupTestDependencies();
  });

  group('ChannelTree', () {
    late MockRustAudioEngine mockRustEngine;
    late MockDeviceLister mockDeviceLister;
    late SettingsService settingsService;
    late MumbleService mumbleService;

    setUp(() async {
      mockRustEngine = MockRustAudioEngine();
      mockDeviceLister = MockDeviceLister();
      
      when(() => mockRustEngine.getEventStream()).thenAnswer((_) => const Stream.empty());
      when(() => mockRustEngine.setConfig(config: any(named: 'config'))).thenAnswer((_) async {});
      
      when(() => mockDeviceLister.listInputDevices()).thenAnswer((_) async => []);
      when(() => mockDeviceLister.listOutputDevices()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settingsService = SettingsService(prefs);
      mumbleService = MumbleService(
        rustEngine: mockRustEngine,
        deviceLister: mockDeviceLister,
      );
    });

    testWidgets('renders channels and users correctly', (WidgetTester tester) async {
      const rootChannel = MumbleChannel(
        id: 0,
        name: 'Root Channel',
        parentId: null,
        position: 0,
        isEnterRestricted: false,
      );
      const subChannel = MumbleChannel(
        id: 1,
        name: 'Sub Channel',
        parentId: 0,
        position: 1,
        isEnterRestricted: false,
      );
      const user = MumbleUser(
        session: 100,
        name: 'Test User',
        channelId: 0,
        isTalking: false,
        isMuted: false,
        isDeafened: false,
        isSuppressed: false,
      );

      await tester.pumpWidget(
        ShadApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsService),
              ChangeNotifierProvider.value(value: mumbleService),
            ],
            child: Scaffold(
              body: ChannelTree(
                channels: const [rootChannel, subChannel],
                users: const [user],
                talkingUsers: const {},
                self: user,
                hasMicPermission: true,
                onChannelTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Root Channel'), findsOneWidget);
      expect(find.text('Sub Channel'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('(You)'), findsOneWidget);
    });

    testWidgets('hides empty channels when setting is enabled', (WidgetTester tester) async {
      const rootChannel = MumbleChannel(
        id: 0,
        name: 'Root Channel',
        parentId: null,
        position: 0,
        isEnterRestricted: false,
      );
      const emptyChannel = MumbleChannel(
        id: 1,
        name: 'Empty Channel',
        parentId: 0,
        position: 1,
        isEnterRestricted: false,
      );
      const user = MumbleUser(
        session: 100,
        name: 'Test User',
        channelId: 0,
        isTalking: false,
        isMuted: false,
        isDeafened: false,
        isSuppressed: false,
      );

      settingsService.setHideEmptyChannels(true);

      await tester.pumpWidget(
        ShadApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settingsService),
              ChangeNotifierProvider.value(value: mumbleService),
            ],
            child: Scaffold(
              body: ChannelTree(
                channels: const [rootChannel, emptyChannel],
                users: const [user],
                talkingUsers: const {},
                self: user,
                hasMicPermission: true,
                onChannelTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Root Channel'), findsOneWidget);
      expect(find.text('Empty Channel'), findsNothing);
    });
  });
}
