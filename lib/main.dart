import 'dart:async';
import 'package:rumble/utils/layout_constants.dart';
import 'dart:convert';
import 'dart:io';
import 'package:rumble/services/background_service.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:rumble/utils/permissions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/components/rumble_tooltip.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/certificate_service.dart';
import 'package:rumble/services/hotkey_service.dart';
import 'package:rumble/services/update_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rumble/components/server_card.dart';
import 'package:rumble/components/ptt_button.dart';
import 'package:rumble/components/add_server_dialog.dart';
import 'package:rumble/components/settings/settings_dialog.dart';
import 'package:rumble/components/permission_banner.dart';
import 'package:rumble/components/hotkey_recorder.dart';
import 'package:rumble/components/chat_view.dart';
import 'package:rumble/models/hotkey_action.dart';
import 'package:rumble/services/connectivity_service.dart';
import 'package:rumble/src/rust/frb_generated.dart';
import 'package:rumble/utils/logger.dart';
import 'package:rumble/components/loading_screen.dart';
import 'package:media_kit/media_kit.dart';

// Brand Colors
const kBrandGreen = Color(0xFF64FFDA);
const kBrandGreenText = Color(0xFF065F46);
const kBrandGreenButton = Color.fromARGB(255, 79, 196, 157);

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        MediaKit.ensureInitialized();
        debugPrint('[DEBUG] MediaKit initialized successfully');
      } catch (e) {
        debugPrint('[DEBUG] MediaKit initialization failed: $e');
      }
      await BackgroundService.initialize();

      // Request microphone permission immediately at startup on mobile
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        PermissionUtils.requestMicrophonePermission();
      }

      // Catch Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        developer.log(
          'Flutter Framework Error',
          error: details.exception,
          stackTrace: details.stack,
          level: 1000,
        );
      };

      // Catch asynchronous errors outside of the Flutter framework
      PlatformDispatcher.instance.onError = (error, stack) {
        developer.log(
          'Asynchronous Error',
          error: error,
          stackTrace: stack,
          level: 1000,
        );
        return true; // Error was handled
      };

      // Load environment variables
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // In many environments (like release or CI), .env might not exist.
        // We log it and continue so the app still starts correctly.
        debugPrint('Warning: .env file could not be loaded: $e');
      }

      // Initialize Rust
      await RustLib.init();
      setupLogger();

      final prefs = await SharedPreferences.getInstance();
      final settingsService = SettingsService(prefs);

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        // Initialize auto-updates (currently supports WinSparkle and Sparkle)
        UpdateService.instance.initialize();
        
        await windowManager.ensureInitialized();
        await hotKeyManager.unregisterAll();

        double? width = settingsService.windowWidth;
        double? height = settingsService.windowHeight;
        double? x = settingsService.windowX;
        double? y = settingsService.windowY;

        // Configure window initially hidden and transparent for fade-in
        WindowOptions windowOptions = WindowOptions(
          size: width != null && height != null
              ? Size(width, height)
              : const Size(1100, 750),
          center: x == null || y == null,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
          title: 'Rumble',
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          if (x != null && y != null) {
            await windowManager.setPosition(Offset(x, y));
          }
          // Start fully transparent
          await windowManager.setOpacity(0.0);
        });
      }

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ConnectivityService()),
            ChangeNotifierProvider(
              create: (_) => MumbleService()
                ..initialize(
                  settingsService,
                  settingsService.inputGain,
                  settingsService.outputVolume,
                  settingsService.captureDeviceId,
                  settingsService.playbackDeviceId,
                ),
            ),
            ChangeNotifierProvider(create: (_) => ServerProvider()),
            ChangeNotifierProvider.value(value: settingsService),
            ChangeNotifierProvider(
              create: (_) => CertificateService()..loadCertificates(),
            ),
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
    },
    (error, stack) {
      developer.log(
        'Unhandled Top-level Error',
        error: error,
        stackTrace: stack,
        level: 1000,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) => ShadApp(
        builder: (context, child) => _WindowResizeListener(child: child!),
        title: 'Rumble',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        // ... (styles kept same)
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadSlateColorScheme.light(
            primary: kBrandGreenText,
            primaryForeground: Colors.white,
          ),
          primaryButtonTheme: const ShadButtonTheme(
            backgroundColor: kBrandGreenButton,
            foregroundColor: Colors.white,
          ),
          primaryToastTheme: ShadToastTheme(
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 32),
            duration: const Duration(seconds: 4),
          ),
          destructiveToastTheme: ShadToastTheme(
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 32),
            duration: const Duration(seconds: 4),
          ),
          textTheme: ShadTextTheme(p: const TextStyle(fontFamily: 'Outfit')),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(
            primary: kBrandGreen,
            primaryForeground: Colors.black,
          ),
          primaryButtonTheme: const ShadButtonTheme(
            backgroundColor: kBrandGreen,
            foregroundColor: Colors.black,
          ),
          primaryToastTheme: ShadToastTheme(
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 32),
            duration: const Duration(seconds: 4),
          ),
          destructiveToastTheme: ShadToastTheme(
            alignment: Alignment.bottomCenter,
            offset: const Offset(0, 32),
            duration: const Duration(seconds: 4),
          ),
          textTheme: ShadTextTheme(p: const TextStyle(fontFamily: 'Outfit')),
        ),
        home: const LoadingPage(),
      ),
    );
  }
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Give window manager a moment to settle position/size before showing
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Wait for sizes/position to be applied
      await Future.delayed(const Duration(milliseconds: 150));

      // Show window (still at 0.0 opacity)
      await windowManager.show();
      await windowManager.focus();

      // Fade in smoothly
      double opacity = 0.0;
      const duration = Duration(milliseconds: 300);
      const steps = 15;
      final stepDelay = duration.inMilliseconds ~/ steps;

      for (int i = 1; i <= steps; i++) {
        await Future.delayed(Duration(milliseconds: stepDelay));
        opacity = i / steps;
        await windowManager.setOpacity(opacity);
      }

      // Ensure final opacity is 1.0
      await windowManager.setOpacity(1.0);
    }

    // Transition to HomeScreen smoothly
    if (mounted) {
      // Ensure we don't navigate while the navigator is locked (e.g., during initState)
      // On desktop, we've already awaited for window management. On mobile, we need a small delay or post-frame callback.
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen();
  }
}

