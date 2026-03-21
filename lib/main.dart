import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/models/server.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/certificate_service.dart';
import 'package:rumble/services/hotkey_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rumble/components/server_card.dart';
import 'package:rumble/components/add_server_dialog.dart';
import 'package:rumble/components/settings/settings_dialog.dart';
import 'package:rumble/components/permission_banner.dart';
import 'package:rumble/components/hotkey_recorder.dart';
import 'package:rumble/components/chat_view.dart';

// Brand Colors
const kBrandGreen = Color(0xFF64FFDA);
const kBrandGreenText = Color(0xFF065F46);
const kBrandGreenButton = Color.fromARGB(255, 79, 196, 157);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();

    double? width = settingsService.windowWidth;
    double? height = settingsService.windowHeight;
    double? x = settingsService.windowX;
    double? y = settingsService.windowY;

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
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MumbleService()
            ..initialize(
              settingsService.inputGain,
              settingsService.outputVolume,
              settingsService.inputDeviceId,
              settingsService.outputDeviceId,
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) => ShadApp(
        title: 'Rumble',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
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
        home: const _WindowResizeListener(child: HomeScreen()),
      ),
    );
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
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  @override
  void onWindowResize() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final size = await windowManager.getSize();
    settings.setWindowSize(size);
  }

  @override
  void onWindowMove() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final pos = await windowManager.getPosition();
    settings.setWindowPosition(pos);
  }

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

  @override
  void initState() {
    super.initState();
    _checkLastServer();

    // Listen for PTT errors/warnings globally in the Home Screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mumbleService = Provider.of<MumbleService>(context, listen: false);
      mumbleService.addListener(_handlePttWarning);
    });
  }

  @override
  void dispose() {
    // We can't use Provider.of in dispose, so we'd need a reference
    // but MumbleService is a global provider so we can find it.
    // However, since it's a singleton-like in this app context, and the app is closed, it's usually fine.
    // But for good practice:
    _removePttListener();
    super.dispose();
  }

  void _removePttListener() {
    try {
      final mumbleService = Provider.of<MumbleService>(context, listen: false);
      mumbleService.removeListener(_handlePttWarning);
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
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkLastServer() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    if (settings.reconnectToLastServer && settings.lastServerJson != null) {
      final serverMap = jsonDecode(settings.lastServerJson!);
      final lastServer = MumbleServer.fromJson(serverMap);
      final mumbleService = Provider.of<MumbleService>(context, listen: false);

      Timer(const Duration(milliseconds: 500), () {
        if (mounted) _connectToServer(mumbleService, lastServer);
      });
    }
  }

  void _showAddServerDialog(BuildContext context, {MumbleServer? server}) {
    showShadDialog(
      context: context,
      builder: (context) => AddServerDialog(server: server),
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

  void _showHotkeyRecorder(BuildContext context, SettingsService settings) {
    showShadDialog(
      context: context,
      builder: (context) => HotkeyRecorder(settings: settings),
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
        return ShadSheet(
          backgroundColor: theme.colorScheme.background.withValues(alpha: 0.6),
          padding: EdgeInsets.zero,
          scrollable: false,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 16, top: 16),
            child: const Text('Chat'),
          ),
          description: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: const Text('Text messages and conversation'),
          ),
          child: ClipRRect(
            borderRadius: theme.radius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: const ChatView(),
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
    if (mounted) setState(() => _connectingServerId = server.id);
    try {
      final certService = Provider.of<CertificateService>(
        context,
        listen: false,
      );
      final defaultCertId = certService.defaultCertificateId;
      final certificate = defaultCertId != null
          ? certService.getCertificateById(defaultCertId)
          : null;

      await service.connect(server, certificate: certificate);

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
    final errorStr = e.toString().toLowerCase();
    String message = 'Failed to connect to server.';
    bool showEdit = false;

    if (e.toString().contains(':')) {
      message = e.toString().split(':').last.trim();
    }

    if (errorStr.contains('password')) {
      message = message.isEmpty ? 'Incorrect password.' : message;
      showEdit = true;
    } else if (errorStr.contains('hostname') ||
        errorStr.contains('host not found')) {
      message = 'Invalid server address.';
      showEdit = true;
    }

    if (mounted) {
      ShadSonner.of(context).show(
        ShadToast.destructive(
          title: const Text('Connection Error'),
          description: Text(message),
        ),
      );
      if (showEdit) _showAddServerDialog(context, server: server);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(mumbleService),
            const PermissionBanner(),
            Expanded(
              child: ListenableBuilder(
                listenable: mumbleService,
                builder: (context, _) {
                  if (mumbleService.isConnected) {
                    final platformDesktop =
                        !kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.linux ||
                            defaultTargetPlatform == TargetPlatform.macOS);

                    final isSlim = MediaQuery.of(context).size.width < 900;

                    if (platformDesktop) {
                      if (isSlim) {
                        return ChannelTree(
                          channels: mumbleService.channels,
                          users: mumbleService.users,
                          talkingUsers: mumbleService.talkingUsers,
                          self: mumbleService.self,
                          hasMicPermission: mumbleService.hasMicPermission,
                          onChannelTap: (c) => mumbleService.joinChannel(c),
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
                              onChannelTap: (c) => mumbleService.joinChannel(c),
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
                    } else {
                      return ChannelTree(
                        channels: mumbleService.channels,
                        users: mumbleService.users,
                        talkingUsers: mumbleService.talkingUsers,
                        self: mumbleService.self,
                        hasMicPermission: mumbleService.hasMicPermission,
                        onChannelTap: (c) => mumbleService.joinChannel(c),
                      );
                    }
                  }
                  return _buildServerList();
                },
              ),
            ),
            if (mumbleService.isConnected) _buildBottomBar(mumbleService),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MumbleService mumbleService) {
    final theme = ShadTheme.of(context);
    final isSlimDesktop =
        mumbleService.isConnected &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        MediaQuery.of(context).size.width < 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isSlimDesktop)
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.messageSquare, size: 20),
              onPressed: () => _showChatSheet(context, mumbleService),
            ),
          if (mumbleService.isConnected)
            ShadIconButton.ghost(
              icon: Icon(
                LucideIcons.logOut,
                color: theme.colorScheme.destructive,
                size: 20,
              ),
              onPressed: () => mumbleService.disconnect(),
            ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.settings, size: 20),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    final theme = ShadTheme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

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
            horizontal: isMobile ? 12 : 32,
            vertical: isMobile ? 12 : 40,
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
                    ShadButton(
                      leading: const Icon(LucideIcons.plus, size: 16),
                      onPressed: () => _showAddServerDialog(context),
                      child: const Text('Add Server'),
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
          ShadButton(
            size: ShadButtonSize.lg,
            leading: const Icon(LucideIcons.plus, size: 20),
            onPressed: () => _showAddServerDialog(context),
            child: const Text('Add First Server'),
          ),
          const SizedBox(height: 16),
          ShadButton.ghost(
            onPressed: () => _showSettingsDialog(context),
            child: const Text('Application Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(MumbleService service) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildMicStatus(service),
          const SizedBox(width: 16),
          _buildPTTButton(service),
        ],
      ),
    );
  }

  Widget _buildMicStatus(MumbleService service) {
    final theme = ShadTheme.of(context);
    final isMuted = service.isMuted;
    final isDeafened = service.isDeafened;
    final volume = service.currentVolume;

    return Row(
      children: [
        // Mic signal indicator (circle that grows with volume)
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kBrandGreen.withValues(alpha: 0.1),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: 2 + (8 * volume).clamp(0, 8),
              height: 2 + (8 * volume).clamp(0, 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isMuted || isDeafened)
                    ? theme.colorScheme.mutedForeground.withValues(alpha: 0.3)
                    : kBrandGreen.withValues(
                        alpha: (0.4 + (volume * 0.6)).clamp(0, 1.0),
                      ),
                boxShadow: [
                  if (!isMuted && !isDeafened && volume > 0.1)
                    BoxShadow(
                      color: kBrandGreen.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                ],
              ),
            ),
          ),
        ),
        ShadIconButton.ghost(
          icon: Icon(
            isMuted ? LucideIcons.micOff : LucideIcons.mic,
            color: isMuted
                ? theme.colorScheme.destructive
                : theme.colorScheme.primary,
          ),
          onPressed: () => service.toggleMute(),
        ),
        ShadIconButton.ghost(
          icon: Icon(
            isDeafened ? LucideIcons.headphoneOff : LucideIcons.headphones,
            color: isDeafened
                ? theme.colorScheme.destructive
                : theme.colorScheme.primary,
          ),
          onPressed: () => service.toggleDeafen(),
        ),
      ],
    );
  }

  Widget _buildPTTButton(MumbleService service) {
    final bool isTalking = service.isTalking;
    final bool isSuppressed = service.isSuppressed;
    final bool isMuted = service.isMuted;
    final settings = Provider.of<SettingsService>(context);

    String label = 'HOLD TO TALK';
    if (isSuppressed)
      label = 'SUPPRESSED';
    else if (isMuted)
      label = 'MUTED';
    else if (isTalking)
      label = 'TALKING...';
    else if (settings.pttKey != PttKey.none) {
      label = 'HOLD ${settings.pttKey.name.toUpperCase()}';
    }

    final theme = ShadTheme.of(context);

    return Listener(
      onPointerDown: (_) => service.startPushToTalk(),
      onPointerUp: (_) => service.stopPushToTalk(),
      onPointerCancel: (_) => service.stopPushToTalk(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 180, // Fixed width to prevent resizing
        height: 48, // Fixed height to prevent resizing
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: (isSuppressed || isMuted)
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.destructive.withValues(alpha: 0.1),
                    theme.colorScheme.destructive.withValues(alpha: 0.2),
                  ],
                )
              : isTalking
              ? const LinearGradient(
                  colors: [Colors.blueAccent, Color(0xFF448AFF)],
                )
              : LinearGradient(
                  colors: [kBrandGreen, kBrandGreen.withValues(alpha: 0.8)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isSuppressed || isMuted)
                  ? Colors.transparent
                  : isTalking
                  ? Colors.blueAccent.withValues(alpha: 0.4)
                  : kBrandGreen.withValues(alpha: 0.2),
              blurRadius: isTalking ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isTalking
                ? Colors.white
                : ((isSuppressed || isMuted)
                      ? theme.colorScheme.destructive
                      : Colors.black),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
