import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/server_actions.dart';

// Component: server-card
class ServerCard extends StatelessWidget {
  final MumbleServer server;
  final ServerProvider provider;
  final bool isConnecting;
  final Function(MumbleServer) onConnect;
  final Function(MumbleServer) onEdit;

  const ServerCard({
    super.key,
    required this.server,
    required this.provider,
    required this.isConnecting,
    required this.onConnect,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: isMobile ? _buildMobileLayout(context, theme) : _buildDesktopLayout(context, theme),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ShadThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -8,
          right: -8,
          child: _buildActions(context),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIcon(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(
                      server.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDetails(theme),
                ),
                _buildStats(theme, horizontal: false),
              ],
            ),
            const SizedBox(height: 16),
            _buildConnectButton(theme, width: double.infinity),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, ShadThemeData theme) {
    return Row(
      children: [
        _buildIcon(theme, size: 48),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                server.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildDetails(theme),
                  if (server.ping != null || server.userCount != null) ...[
                    const SizedBox(width: 12),
                    _buildDot(theme),
                    const SizedBox(width: 12),
                    _buildStats(theme, horizontal: true),
                  ],
                ],
              ),
            ],
          ),
        ),
        _buildConnectButton(theme),
        const SizedBox(width: 8),
        _buildActions(context),
      ],
    );
  }

  Widget _buildIcon(ShadThemeData theme, {double size = 40}) {
    return Container(
      padding: EdgeInsets.all(size / 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        LucideIcons.server,
        color: theme.colorScheme.primary,
        size: size / 2,
      ),
    );
  }

  Widget _buildDetails(ShadThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${server.host}:${server.port}',
          style: TextStyle(
            color: theme.colorScheme.foreground.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        Text(
          'User: ${server.username}',
          style: TextStyle(
            color: theme.colorScheme.foreground.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(ShadThemeData theme, {required bool horizontal}) {
    final ping = server.ping;
    final userCount = server.userCount;
    
    if (ping == null && userCount == null) return const SizedBox.shrink();

    final widgets = [
      if (ping != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wifi,
              color: _getPingColor(ping),
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${ping}ms',
              style: TextStyle(
                color: theme.colorScheme.foreground.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      if (horizontal && ping != null && userCount != null) const SizedBox(width: 12),
      if (!horizontal && ping != null && userCount != null) const SizedBox(height: 4),
      if (userCount != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.users,
              color: theme.colorScheme.foreground.withValues(alpha: 0.5),
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '$userCount/${server.maxUsers ?? "?"}',
              style: TextStyle(
                color: theme.colorScheme.foreground.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
    ];

    return horizontal 
      ? Row(mainAxisSize: MainAxisSize.min, children: widgets)
      : Column(crossAxisAlignment: CrossAxisAlignment.end, children: widgets);
  }

  Widget _buildConnectButton(ShadThemeData theme, {double? width, ShadButtonSize? size}) {
    return SizedBox(
      width: width,
      child: ShadButton(
        size: size ?? ShadButtonSize.regular,
        onPressed: isConnecting ? null : () => onConnect(server),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isConnecting ? 0 : 1,
              child: const Text('CONNECT'),
            ),
            if (isConnecting)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primaryForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return ServerActions(
      provider: provider,
      server: server,
      onShowAddServerDialog: (context, s) => onEdit(s!),
      onArchiveServerWithUndo: (context, p, s) => _archiveServerWithUndo(context, p, s),
    );
  }

  void _archiveServerWithUndo(BuildContext context, ServerProvider provider, MumbleServer server) {
    provider.archiveServer(server.id);
    ShadSonner.of(context).show(
      ShadToast(
        title: const Text('Server archived'),
        action: ShadButton.outline(
          size: ShadButtonSize.sm,
          child: const Text('undo'),
          onPressed: () => provider.unarchiveServer(server.id),
        ),
      ),
    );
  }

  Widget _buildDot(ShadThemeData theme) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.foreground.withValues(alpha: 0.3),
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping < 50) return Colors.green;
    if (ping < 150) return Colors.orange;
    return Colors.red;
  }
}