class _WindowResizeListener extends StatefulWidget {
  final Widget child;
  const _WindowResizeListener({required this.child});

  @override
  State<_WindowResizeListener> createState() => _WindowResizeListenerState();
}

class _WindowResizeListenerState extends State<_WindowResizeListener>
    with WindowListener {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _saveWindowState() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      try {
        final settings = Provider.of<SettingsService>(context, listen: false);
        final size = await windowManager.getSize();
        final pos = await windowManager.getPosition();
        final isMaximized = await windowManager.isMaximized();

        // Avoid saving if window is minimized or too small (transition states)
        if (size.width > 200 && size.height > 200 && !isMaximized) {
          debugPrint('[DEBUG] Saving window - pos: $pos, size: $size');
          await settings.setWindowSize(size);
          await settings.setWindowPosition(pos);
        }
      } catch (e) {
        debugPrint('Error saving window state: $e');
      }
    });
  }

  @override
  void onWindowResized() => _saveWindowState();

  @override
  void onWindowMoved() => _saveWindowState();

  @override
  void onWindowResize() => _saveWindowState();

  @override
  void onWindowMove() => _saveWindowState();

  @override
  void onWindowMaximize() => _saveWindowState();

  @override
  void onWindowUnmaximize() => _saveWindowState();

  @override
  void onWindowFocus() => _saveWindowState();

  @override
  void onWindowBlur() => _saveWindowState();

  @override
  void onWindowClose() => _saveWindowState();

  @override
  Widget build(BuildContext context) => widget.child;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _connectingServerId;
  final _volumePopoverController = ShadPopoverController();

  @override
  void initState() {
    super.initState();
    // Wrap the initial server check in addPostFrameCallback to avoid the markNeedsBuild()
    // error during build. This ensures it runs after the first frame has finished.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLastServer();
    });

    // Listen for PTT errors/warnings globally in the Home Screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mumbleService = Provider.of<MumbleService>(context, listen: false);
      mumbleService.addListener(_handlePttWarning);
      
      final hotkeyService = Provider.of<HotkeyService>(context, listen: false);
      hotkeyService.addListener(_handleHotkeyError);
    });
  }

  @override
  void dispose() {
    _removePttListener();
    _removeHotkeyListener();
    super.dispose();
  }

  void _removePttListener() {
    try {
      final mumbleService = Provider.of<MumbleService>(context, listen: false);
      mumbleService.removeListener(_handlePttWarning);
    } catch (_) {}
  }

  void _removeHotkeyListener() {
    try {
      final hotkeyService = Provider.of<HotkeyService>(context, listen: false);
      hotkeyService.removeListener(_handleHotkeyError);
    } catch (_) {}
  }

  void _handlePttWarning() {
    if (!mounted) return;
    final mumbleService = Provider.of<MumbleService>(context, listen: false);
    if (mumbleService.pttErrorMessage != null) {
      final message = mumbleService.pttErrorMessage!;
      mumbleService.clearPttErrorMessage();

      ShadSonner.of(context).show(
        ShadToast.destructive(
          title: const Text('Cannot Talk'),
          description: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleHotkeyError() {
    if (!mounted) return;
    final hotkeyService = Provider.of<HotkeyService>(context, listen: false);
    if (hotkeyService.registrationError != null) {
      final message = hotkeyService.registrationError!;
      hotkeyService.clearRegistrationError();

      ShadSonner.of(context).show(
        ShadToast.destructive(
          title: const Text('Hotkey Error'),
          description: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _checkLastServer() async {
    // Wait a moment to ensure the push transition from LoadingPage is completed
    // to avoid navigator locking issues (especially on mobile).
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final settings = Provider.of<SettingsService>(context, listen: false);
    if (settings.reconnectToLastServer && settings.lastServerJson != null) {
      final serverMap = jsonDecode(settings.lastServerJson!);
      final lastServer = MumbleServer.fromJson(serverMap);
      final mumbleService = Provider.of<MumbleService>(context, listen: false);

      _connectToServer(mumbleService, lastServer);
    }
  }

  void _showAddServerDialog(
    BuildContext context, {
    MumbleServer? server,
    String? errorField,
  }) {
    showShadDialog(
      context: context,
      builder: (context) =>
          AddServerDialog(server: server, errorField: errorField),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final mumbleService = Provider.of<MumbleService>(context, listen: false);

    showShadDialog(
      context: context,
      builder: (context) => SettingsDialog(
        settings: settings,
        mumbleService: mumbleService,
        onShowHotkeyRecorder: _showHotkeyRecorder,
      ),
    );
  }

  void _showHotkeyRecorder(
    BuildContext context,
    SettingsService settings, {
    HotkeyAction? action,
  }) {
    showShadDialog(
      context: context,
      builder: (context) => HotkeyRecorder(
        settings: settings,
        action: action ?? HotkeyAction.pushToTalk,
      ),
    );
  }

  void _showChatSheet(BuildContext context, MumbleService mumbleService) {
    showShadSheet(
      side: ShadSheetSide.right,
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      animateIn: [
        SlideEffect(
          begin: const Offset(1, 0),
          end: Offset.zero,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        ),
      ],
      animateOut: [
        SlideEffect(
          begin: Offset.zero,
          end: const Offset(1, 0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInCubic,
        ),
      ],
      builder: (context) {
        final theme = ShadTheme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ShadSheet(
                  backgroundColor: theme.colorScheme.background.withValues(
                    alpha: 0.6,
                  ),
                  padding: EdgeInsets.zero,
                  scrollable: false,
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * (LayoutConstants.isSlim(context) ? 1.0 : 0.9),
                  ),
                  radius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  closeIconPosition: const ShadPosition(top: 12, right: 12),
                  title: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16),
                    child: const Text('Chat'),
                  ),
                  description: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: const Text('Text messages and conversation'),
                  ),
                  child: const ChatView(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _connectToServer(
    MumbleService service,
    MumbleServer server,
  ) async {
    debugPrint(
      '[DEBUG] _connectToServer to: ${server.name} @ ${server.host}:${server.port}',
    );
    // Using addPostFrameCallback here ensures the state change doesn't interfere
    // with any ongoing build processes.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _connectingServerId = server.id);
      });
    }
    try {
      // Request microphone permission on mobile platforms
      debugPrint(
        '[DEBUG] Platform check: isAndroid=${Platform.isAndroid}, isIOS=${Platform.isIOS}',
      );
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('[DEBUG] Requesting microphone permission...');
        final hasPermission =
            await PermissionUtils.requestMicrophonePermission();
        debugPrint('[DEBUG] Microphone permission result: $hasPermission');
        if (!hasPermission) {
          if (mounted) {
            ShadToaster.of(context).show(
              const ShadToast.destructive(
                title: Text('Permission Denied'),
                description: Text(
                  'Microphone access is required to connect to a server.',
                ),
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;
      final certService = Provider.of<CertificateService>(
        context,
        listen: false,
      );
      debugPrint('[DEBUG] Accessed CertificateService');

      // We must wait for certificates to load from disk if they haven't finished yet,
      // otherwise autoconnect won't find the correct certificate during startup.
      if (!certService.isInitialized) {
        debugPrint('[DEBUG] Waiting for certificates to load...');
        await certService.loadCertificates();
      }

      // Prioritize server-specific certificate, then global default
      final certId = server.certificateId ?? certService.defaultCertificateId;
      final certificate = certId != null
          ? certService.getCertificateById(certId)
          : null;
      debugPrint('[DEBUG] Certificate resolved ($certId): $certificate');

      // Set update callback for persisting last joined channel
      service.onServerUpdated = (updatedServer) {
        if (mounted) {
          Provider.of<ServerProvider>(
            context,
            listen: false,
          ).updateServer(updatedServer);
        }
      };

      await service.connect(server, certificate: certificate);
      debugPrint('[DEBUG] Connecting service done');

      if (mounted) {
        final settings = Provider.of<SettingsService>(context, listen: false);
        settings.setLastServerJson(jsonEncode(server.toJson()));
      }
    } catch (e) {
      _handleConnectionError(e, server);
    } finally {
      if (mounted) setState(() => _connectingServerId = null);
    }
  }

  void _handleConnectionError(Object e, MumbleServer server) {
    developer.log(
      'Connection Error to ${server.name}',
      error: e,
      name: 'HomeScreen',
      level: 1000,
    );

    String message = 'Failed to connect to server.';
    bool showEdit = false;
    String? errorField;

    final errorStr = e.toString().toLowerCase();

    if (e is SocketException) {
      message = e.message;
      if (e.osError?.message != null && e.osError!.message.isNotEmpty) {
        message += ' (${e.osError!.message})';
      }
    } else if (e.toString().contains(':')) {
      // Fallback for other errors with a message after ":"
      final parts = e.toString().split(':');
      if (parts.length > 1) {
        message = parts.last.trim();
      } else {
        message = e.toString();
      }
    } else {
      message = e.toString();
    }

    if (errorStr.contains('password')) {
      showEdit = true;
      errorField = 'password';
    } else if (errorStr.contains('hostname') ||
        errorStr.contains('host not found') ||
        errorStr.contains('failed to resolve')) {
      showEdit = true;
      errorField = 'host';
    } else if (errorStr.contains('username')) {
      showEdit = true;
      errorField = 'username';
    }

    if (mounted) {
      ShadSonner.of(context).show(
        ShadToast.destructive(
          title: const Text('Connection Error'),
          description: Text(message),
        ),
      );
      if (showEdit) {
        _showAddServerDialog(context, server: server, errorField: errorField);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);
    final connectivityService = Provider.of<ConnectivityService>(context);
    final theme = ShadTheme.of(context);
    final isSlim = LayoutConstants.isSlim(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: Column(
          children: [
            if (!connectivityService.isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                color: Colors.blue.withValues(alpha: 0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'No internet connection. Waiting to reconnect...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeader(mumbleService, isSlim),
            const PermissionBanner(),
            Expanded(
              child: ListenableBuilder(
                listenable: mumbleService,
                builder: (context, _) {
                  if (mumbleService.isConnected) {
                    if (isSlim) {
                      return ChannelTree(
                        channels: mumbleService.channels,
                        users: mumbleService.users,
                        talkingUsers: mumbleService.talkingUsers,
                        self: mumbleService.self,
                        hasMicPermission: mumbleService.hasMicPermission,
                        onChannelTap: (c) => mumbleService.joinChannel(c.id),
                      );
                    }
                    return ShadResizablePanelGroup(
                      showHandle: true,
                      children: [
                        ShadResizablePanel(
                          id: 0,
                          defaultSize: .3,
                          minSize: .2,
                          child: ChannelTree(
                            channels: mumbleService.channels,
                            users: mumbleService.users,
                            talkingUsers: mumbleService.talkingUsers,
                            self: mumbleService.self,
                            hasMicPermission: mumbleService.hasMicPermission,
                            onChannelTap: (c) =>
                                mumbleService.joinChannel(c.id),
                          ),
                        ),
                        ShadResizablePanel(
                          id: 1,
                          defaultSize: .7,
                          minSize: .3,
                          child: ColoredBox(
                            color: theme.colorScheme.background,
                            child: const ChatView(),
                          ),
                        ),
                      ],
                    );
                  }
                  return _buildServerList(isSlim);
                },
              ),
            ),
            if (mumbleService.isConnected)
              _buildBottomBar(mumbleService, isSlim),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MumbleService mumbleService, bool isSlim) {
    final theme = ShadTheme.of(context);
    final showChatToggle = mumbleService.isConnected && isSlim;

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 8, top: 16, bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Image.asset('assets/icon.png', height: 32, width: 32),
          if (!isSlim) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rumble',
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Mumble Reloaded',
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 10,
                    height: 1.0,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          _buildVolumeControl(mumbleService),
          if (showChatToggle)
            Stack(
              clipBehavior: Clip.none,
              children: [
                RumbleTooltip(
                  message: 'Show Chat',
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.messageSquare, size: 20),
                    onPressed: () => _showChatSheet(context, mumbleService),
                  ),
                ),
                if (mumbleService.unreadMessagesCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.background,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          mumbleService.unreadMessagesCount > 9
                              ? ''
                              : mumbleService.unreadMessagesCount.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.primaryForeground,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (mumbleService.isConnected)
            RumbleTooltip(
              message: 'Disconnect from server',
              child: ShadIconButton.ghost(
                icon: Icon(
                  LucideIcons.logOut,
                  color: theme.colorScheme.destructive,
                  size: 20,
                ),
                onPressed: () => mumbleService.disconnect(),
              ),
            ),
          RumbleTooltip(
            message: 'Settings',
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.settings, size: 20),
              onPressed: () => _showSettingsDialog(context),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildServerList(bool isSlim) {
    final theme = ShadTheme.of(context);

    return Consumer<ServerProvider>(
      builder: (context, provider, _) {
        final activeServers = provider.servers
            .where((s) => !s.isArchived)
            .toList();
        final archivedServers = provider.servers
            .where((s) => s.isArchived)
            .toList();

        if (provider.servers.isEmpty) {
          return _buildEmptyState();
        }

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isSlim ? 12 : 32,
            vertical: isSlim ? 12 : 40,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servers',
                      style: theme.textTheme.h2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${activeServers.length} servers available',
                      style: theme.textTheme.muted,
                    ),
                  ],
                ),
                Row(
                  children: [
                    RumbleTooltip(
                      message: 'Add a new Mumble server',
                      child: ShadButton(
                        leading: const Icon(LucideIcons.plus, size: 16),
                        onPressed: () => _showAddServerDialog(context),
                        child: const Text('Add Server'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            ...activeServers.map(
              (server) => ServerCard(
                server: server,
                provider: provider,
                isConnecting: _connectingServerId == server.id,
                onConnect: (s) => _connectToServer(
                  Provider.of<MumbleService>(context, listen: false),
                  s,
                ),
                onEdit: (s) => _showAddServerDialog(context, server: s),
              ),
            ),
            if (archivedServers.isNotEmpty) ...[
              const SizedBox(height: 48),
              Text(
                'Archived',
                style: theme.textTheme.h4.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              ...archivedServers.map(
                (server) => Opacity(
                  opacity: 0.6,
                  child: ServerCard(
                    server: server,
                    provider: provider,
                    isConnecting: _connectingServerId == server.id,
                    onConnect: (s) => _connectToServer(
                      Provider.of<MumbleService>(context, listen: false),
                      s,
                    ),
                    onEdit: (s) => _showAddServerDialog(context, server: s),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = ShadTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.radio,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text('Welcome to Rumble', style: theme.textTheme.h2),
          const SizedBox(height: 8),
          Text(
            'Connect to a server to start chatting.',
            style: theme.textTheme.muted.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 40),
          RumbleTooltip(
            message: 'Add your first Mumble server to the list',
            child: ShadButton(
              size: ShadButtonSize.lg,
              leading: const Icon(LucideIcons.plus, size: 20),
              onPressed: () => _showAddServerDialog(context),
              child: const Text('Add First Server'),
            ),
          ),
          const SizedBox(height: 16),
          RumbleTooltip(
            message: 'Open application settings',
            child: ShadButton.ghost(
              onPressed: () => _showSettingsDialog(context),
              child: const Text('Application Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(MumbleService service, bool isSlim) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSlim ? 12 : 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildAecToggle(service),
          Row(
            children: [
              _buildMicStatus(service),
              SizedBox(width: isSlim ? 8 : 16),
              _buildPTTButton(service, isSlim),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAecToggle(MumbleService service) {
    final theme = ShadTheme.of(context);
    final isEnabled = service.echoCancellationEnabled;

    return RumbleTooltip(
      message: isEnabled ? 'Echo Cancellation: ON' : 'Echo Cancellation: OFF',
      child: GestureDetector(
        onTap: () => service.setEchoCancellation(!isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? kBrandGreen.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled
                  ? kBrandGreen.withValues(alpha: 0.5)
                  : theme.colorScheme.border.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.audioWaveform,
                size: 16,
                color: isEnabled
                    ? kBrandGreen
                    : theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                'AEC',
                style: theme.textTheme.small.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? kBrandGreen
                      : theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPTTButton(MumbleService service, bool isSlim) {
    return PushToTalkButton(
      service: service,
      compact: isSlim,
      width: isSlim ? 110 : 180,
    );
  }

  Widget _buildMicStatus(MumbleService service) {
    final theme = ShadTheme.of(context);
    final settings = Provider.of<SettingsService>(context);
    final isMuted = service.isMuted;
    final isDeafened = service.isDeafened;

    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (settings.showVolumeIndicator)
              VolumeIndicator(
                volumeNotifier: service.volumeNotifier,
                isMuted: isMuted,
                isDeafened: isDeafened,
                foregroundColor: kBrandGreen,
                mutedColor: theme.colorScheme.mutedForeground,
              ),
            RumbleTooltip(
              message: isMuted ? 'Unmute' : 'Mute',
              child: ShadIconButton.ghost(
                icon: Icon(
                  isMuted ? LucideIcons.micOff : LucideIcons.mic,
                  color: isMuted
                      ? theme.colorScheme.destructive
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                onPressed: () => service.toggleMute(),
              ),
            ),
          ],
        ),
        RumbleTooltip(
          message: isDeafened ? 'Undeafen' : 'Deafen',
          child: ShadIconButton.ghost(
            icon: Icon(
              isDeafened ? LucideIcons.headphoneOff : LucideIcons.headphones,
              color: isDeafened
                  ? theme.colorScheme.destructive
                  : theme.colorScheme.primary,
            ),
            onPressed: () => service.toggleDeafen(),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeControl(MumbleService service) {
    final theme = ShadTheme.of(context);
    final settings = Provider.of<SettingsService>(context);

    return ShadPopover(
      controller: _volumePopoverController,
      popover: (context) => SizedBox(
        width: 250,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Master Volume', style: theme.textTheme.small),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ShadSlider(
                        initialValue: settings.outputVolume,
                        min: 0.0,
                        max: 2.0,
                        thumbRadius: 10,
                        onChanged: (v) {
                          settings.setOutputVolume(v);
                          service.updateAudioSettings(outputVolume: v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(settings.outputVolume * 100).round()}%',
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      child: RumbleTooltip(
        message: 'Volume Settings',
        child: ShadIconButton.ghost(
          onPressed: () => _volumePopoverController.toggle(),
          icon: Icon(
            settings.outputVolume == 0
                ? LucideIcons.volumeX
                : settings.outputVolume < 0.5
                ? LucideIcons.volume1
                : LucideIcons.volume2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// A high-performance volume indicator that paints directly to the canvas.
/// Uses [RepaintBoundary] to isolate repaints and [CustomPainter] with a
/// [repaint] listener to skip the build and layout phases of the Flutter pipeline.
class VolumeIndicator extends StatelessWidget {
  final ValueListenable<double> volumeNotifier;
  final bool isMuted;
  final bool isDeafened;
  final Color foregroundColor;
  final Color mutedColor;

  const VolumeIndicator({
    super.key,
    required this.volumeNotifier,
    required this.isMuted,
    required this.isDeafened,
    required this.foregroundColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(48, 48),
        painter: _VolumeIndicatorPainter(
          volumeNotifier: volumeNotifier,
          isMuted: isMuted,
          isDeafened: isDeafened,
          foregroundColor: foregroundColor,
          mutedColor: mutedColor,
        ),
      ),
    );
  }
}

class _VolumeIndicatorPainter extends CustomPainter {
  final ValueListenable<double> volumeNotifier;
  final bool isMuted;
  final bool isDeafened;
  final Color foregroundColor;
  final Color mutedColor;

  _VolumeIndicatorPainter({
    required this.volumeNotifier,
    required this.isMuted,
    required this.isDeafened,
    required this.foregroundColor,
    required this.mutedColor,
  }) : super(repaint: volumeNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 1. Draw background circle (outside ring)
    final bgPaint = Paint()
      ..color = foregroundColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18.0, bgPaint);

    final volume = volumeNotifier.value;
    const double volumeMultiplier = 35.0; // Responsive scale
    final displayVolume = (volume * volumeMultiplier).clamp(0.0, 1.0);

    // 2. Calculate inner circle size (radius)
    // Larger baseline: 15px (30px diameter)
    // Dynamic expansion up to 24px (48px diameter)
    final innerRadius = 15.0 + (9.0 * displayVolume);

    // 3. Draw indicator circle
    final innerPaint = Paint()..style = PaintingStyle.fill;

    if (isMuted || isDeafened) {
      innerPaint.color = mutedColor.withValues(alpha: 0.1);
    } else {
      // Lowered alpha for the larger surface area
      innerPaint.color = foregroundColor.withValues(
        alpha: (0.15 + (displayVolume * 0.35)).clamp(0.0, 1.0),
      );
    }

    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _VolumeIndicatorPainter oldDelegate) {
    return oldDelegate.isMuted != isMuted ||
        oldDelegate.isDeafened != isDeafened ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}
