import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';

class ServerCard extends StatelessWidget {
  final MumbleServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.accent.withAlpha(50) 
              : theme.colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.server,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${server.host}:${server.port}',
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (server.ping != null || server.userCount != null) ...[
                        if (server.ping != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.wifi,
                            size: 14,
                            color: _getPingColor(server.ping!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${server.ping}ms',
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        ],
                        if (server.userCount != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.users,
                            size: 14,
                            color: theme.colorScheme.mutedForeground.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${server.userCount}/${server.maxUsers ?? "?"}',
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                LucideIcons.circleCheck,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping < 50) return Colors.greenAccent;
    if (ping < 150) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
