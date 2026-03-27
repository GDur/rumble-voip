import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// Component: about-tab
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', height: 120, width: 120),
            const SizedBox(height: 16),
            const Text(
              'Rumble',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'v1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'A modern, cross-platform Mumble voice chat client built with Flutter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Created by Rumble Team',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'designed with ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
                Icon(
                  LucideIcons.heart,
                  size: 14,
                  color: theme.colorScheme.destructive.withValues(alpha: 0.8),
                ),
                Text(
                  ' and ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
                Icon(
                  LucideIcons.bot,
                  size: 14,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
                Text(
                  ' assistance',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
