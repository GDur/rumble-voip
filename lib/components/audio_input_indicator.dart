import 'package:flutter/material.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AudioInputIndicator extends StatelessWidget {
  final MumbleService mumbleService;

  const AudioInputIndicator({super.key, required this.mumbleService});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ListenableBuilder(
      listenable: mumbleService,
      builder: (context, _) {
        final isTalking = mumbleService.isTalking;
        final volume = mumbleService.currentVolume;

        final activeColor = isTalking ? Colors.blue : Colors.greenAccent;
        final baseColor = isTalking ? Colors.blue : Colors.green;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isTalking ? 1.0 : 0.7,
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.popover.withAlpha(240),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTalking
                    ? Colors.blue.withAlpha(200)
                    : Colors.green.withAlpha(150),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isTalking ? Colors.blue : Colors.green).withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MIC STATUS',
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: activeColor.withAlpha(220),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withAlpha(200),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: baseColor.withAlpha(40)),
                  ),
                  child: Stack(
                    children: [
                      // Subdued track
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: baseColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Level bar
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (volume * 5.0).clamp(
                          0.01,
                          1.0,
                        ), // Always show a tiny bit if connected
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 40),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [activeColor.withAlpha(150), activeColor],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: volume > 0.05
                                ? [
                                    BoxShadow(
                                      color: activeColor.withAlpha(150),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
