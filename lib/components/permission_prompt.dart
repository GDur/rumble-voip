import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/utils/permissions.dart';

class PermissionPrompt extends StatelessWidget {
  final VoidCallback onGranted;

  const PermissionPrompt({super.key, required this.onGranted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ShadTheme.of(context).colorScheme.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 48,
                  color: ShadTheme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Microphone Access',
                style: ShadTheme.of(context).textTheme.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Rumble requires microphone access to let you communicate with others on Mumble servers.',
                style: ShadTheme.of(context).textTheme.muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ShadButton(
                onPressed: () async {
                  final granted = await PermissionUtils.requestMicrophonePermission();
                  if (granted) {
                    onGranted();
                  }
                },
                child: const Text('Allow Microphone Access'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
