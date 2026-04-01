import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Color kBrandGreen = Color(0xFF00FF7F);

class PushToTalkButton extends StatelessWidget {
  final MumbleService service;
  final double width;
  final double height;
  final bool compact;

  const PushToTalkButton({
    super.key,
    required this.service,
    this.width = 180,
    this.height = 48,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final theme = ShadTheme.of(context);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final bool isTalking = service.isTalking;
        final bool isSuppressed = service.isSuppressed;
        final bool isMuted = service.isMuted;

        final isDesktop = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.macOS);

        String label = compact ? 'PTT' : 'HOLD TO TALK';
        if (isSuppressed) {
          label = compact ? 'SUPPR' : 'SUPPRESSED';
        } else if (isMuted) {
          label = 'MUTED';
        } else if (isTalking) {
          label = 'TALKING...';
        } else if (!compact && isDesktop && settings.pttKey != PttKey.none) {
          label = 'HOLD [${settings.pttKey.name.toUpperCase()}]';
        }

        return Listener(
          onPointerDown: (_) => service.startPushToTalk(),
          onPointerUp: (_) => service.stopPushToTalk(),
          onPointerCancel: (_) => service.stopPushToTalk(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: height,
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
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.bold,
                letterSpacing: compact ? 0.8 : 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}
