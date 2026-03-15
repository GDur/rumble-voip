import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/models/server.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/hotkey_service.dart';

// Brand Colors
const kBrandGreen = Color(
  0xFF64FFDA,
); // Bright brand green (for buttons, icons, dark mode)
const kBrandGreenText = Color(
  0xFF065F46,
); // Deep emerald for readable text on light backgrounds
const kBrandGreenButton = Color.fromARGB(
  255,
  79,
  196,
  157,
); // Solid green for buttons on light backgrounds

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MumbleService()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
        ChangeNotifierProvider.value(value: settingsService),
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
            primary: kBrandGreenText, // Darker for text/accents on light bg
            primaryForeground: Colors.white,
          ),
          primaryButtonTheme: const ShadButtonTheme(
            backgroundColor: kBrandGreenButton, // More solid green for buttons
            foregroundColor: Colors.white,
          ),
          textTheme: ShadTextTheme(p: const TextStyle(fontFamily: 'Outfit')),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(
            primary: kBrandGreen, // Bright for pop on dark bg
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
            duration: const Duration(seconds: 6),
          ),
          textTheme: ShadTextTheme(p: const TextStyle(fontFamily: 'Outfit')),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _hostController = TextEditingController();
  final _nameController = TextEditingController();
  final _portController = TextEditingController(text: '64738');
  final _usernameController = TextEditingController(
    text: 'Rumble - Mumble Reloaded',
  );
  final _passwordController = TextEditingController();
  bool _isAutoName = true;
  String? _connectingServerId;
  bool _archiveExpanded = false;
  bool _showSuccessBanner = false;
  Timer? _successBannerTimer;

  @override
  void initState() {
    super.initState();

    // Listen for permission changes to show success banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hotkeyService = Provider.of<HotkeyService>(context, listen: false);
      bool lastStatus = hotkeyService.hasAccessibilityPermission.value;

      hotkeyService.hasAccessibilityPermission.addListener(() {
        final newStatus = hotkeyService.hasAccessibilityPermission.value;
        if (newStatus && !lastStatus) {
          // Permission was just granted!
          if (mounted) {
            setState(() => _showSuccessBanner = true);
            _successBannerTimer?.cancel();
            _successBannerTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() => _showSuccessBanner = false);
              }
            });
          }
        }
        lastStatus = newStatus;
      });
    });
  }

  @override
  void dispose() {
    _successBannerTimer?.cancel();
    _hostController.dispose();
    _nameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    showShadDialog(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
              title: const Text('Settings'),
              actions: [
                ShadButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              child: Container(
                width: 440,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ShadTabs<String>(
                  tabBarConstraints: const BoxConstraints(maxWidth: 440),
                  contentConstraints: const BoxConstraints(maxWidth: 440),
                  value: 'general',
                  tabs: [
                    ShadTab(
                      value: 'general',
                      content: _buildGeneralSettings(
                        context,
                        settings,
                        setDialogState,
                      ),
                      child: const Text('General'),
                    ),
                    ShadTab(
                      value: 'about',
                      content: _buildAboutPage(context),
                      child: const Text('About'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGeneralSettings(
    BuildContext context,
    SettingsService settings,
    StateSetter setDialogState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: ShadSelect<ThemeMode>(
              placeholder: const Text('Select Theme'),
              initialValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settings.setThemeMode(value);
                  setDialogState(() {});
                }
              },
              options: [
                ShadOption(
                  value: ThemeMode.system,
                  child: const Text('System'),
                ),
                ShadOption(value: ThemeMode.light, child: const Text('Light')),
                ShadOption(value: ThemeMode.dark, child: const Text('Dark')),
              ],
              selectedOptionBuilder: (context, value) =>
                  Text(value.name.toUpperCase()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'PTT Hotkey',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              children: [
                Expanded(
                  child: ShadSelect<PttKey>(
                    placeholder: const Text('Select a key'),
                    initialValue: settings.pttKey,
                    onChanged: (value) {
                      if (value != null) {
                        settings.setPttKey(value);
                        setDialogState(() {});
                      }
                    },
                    options: [
                      ...PttKey.values.map((k) {
                        String label = k.name.toUpperCase();
                        if (k == PttKey.none) label = 'DISABLED';
                        return ShadOption(value: k, child: Text(label));
                      }),
                    ],
                    selectedOptionBuilder: (context, value) {
                      if (value == PttKey.none &&
                          settings.customHotkey != null) {
                        return Text(
                          'CUSTOM: ${settings.customHotkey!['label'] ?? 'Unknown'}',
                        );
                      }
                      return Text(value.name.toUpperCase());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: () => _showHotkeyRecorder(context, settings),
                  child: const Text('Record...'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (settings.pttKey != PttKey.none ||
              settings.customHotkey != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Suppress original key function',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          ShadTooltip(
                            builder: (context) => const Text(
                              'If enabled, the key will not perform its original duty (e.g. CapsLock LED won\'t toggle).',
                            ),
                            child: Icon(
                              LucideIcons.info,
                              size: 14,
                              color: ShadTheme.of(
                                context,
                              ).colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ShadSwitch(
                  value: settings.pttSuppress,
                  onChanged: (val) {
                    settings.setPttSuppress(val);
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ],
          if (defaultTargetPlatform == TargetPlatform.macOS) ...[
            const SizedBox(height: 24),
            const Text(
              'macOS Permissions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: Provider.of<HotkeyService>(
                context,
                listen: false,
              ).hasAccessibilityPermission,
              builder: (context, hasPermission, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasPermission ? LucideIcons.check : LucideIcons.info,
                          size: 14,
                          color: hasPermission ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasPermission
                              ? 'Permission Granted'
                              : 'Permission Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasPermission ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To use Push-to-Talk while Rumble is in the background, you must allow "Accessibility" in System Settings.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ShadButton.outline(
                          onPressed: () {
                            Provider.of<HotkeyService>(
                              context,
                              listen: false,
                            ).openAccessibilitySettings();
                          },
                          child: Text(
                            hasPermission
                                ? 'Manage in System Settings'
                                : 'Grant Permission',
                          ),
                        ),
                        const SizedBox(width: 12),
                        ShadButton.ghost(
                          onPressed: () {
                            Provider.of<HotkeyService>(
                              context,
                              listen: false,
                            ).checkPermission();
                          },
                          child: const Row(
                            children: [
                              Icon(LucideIcons.refreshCw, size: 14),
                              const SizedBox(width: 8),
                              const Text('Check Status'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutPage(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            // padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon.png',
                width: 80 + 16 + 16,
                height: 80 + 16 + 16,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rumble',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Mumble Reloaded',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'A modern, high-performance Mumble client built with Flutter. Designed for seamless voice chat across all your devices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          _buildAboutInfo(context, 'Version', '1.0.0+1'),
          _buildAboutInfo(context, 'Created', 'March 2026'),
          _buildAboutInfo(context, 'License', 'No Warranty (AS IS)'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Crafted with ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Icon(LucideIcons.heart, size: 12, color: Colors.red),
              const Text(
                ' and ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Icon(LucideIcons.bot, size: 14, color: Colors.blue),
              const Text(
                ' assistance',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfo(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, {MumbleServer? server}) {
    if (server != null) {
      _hostController.text = server.host;
      _nameController.text = server.name;
      _portController.text = server.port.toString();
      _usernameController.text = server.username;
      _passwordController.text = server.password;
      _isAutoName = false;
    } else {
      _hostController.clear();
      _nameController.clear();
      _portController.text = '64738';
      _passwordController.clear();
    }

    final formKey = GlobalKey<ShadFormState>();
    bool passwordObscure = true;

    showShadDialog(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
              title: Text(server == null ? 'Add New Server' : 'Edit Server'),
              actions: [
                ShadButton.outline(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ShadButton(
                  child: const Text('Save Server'),
                  onPressed: () {
                    if (formKey.currentState!.saveAndValidate()) {
                      final username = _usernameController.text.trim();
                      final newServer = MumbleServer(
                        id: server?.id,
                        name: _nameController.text.isEmpty
                            ? _hostController.text
                            : _nameController.text,
                        host: _hostController.text,
                        port: int.tryParse(_portController.text) ?? 64738,
                        username: username,
                        password: _passwordController.text,
                      );
                      if (server == null) {
                        Provider.of<ServerProvider>(
                          context,
                          listen: false,
                        ).addServer(newServer);
                      } else {
                        Provider.of<ServerProvider>(
                          context,
                          listen: false,
                        ).updateServer(newServer);
                      }
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
              child: ShadForm(
                key: formKey,
                child: Container(
                  width: 440,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ShadInputFormField(
                          id: 'host',
                          label: Row(
                            children: [
                              const Text('Server Address (Host)'),
                              const SizedBox(width: 8),
                              ShadTooltip(
                                builder: (context) => const Text(
                                  'The hostname or IP of the Mumble server.',
                                ),
                                child: Icon(
                                  LucideIcons.info,
                                  size: 14,
                                  color: ShadTheme.of(
                                    context,
                                  ).colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          placeholder: const Text('mumble.example.com'),
                          controller: _hostController,
                          onChanged: (val) {
                            if (_isAutoName) {
                              setDialogState(() => _nameController.text = val);
                            }
                          },
                          validator: (v) {
                            if (v.isEmpty) return 'Host address is required';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ShadInputFormField(
                          id: 'name',
                          label: Row(
                            children: [
                              const Text('Display Name'),
                              const SizedBox(width: 8),
                              ShadTooltip(
                                builder: (context) => const Text(
                                  'How this server appears in your list.',
                                ),
                                child: Icon(
                                  LucideIcons.info,
                                  size: 14,
                                  color: ShadTheme.of(
                                    context,
                                  ).colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          placeholder: const Text('My Awesome Server'),
                          controller: _nameController,
                          onChanged: (val) =>
                              setDialogState(() => _isAutoName = false),
                          validator: (v) {
                            if (v.isEmpty) return 'Display name is required';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: ShadInputFormField(
                                id: 'port',
                                label: const Text('Port'),
                                placeholder: const Text('64738'),
                                controller: _portController,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (int.tryParse(v) == null) {
                                    return 'Invalid port';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: ShadInputFormField(
                                id: 'username',
                                label: Row(
                                  children: [
                                    const Text('Username'),
                                    const SizedBox(width: 8),
                                    ShadTooltip(
                                      builder: (context) => const Text(
                                        'Public display name on server.',
                                      ),
                                      child: Icon(
                                        LucideIcons.info,
                                        size: 14,
                                        color: ShadTheme.of(
                                          context,
                                        ).colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                                placeholder: const Text('Your Nickname'),
                                controller: _usernameController,
                                validator: (v) {
                                  if (v.length < 2) return 'Username too short';
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ShadInputFormField(
                          id: 'password',
                          label: const Text('Password (Optional)'),
                          placeholder: const Text('Secret Password'),
                          controller: _passwordController,
                          obscureText: passwordObscure,
                          leading: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(LucideIcons.lock, size: 16),
                          ),
                          trailing: ShadIconButton.ghost(
                            width: 24,
                            height: 24,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              passwordObscure
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                            ),
                            onPressed: () {
                              setDialogState(
                                () => passwordObscure = !passwordObscure,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);
    final serverProvider = Provider.of<ServerProvider>(context);

    final theme = ShadTheme.of(context);
    final bool isMobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      floatingActionButton: (!mumbleService.isConnected && isMobile)
          ? ShadButton(
              onPressed: () => _showAddServerDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 20),
                  SizedBox(width: 8),
                  Text('ADD SERVER'),
                ],
              ),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, mumbleService, isMobile),
              _buildPermissionBanner(context),
              Expanded(
                child: mumbleService.isConnected
                    ? ChannelTree(
                        channels: mumbleService.channels,
                        users:
                            mumbleService.client?.getUsers().values.toList() ??
                            [],
                        talkingUsers: mumbleService.talkingUsers,
                        self: mumbleService.client?.self,
                        hasMicPermission: mumbleService.hasMicPermission,
                        onChannelTap: (channel) {
                          mumbleService.client?.self.moveToChannel(
                            channel: channel,
                          );
                        },
                      )
                    : _buildServerList(context, serverProvider, mumbleService),
              ),
              if (mumbleService.isConnected) _buildBottomBar(mumbleService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS)
      return const SizedBox.shrink();

    final hotkeyService = Provider.of<HotkeyService>(context);
    final settings = Provider.of<SettingsService>(context);

    if (settings.pttKey == PttKey.none) return const SizedBox.shrink();

    // Show success banner if recently granted
    if (_showSuccessBanner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.green.withValues(alpha: 0.1),
        child: Row(
          children: [
            Icon(LucideIcons.check, color: Colors.green, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Access granted successfully! Try using ${settings.pttKey.name.toUpperCase()} now for PTT.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ShadIconButton.ghost(
              width: 32,
              height: 32,
              padding: EdgeInsets.zero,
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () => setState(() => _showSuccessBanner = false),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: hotkeyService.hasAccessibilityPermission,
      builder: (context, hasPermission, _) {
        if (hasPermission) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: ShadTheme.of(
            context,
          ).colorScheme.destructive.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(
                LucideIcons.info,
                color: ShadTheme.of(context).colorScheme.destructive,
                size: 20,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Global Hotkeys require Accessibility permissions on macOS to work in the background.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => hotkeyService.openAccessibilitySettings(),
                child: const Text('Open Settings'),
              ),
              const SizedBox(width: 8),
              ShadIconButton.ghost(
                width: 32,
                height: 32,
                padding: EdgeInsets.zero,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                onPressed: () => hotkeyService.checkPermission(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHotkeyRecorder(BuildContext context, SettingsService settings) {
    showShadDialog(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: ShadDialog(
          title: const Text('Record Hotkey'),
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;

              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.escape) {
                Navigator.pop(context);
                return KeyEventResult.handled;
              }

              // Capture mapping
              settings.setCustomHotkey({
                'label': key.keyLabel,
                'logicalKey': key.debugName,
                'physicalKey': event.physicalKey.debugName,
                // Very rough VK Mapping for Windows (example)
                'vkCode': _mapPhysicalToVk(event.physicalKey),
              });

              Navigator.pop(context);
              return KeyEventResult.handled;
            },
            child: Container(
              width: 300,
              height: 150,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Press any key or combined modifiers'),
                  SizedBox(height: 12),
                  Text(
                    'Press ESC to cancel',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _mapPhysicalToVk(PhysicalKeyboardKey key) {
    // Basic mapping for common keys to Windows VK codes
    if (key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.shiftRight)
      return 0x10;
    if (key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.controlRight)
      return 0x11;
    if (key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.altRight)
      return 0x12;
    if (key == PhysicalKeyboardKey.capsLock) return 0x14;
    if (key == PhysicalKeyboardKey.space) return 0x20;
    if (key == PhysicalKeyboardKey.f1) return 0x70;
    if (key == PhysicalKeyboardKey.f2) return 0x71;
    // ... add more as needed or use a more comprehensive map
    return 0;
  }

  Widget _buildHeader(
    BuildContext context,
    MumbleService service,
    bool isMobile,
  ) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.card.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rumble',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.foreground,
                      letterSpacing: -0.5,
                      fontFamily: 'Outfit',
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'MUMBLE RELOADED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (service.isConnected)
            Builder(
              builder: (context) {
                final bool hideText = MediaQuery.of(context).size.width < 500;
                return Row(
                  children: [
                    ShadTooltip(
                      builder: (context) =>
                          const Text('You are connected to the Mumble server.'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: hideText ? 10 : 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kBrandGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kBrandGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 4,
                              backgroundColor: kBrandGreen,
                            ),
                            if (!hideText) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'CONNECTED',
                                style: TextStyle(
                                  color: kBrandGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadIconButton.ghost(
                      onPressed: () => service.disconnect(),
                      icon: Icon(
                        LucideIcons.logOut,
                        color: theme.colorScheme.foreground.withValues(
                          alpha: 0.5,
                        ),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ShadIconButton.ghost(
                      onPressed: () => _showSettingsDialog(context),
                      icon: Icon(
                        LucideIcons.settings,
                        color: theme.colorScheme.foreground.withValues(
                          alpha: 0.5,
                        ),
                        size: 20,
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Row(
              children: [
                ShadIconButton.ghost(
                  onPressed: () => _showSettingsDialog(context),
                  icon: Icon(
                    LucideIcons.settings,
                    color: theme.colorScheme.foreground.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isMobile)
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => _showAddServerDialog(context),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.plus, size: 16),
                        SizedBox(width: 8),
                        Text('ADD SERVER'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildServerList(
    BuildContext context,
    ServerProvider provider,
    MumbleService service,
  ) {
    final theme = ShadTheme.of(context);
    final activeServers = provider.servers.where((s) => !s.isArchived).toList();
    final archivedServers = provider.servers
        .where((s) => s.isArchived)
        .toList();
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF64FFDA)),
      );
    }

    if (provider.servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.server, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No servers yet',
              style: TextStyle(
                color: theme.colorScheme.foreground.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: () => _showAddServerDialog(context),
              child: const Text('ADD YOUR FIRST SERVER'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final padding = EdgeInsets.all(isMobile ? 16 : 24);

        return ListView(
          padding: padding,
          children: [
            ...activeServers.map(
              (server) => _buildServerCard(
                context,
                provider,
                service,
                server,
                isMobile,
              ),
            ),
            if (archivedServers.isNotEmpty) ...[
              const SizedBox(height: 32),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      setState(() => _archiveExpanded = !_archiveExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _archiveExpanded
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRight,
                          size: 16,
                          color: theme.colorScheme.foreground.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ARCHIVE (${archivedServers.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.foreground.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_archiveExpanded)
                ...archivedServers.map(
                  (server) => Opacity(
                    opacity: 0.6,
                    child: _buildServerCard(
                      context,
                      provider,
                      service,
                      server,
                      isMobile,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildServerCard(
    BuildContext context,
    ServerProvider provider,
    MumbleService service,
    MumbleServer server,
    bool isMobile,
  ) {
    final theme = ShadTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: isMobile
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -8,
                    right: -8,
                    child: _buildServerActions(context, provider, server),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              LucideIcons.server,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 24,
                              ), // Space for the '...' menu
                              child: Text(
                                server.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${server.host}:${server.port}',
                        style: TextStyle(
                          color: theme.colorScheme.foreground.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'User: ${server.username}',
                        style: TextStyle(
                          color: theme.colorScheme.foreground.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ShadButton(
                              onPressed: _connectingServerId == null
                                  ? () => _connectToServer(service, server)
                                  : null,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: _connectingServerId == server.id
                                        ? 0
                                        : 1,
                                    child: const Text('CONNECT'),
                                  ),
                                  if (_connectingServerId == server.id)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            theme.colorScheme.primaryForeground,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            : ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.server,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  server.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${server.host}:${server.port} • ${server.username}',
                    style: TextStyle(
                      color: theme.colorScheme.foreground.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: _connectingServerId == null
                          ? () => _connectToServer(service, server)
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _connectingServerId == server.id ? 0 : 1,
                            child: const Text('CONNECT'),
                          ),
                          if (_connectingServerId == server.id)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primaryForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildServerActions(context, provider, server),
                  ],
                ),
              ),
      ),
    );
  }

  void _archiveServerWithUndo(
    BuildContext context,
    ServerProvider provider,
    MumbleServer server,
  ) {
    provider.archiveServer(server.id);
    ShadSonner.of(context).show(
      ShadToast(
        title: const Text('Server archived'),
        action: ShadButton.outline(
          size: ShadButtonSize.sm,
          child: const Text('undo'),
          onPressed: () {
            provider.unarchiveServer(server.id);
          },
        ),
      ),
    );
  }

  Widget _buildServerActions(
    BuildContext context,
    ServerProvider provider,
    MumbleServer server,
  ) {
    final theme = ShadTheme.of(context);
    final controller = ShadPopoverController();
    return ShadPopover(
      controller: controller,
      popover: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadButton.ghost(
                width: double.infinity,
                mainAxisAlignment: MainAxisAlignment.start,
                onPressed: () {
                  controller.hide();
                  _showAddServerDialog(context, server: server);
                },
                child: const Row(
                  children: [
                    Icon(LucideIcons.pencil, size: 16),
                    SizedBox(width: 8),
                    Text('Edit Server'),
                  ],
                ),
              ),
              ShadButton.ghost(
                width: double.infinity,
                mainAxisAlignment: MainAxisAlignment.start,
                foregroundColor: server.isArchived
                    ? theme.colorScheme.primary
                    : theme.colorScheme.foreground,
                onPressed: () {
                  controller.hide();
                  if (server.isArchived) {
                    provider.unarchiveServer(server.id);
                  } else {
                    _archiveServerWithUndo(context, provider, server);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      server.isArchived
                          ? LucideIcons.archiveRestore
                          : LucideIcons.archive,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      server.isArchived ? 'Restore Server' : 'Archive Server',
                    ),
                  ],
                ),
              ),
              if (server.isArchived)
                ShadButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  foregroundColor: Colors.redAccent,
                  onPressed: () {
                    controller.hide();
                    provider.deleteServer(server.id);
                  },
                  child: const Row(
                    children: [
                      Icon(LucideIcons.trash, size: 16),
                      SizedBox(width: 8),
                      Text('Permanently Delete'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      child: ShadIconButton.ghost(
        onPressed: controller.toggle,
        icon: Icon(
          LucideIcons.ellipsis,
          size: 20,
          color: theme.colorScheme.foreground.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<void> _connectToServer(
    MumbleService service,
    MumbleServer server,
  ) async {
    setState(() => _connectingServerId = server.id);
    try {
      await service.connect(server);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      String message = 'Failed to connect to server.';
      bool showEdit = false;

      // Extract specific reason from RejectException or PermissionDeniedException if present
      if (e.toString().contains(':')) {
        message = e.toString().split(':').last.trim();
      }

      if (errorStr.contains('password')) {
        message = message.isEmpty ? 'Incorrect password.' : message;
        showEdit = true;
      } else if (errorStr.contains('invalidusername') ||
          errorStr.contains('invalid user name')) {
        message = message.isEmpty
            ? 'The username is invalid on this server.'
            : message;
        showEdit = true;
      } else if (errorStr.contains('denied')) {
        message = message.isEmpty ? 'Connection denied.' : message;
        showEdit = true;
      } else if (errorStr.contains('timeout') ||
          errorStr.contains('connection refused')) {
        message = 'Server is unreachable. Check the address and port.';
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
        if (showEdit) {
          _showAddServerDialog(context, server: server);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _connectingServerId = null);
      }
    }
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
            width: 1,
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

  Widget _buildPTTButton(MumbleService service) {
    final bool isTalking = service.isTalking;
    final bool isSuppressed = service.isSuppressed;
    final settings = Provider.of<SettingsService>(context);

    String label = isSuppressed
        ? 'SUPPRESSED'
        : (isTalking ? 'TALKING...' : 'HOLD TO TALK');
    if (!isSuppressed && !isTalking && settings.pttKey != PttKey.none) {
      label = 'HOLD ${settings.pttKey.name.toUpperCase()}';
    }

    final theme = ShadTheme.of(context);

    return Listener(
      onPointerDown: (_) => isSuppressed ? null : service.startPushToTalk(),
      onPointerUp: (_) => service.stopPushToTalk(),
      onPointerCancel: (_) => service.stopPushToTalk(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSuppressed
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.destructive.withValues(alpha: 0.1),
                    theme.colorScheme.destructive.withValues(alpha: 0.2),
                  ],
                )
              : isTalking
              ? const LinearGradient(
                  colors: [
                    Colors.blueAccent,
                    Color(0xFF448AFF), // Lighter blue
                  ],
                )
              : LinearGradient(
                  colors: [kBrandGreen, kBrandGreen.withValues(alpha: 0.8)],
                ),
          borderRadius: BorderRadius.circular(16),
          border: isSuppressed
              ? Border.all(
                  color: theme.colorScheme.destructive.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isSuppressed
                  ? Colors.transparent
                  : isTalking
                  ? Colors.blueAccent.withValues(alpha: 0.4)
                  : kBrandGreen.withValues(alpha: 0.2),
              blurRadius: isTalking ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuppressed
                    ? LucideIcons.micOff
                    : (isTalking ? LucideIcons.audioLines : LucideIcons.mic),
                color: isSuppressed
                    ? theme.colorScheme.destructive
                    : isTalking
                    ? Colors.white
                    : Colors.black, // High contrast on bright green
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSuppressed
                      ? theme.colorScheme.destructive
                      : isTalking
                      ? Colors.white
                      : Colors.black, // High contrast on bright green
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicStatus(MumbleService service) {
    final theme = ShadTheme.of(context);
    final double volume = service.currentVolume;
    final bool isTalking = service.isTalking;
    Color statusColor;
    IconData iconData = LucideIcons.mic;

    if (isTalking) {
      statusColor = Colors.blueAccent;
    } else if (service.hasMicPermission && !service.isSuppressed) {
      statusColor = Colors.greenAccent;
    } else {
      statusColor = Colors.grey;
      iconData = LucideIcons.micOff;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.card,
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 24 + (volume * 22), // More exaggerated scaling
              height: 24 + (volume * 22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(
                  alpha: isTalking
                      ? (0.15 + (volume * 0.25))
                      : (0.2 + (volume * 0.1)),
                ),
              ),
            ),
            Icon(
              iconData,
              size: 20,
              color: isTalking
                  ? statusColor
                  : statusColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
