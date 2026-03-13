import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:rumble/models/server.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
      child: ShadApp(
        title: 'Rumble',
        debugShowCheckedModeBanner: false,
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(),
          primaryButtonTheme: ShadButtonTheme(
            backgroundColor: const Color(0xFF64FFDA),
            foregroundColor: Colors.black,
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
  final _usernameController = TextEditingController(text: 'Rumble - Mumble Reloaded');
  final _passwordController = TextEditingController();
  bool _isAutoName = true;

  @override
  void dispose() {
    _hostController.dispose();
    _nameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      builder: (context) => StatefulBuilder(
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
              width: 400,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShadInput(
                    top: const Text('Server Address (Host)'),
                    placeholder: const Text('mumble.example.com'),
                    controller: _hostController,
                    onChanged: (val) {
                      if (_isAutoName) {
                        setDialogState(() => _nameController.text = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ShadInput(
                    top: const Text('Display Name'),
                    placeholder: const Text('My Awesome Server'),
                    controller: _nameController,
                    onChanged: (val) => setDialogState(() => _isAutoName = false),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ShadInput(
                          top: const Text('Port'),
                          placeholder: const Text('64738'),
                          controller: _portController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: ShadInput(
                          top: const Text('Username'),
                          placeholder: const Text('Your Nickname'),
                          controller: _usernameController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ShadInput(
                    top: const Text('Password (Optional)'),
                    placeholder: const Text('Secret Password'),
                    controller: _passwordController,
                    obscureText: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);
    final serverProvider = Provider.of<ServerProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
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
                  color: const Color(0xFF64FFDA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.waves, color: Color(0xFF64FFDA), size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rumble',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
                      color: const Color(0xFF64FFDA).withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (service.isConnected)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64FFDA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF64FFDA).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Color(0xFF64FFDA)),
                      SizedBox(width: 8),
                      Text(
                        'CONNECTED',
                        style: TextStyle(
                          color: Color(0xFF64FFDA),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                  onPressed: () => service.disconnect(),
                  tooltip: 'Disconnect',
                ),
              ],
            )
          else
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () => _showAddServerDialog(context),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 8),
                  Text('ADD SERVER'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServerList(BuildContext context, ServerProvider provider, MumbleService service) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF64FFDA)));
    }

    if (provider.servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dns_outlined, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            const Text('No servers yet', style: TextStyle(color: Colors.white54)),
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
                color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: isMobile 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64FFDA).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.dns, color: Color(0xFF64FFDA), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                server.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${server.host}:${server.port}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          'User: ${server.username}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ShadButton(
                                onPressed: () => _connectToServer(service, server),
                                child: const Text('CONNECT'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                              onPressed: () => _showAddServerDialog(context, server: server),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => provider.removeServer(server.id),
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
                          color: const Color(0xFF64FFDA).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.dns, color: Color(0xFF64FFDA)),
                      ),
                      title: Text(
                        server.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${server.host}:${server.port} • ${server.username}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                            onPressed: () => _showAddServerDialog(context, server: server),
                            tooltip: 'Edit Server',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => provider.removeServer(server.id),
                            tooltip: 'Delete Server',
                          ),
                          const SizedBox(width: 8),
                          ShadButton(
                            onPressed: () => _connectToServer(service, server),
                            child: const Text('CONNECT'),
                          ),
                        ],
                      ),
                    ),
              ),
            );
          },
        );
      }
    );
  }

  Future<void> _connectToServer(MumbleService service, MumbleServer server) async {
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
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Connection Error'),
            description: Text(message),
          ),
        );
        if (showEdit) {
          _showAddServerDialog(context, server: server);
        }
      }
    }
  }

  Widget _buildBottomBar(MumbleService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
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

    return GestureDetector(
      onTapDown: (_) => service.startPushToTalk(),
      onTapUp: (_) => service.stopPushToTalk(),
      onTapCancel: () => service.stopPushToTalk(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF64FFDA), Color(0xFF14B8A6)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64FFDA).withValues(alpha: isTalking ? 0.4 : 0.2),
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
              Icon(isTalking ? Icons.record_voice_over : Icons.mic, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Text(
                isTalking ? 'TALKING...' : 'HOLD TO TALK',
                style: const TextStyle(
                  color: Colors.black,
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
    final double volume = service.currentVolume;
    final bool isTalking = service.isTalking;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                color: (isTalking ? const Color(0xFF64FFDA) : Colors.white).withValues(
                  alpha: isTalking ? (0.15 + (volume * 0.25)) : (0.05 + (volume * 0.1)),
                ),
              ),
            ),
            Icon(
              isTalking ? Icons.mic : Icons.mic_none,
              size: 20,
              color: isTalking ? const Color(0xFF64FFDA) : Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
