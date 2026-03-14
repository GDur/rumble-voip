import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/models/server.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/services/hotkey_service.dart';

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
        ProxyProvider2<MumbleService, SettingsService, HotkeyService>(
          update: (context, mumble, settings, previous) => 
              previous ?? HotkeyService(mumble, settings),
          dispose: (context, hotkey) => hotkey.dispose(),
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MumbleService()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => ShadApp(
          title: 'Rumble',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadSlateColorScheme.light(),
            textTheme: ShadTextTheme(p: const TextStyle(fontFamily: 'Outfit')),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadSlateColorScheme.dark(),
            primaryButtonTheme: ShadButtonTheme(
              backgroundColor: const Color(0xFF64FFDA),
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
  final _usernameController = TextEditingController(text: 'Rumble - Mumble Reloaded');
  final _passwordController = TextEditingController();
  bool _isAutoName = true;
  String? _connectingServerId;

  @override
  void dispose() {
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
            description: const Text('Configure global Push-to-Talk hotkeys.'),
            actions: [
              ShadButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            child: Container(
              width: 440,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        ShadOption(value: ThemeMode.system, child: const Text('System')),
                        ShadOption(value: ThemeMode.light, child: const Text('Light')),
                        ShadOption(value: ThemeMode.dark, child: const Text('Dark')),
                      ],
                      selectedOptionBuilder: (context, value) => Text(value.name.toUpperCase()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('PTT Hotkey', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ShadSelect<PttKey>(
                      placeholder: const Text('Select a key'),
                      initialValue: settings.pttKey,
                      onChanged: (value) {
                        if (value != null) {
                          settings.setPttKey(value);
                          setDialogState(() {});
                        }
                      },
                      options: PttKey.values.map((k) {
                         String label = k.name.toUpperCase();
                         if (k == PttKey.none) label = 'DISABLED';
                         return ShadOption(value: k, child: Text(label));
                      }).toList(),
                      selectedOptionBuilder: (context, value) => Text(value.name.toUpperCase()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (settings.pttKey != PttKey.none) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Suppress original function', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                'If enabled, the key will not perform its original duty (e.g. CapsLock LED won\'t toggle).',
                                style: TextStyle(fontSize: 12, color: Colors.white54),
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
                ],
              ),
            ),
          );
        },
      ),
    ));
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
      _isAutoName = true;
    }

    showShadDialog(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
            title: Text(server == null ? 'Add New Server' : 'Edit Server'),
            description: const Text('Enter the server details below.'),
            actions: [
              ShadButton.outline(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ShadButton(
                child: const Text('Save Server'),
                onPressed: () {
                  if (_hostController.text.isNotEmpty) {
                    final username = _usernameController.text.trim();
                    final newServer = MumbleServer(
                      id: server?.id,
                      name: _nameController.text.isEmpty ? _hostController.text : _nameController.text,
                      host: _hostController.text,
                      port: int.tryParse(_portController.text) ?? 64738,
                      username: username,
                      password: _passwordController.text,
                    );
                    if (server == null) {
                      Provider.of<ServerProvider>(context, listen: false).addServer(newServer);
                    } else {
                      Provider.of<ServerProvider>(context, listen: false).updateServer(newServer);
                    }
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
            child: Container(
              width: 440,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: ShadInput(
                      top: const Text('Server Address (Host)'),
                      placeholder: const Text('mumble.example.com'),
                      controller: _hostController,
                      onChanged: (val) {
                        if (_isAutoName) {
                          setDialogState(() => _nameController.text = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: ShadInput(
                      top: const Text('Display Name'),
                      placeholder: const Text('My Awesome Server'),
                      controller: _nameController,
                      onChanged: (val) => setDialogState(() => _isAutoName = false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: ShadInput(
                            top: const Text('Port'),
                            placeholder: const Text('64738'),
                            controller: _portController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: ShadInput(
                            top: const Text('Username'),
                            placeholder: const Text('Your Nickname'),
                            controller: _usernameController,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: ShadInput(
                      top: const Text('Password (Optional)'),
                      placeholder: const Text('Secret Password'),
                      controller: _passwordController,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);
    final serverProvider = Provider.of<ServerProvider>(context);

    final theme = ShadTheme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, mumbleService),
              Expanded(
                child: mumbleService.isConnected
                    ? ChannelTree(
                        channels: mumbleService.channels,
                        users: mumbleService.client?.getUsers().values.toList() ?? [],
                        talkingUsers: mumbleService.talkingUsers,
                        self: mumbleService.client?.self,
                        onChannelTap: (channel) {
                          mumbleService.client?.self.moveToChannel(channel: channel);
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

  Widget _buildHeader(BuildContext context, MumbleService service) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 24,
                    height: 24,
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
                      builder: (context) => const Text('You are connected to the Mumble server.'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: hideText ? 10 : 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64FFDA).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF64FFDA).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(radius: 4, backgroundColor: Color(0xFF64FFDA)),
                            if (!hideText) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'CONNECTED',
                                style: TextStyle(
                                  color: Color(0xFF64FFDA),
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
                      icon: Icon(LucideIcons.logOut, color: theme.colorScheme.foreground.withValues(alpha: 0.5), size: 20),
                    ),
                    const SizedBox(width: 4),
                    ShadIconButton.ghost(
                      onPressed: () => _showSettingsDialog(context),
                      icon: Icon(LucideIcons.settings, color: theme.colorScheme.foreground.withValues(alpha: 0.5), size: 20),
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
                  icon: Icon(LucideIcons.settings, color: theme.colorScheme.foreground.withValues(alpha: 0.5), size: 20),
                ),
                const SizedBox(width: 8),
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

  Widget _buildServerList(BuildContext context, ServerProvider provider, MumbleService service) {
    final theme = ShadTheme.of(context);
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF64FFDA)));
    }

    if (provider.servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.server, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No servers yet', style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5))),
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
        
        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          itemCount: provider.servers.length,
          itemBuilder: (context, index) {
            final server = provider.servers[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.border.withValues(alpha: 0.5)),
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
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(LucideIcons.server, color: theme.colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 24), // Space for the '...' menu
                                    child: Text(
                                      server.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.foreground),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${server.host}:${server.port}',
                              style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5), fontSize: 13),
                            ),
                            Text(
                              'User: ${server.username}',
                              style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ShadButton(
                                    onPressed: _connectingServerId == null ? () => _connectToServer(service, server) : null,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Opacity(
                                          opacity: _connectingServerId == server.id ? 0 : 1,
                                          child: const Text('CONNECT'),
                                        ),
                                          if (_connectingServerId == server.id)
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primaryForeground,
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
                        child: Icon(LucideIcons.server, color: theme.colorScheme.primary),
                      ),
                      title: Text(
                        server.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.foreground),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${server.host}:${server.port} • ${server.username}',
                          style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShadButton(
                            size: ShadButtonSize.sm,
                            onPressed: _connectingServerId == null ? () => _connectToServer(service, server) : null,
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
                          const SizedBox(width: 8),
                          _buildServerActions(context, provider, server),
                        ],
                      ),
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServerActions(BuildContext context, ServerProvider provider, MumbleServer server) {
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
                foregroundColor: Colors.redAccent,
                onPressed: () {
                  controller.hide();
                  provider.removeServer(server.id);
                },
                child: const Row(
                  children: [
                    Icon(LucideIcons.trash, size: 16),
                    SizedBox(width: 8),
                    Text('Delete Server'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      child: ShadIconButton.ghost(
        onPressed: controller.toggle,
        icon: Icon(LucideIcons.ellipsis, size: 20, color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
      ),
    );
  }

  Future<void> _connectToServer(MumbleService service, MumbleServer server) async {
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
      } else if (errorStr.contains('invalidusername') || errorStr.contains('invalid user name')) {
        message = message.isEmpty ? 'The username is invalid on this server.' : message;
        showEdit = true;
      } else if (errorStr.contains('denied')) {
        message = message.isEmpty ? 'Connection denied.' : message;
        showEdit = true;
      } else if (errorStr.contains('timeout') || errorStr.contains('connection refused')) {
        message = 'Server is unreachable. Check the address and port.';
      } else if (errorStr.contains('hostname') || errorStr.contains('host not found')) {
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
          top: BorderSide(color: theme.colorScheme.border.withValues(alpha: 0.5), width: 1),
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
    
    String label = isSuppressed ? 'SUPPRESSED' : (isTalking ? 'TALKING...' : 'HOLD TO TALK');
    if (!isSuppressed && !isTalking && settings.pttKey != PttKey.none) {
      label = 'HOLD ${settings.pttKey.name.toUpperCase()}';
    }

    final theme = ShadTheme.of(context);
    
    return GestureDetector(
      onTapDown: (_) => isSuppressed ? null : service.startPushToTalk(),
      onTapUp: (_) => service.stopPushToTalk(),
      onTapCancel: () => service.stopPushToTalk(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSuppressed 
            ? LinearGradient(colors: [
                theme.colorScheme.destructive.withValues(alpha: 0.1), 
                theme.colorScheme.destructive.withValues(alpha: 0.2)
              ])
            : LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(16),
          border: isSuppressed 
            ? Border.all(color: theme.colorScheme.destructive.withValues(alpha: 0.4), width: 1)
            : null,
          boxShadow: [
            BoxShadow(
              color: isSuppressed 
                ? Colors.transparent 
                : theme.colorScheme.primary.withValues(alpha: isTalking ? 0.4 : 0.2),
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
                color: isSuppressed ? theme.colorScheme.destructive : theme.colorScheme.primaryForeground, 
                size: 20
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSuppressed ? theme.colorScheme.destructive : theme.colorScheme.primaryForeground,
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

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border.withValues(alpha: 0.3)),
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
                color: (isTalking ? theme.colorScheme.primary : theme.colorScheme.foreground).withValues(
                  alpha: isTalking ? (0.15 + (volume * 0.25)) : (0.05 + (volume * 0.1)),
                ),
              ),
            ),
            Icon(
              isTalking ? LucideIcons.mic : LucideIcons.micOff,
              size: 20,
              color: isTalking ? theme.colorScheme.primary : theme.colorScheme.foreground.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
