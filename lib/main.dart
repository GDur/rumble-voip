import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/utils/permissions.dart';
import 'package:rumble/components/audio_input_indicator.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/components/server_card.dart';
import 'package:rumble/components/permission_prompt.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/components/channel_tree.dart';
import 'package:dumble/dumble.dart' as dumble;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Rumble',
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MumbleServer? _selectedServer = initialServers.first;
  bool? _hasPermission;
  final MumbleService _mumbleService = MumbleService();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermission();
    _mumbleService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _checkInitialPermission() async {
    final granted = await PermissionUtils.isMicrophonePermissionGranted();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasPermission == false) {
      return PermissionPrompt(
        onGranted: () => setState(() => _hasPermission = true),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _mumbleService.isConnected 
              ? _buildChannelView()
              : _buildHomeView(),
            Positioned(
              top: 16,
              right: 16,
              child: AudioInputIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShadBadge(
              child: const Text('Rumble - Mumble Reloaded'),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Rumble',
              style: ShadTheme.of(context).textTheme.h1,
            ),
            const SizedBox(height: 8),
            Text(
              'The next-gen Mumble client.',
              style: ShadTheme.of(context).textTheme.muted,
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AVAILABLE SERVERS',
                    style: ShadTheme.of(context).textTheme.muted.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...initialServers.map((server) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ServerCard(
                      server: server,
                      isSelected: _selectedServer == server,
                      onTap: () => setState(() => _selectedServer = server),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ShadButton(
              enabled: _selectedServer != null && !_isConnecting,
              onPressed: () async {
                if (_selectedServer == null) return;
                
                setState(() => _isConnecting = true);
                try {
                  await _mumbleService.connect(_selectedServer!);
                  if (mounted) {
                     ShadToaster.of(context).show(
                      ShadToast(
                        description: Text('Connected to ${_selectedServer!.name}'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ShadToaster.of(context).show(
                      ShadToast.destructive(
                        description: Text('Connection failed: $e'),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isConnecting = false);
                }
              },
              child: _isConnecting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Connect to Server'),
            ),
            const SizedBox(height: 12),
            ShadButton.outline(
              onPressed: () {
                // TODO: Open settings
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelView() {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _mumbleService.disconnect(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedServer?.name ?? 'Connected',
                      style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_mumbleService.client?.getUsers().length ?? 0} users online',
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ShadButton.destructive(
                size: ShadButtonSize.sm,
                onPressed: () => _mumbleService.disconnect(),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mumbleService.channels.isEmpty
              ? const Center(child: Text('Synchronizing channels...'))
              : ChannelTree(
                  channels: _mumbleService.channels,
                  users: _mumbleService.client?.getUsers().values.toList() ?? [],
                  self: _mumbleService.client?.self,
                  onChannelTap: (channel) {
                    debugPrint('Tapped channel: ${channel.name}');
                  },
                ),
        ),
      ],
    );
  }
}
