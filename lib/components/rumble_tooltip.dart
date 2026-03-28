import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RumbleTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final WidgetBuilder? builder;
  final ShadPopoverController? controller;
  final ShadAnchorBase? anchor;
  final Duration? waitDuration;
  final Duration? showDuration;

  const RumbleTooltip({
    super.key,
    required this.child,
    this.message = '',
    this.builder,
    this.controller,
    this.anchor,
    this.waitDuration,
    this.showDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty && builder == null) return child;
    final theme = ShadTheme.of(context);
    
    return ShadTooltip(
      controller: controller,
      anchor: anchor,
      waitDuration: waitDuration ?? const Duration(milliseconds: 500),
      showDuration: showDuration,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: ShadDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        border: ShadBorder.all(
          color: theme.colorScheme.border.withValues(alpha: 0.8),
          width: 1,
          radius: const BorderRadius.all(Radius.circular(10)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      builder: builder ?? (context) {
        return Text(
          message,
          style: theme.textTheme.small.copyWith(
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        );
      },
      child: ShadGestureDetector(
        child: child,
      ),
    );
  }
}
