import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/utils/permissions.dart';
import 'package:rumble/components/audio_input_indicator.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
              const SizedBox(height: 32),
              ShadButton(
                onPressed: () async {
                  final granted = await PermissionUtils.requestMicrophonePermission();
                  if (mounted) {
                    if (granted) {
                      ShadToaster.of(context).show(
                        const ShadToast(
                          description: Text('Microphone permission granted!'),
                        ),
                      );
                      // Refresh the UI to show the indicator is active
                      setState(() {});
                    } else {
                      ShadToaster.of(context).show(
                        const ShadToast.destructive(
                          description: Text('Microphone access is required.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Connect to Server'),
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
}
