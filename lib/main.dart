import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
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
      providers: [ChangeNotifierProvider(create: (_) => MumbleService())],
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
  @override
  Widget build(BuildContext context) {
    final mumbleService = Provider.of<MumbleService>(context);

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
                        users:
                            mumbleService.client?.getUsers().values.toList() ??
                            [],
                        talkingUsers: mumbleService.talkingUsers,
                        self: mumbleService.client?.self,
                        onChannelTap: (channel) {
                          mumbleService.client?.self.moveToChannel(
                            channel: channel,
                          );
                        },
                      )
                    : _buildConnectPlaceholder(context, mumbleService),
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
                child: const Icon(
                  Icons.waves,
                  color: Color(0xFF64FFDA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Rumble',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          if (service.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF64FFDA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF64FFDA).withValues(alpha: 0.2),
                ),
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
        ],
      ),
    );
  }

  Widget _buildConnectPlaceholder(BuildContext context, MumbleService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF64FFDA).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_input_component,
                size: 80,
                color: const Color(0xFF64FFDA).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ready to Connect?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Join the conversation on rogue server.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ShadButton(
                onPressed: () {
                  service.connect(
                    MumbleServer(
                      name: 'Server',
                      host: 'mumble.rogueserver.com',
                      port: 64738,
                      username: 'Rumble - Mumble Reloaded',
                    ),
                  );
                },
                backgroundColor: const Color(0xFF64FFDA),
                child: const Text(
                  'CONNECT TO SERVER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (service.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    service.error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(MumbleService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
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

    return GestureDetector(
      onTapDown: (_) => service.startPushToTalk(),
      onTapUp: (_) => service.stopPushToTalk(),
      onTapCancel: () => service.stopPushToTalk(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF64FFDA), Color(0xFF14B8A6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF64FFDA,
              ).withValues(alpha: isTalking ? 0.4 : 0.2),
              blurRadius: isTalking ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTalking ? Icons.record_voice_over : Icons.mic,
              color: Colors.black,
              size: 20,
            ),
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
            // Volume wave effect
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 30 + (volume * 18),
              height: 30 + (volume * 18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isTalking ? const Color(0xFF64FFDA) : Colors.white)
                    .withValues(
                      alpha: isTalking
                          ? (0.1 + (volume * 0.2))
                          : (0.05 + (volume * 0.1)),
                    ),
              ),
            ),
            Icon(
              isTalking ? Icons.mic : Icons.mic_none,
              size: 20,
              color: isTalking
                  ? const Color(0xFF64FFDA)
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
