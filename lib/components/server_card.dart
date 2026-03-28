import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/server_actions.dart';
import 'package:rumble/components/rumble_tooltip.dart';

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
        child: isMobile
            ? _buildMobileLayout(context, theme)
            : _buildDesktopLayout(context, theme),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ShadThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(top: -8, right: -8, child: _buildActions(context)),
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
                Expanded(child: _buildDetails(theme)),
                _buildStats(theme),
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
              _buildDetails(theme),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _buildStats(theme),
        const SizedBox(width: 24),
        _buildConnectButton(theme),
        const SizedBox(width: 8),
        _buildActions(context),
      ],
    );
  }

  Widget _buildIcon(ShadThemeData theme, {double size = 40}) {
    return RumbleTooltip(
      message: 'Mumble Server',
      child: Container(
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

  Widget _buildStats(ShadThemeData theme) {
    final ping = server.ping;
    final userCount = server.userCount;
    final maxUsers = server.maxUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RumbleTooltip(
          message: 'Server Latency (Ping)',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.wifi,
                color: ping != null
                    ? _getPingColor(ping)
                    : theme.colorScheme.mutedForeground,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                ping != null ? '${ping}ms' : '---',
                style: TextStyle(
                  color: theme.colorScheme.foreground.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        RumbleTooltip(
          message: 'Online Users',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                color: theme.colorScheme.foreground.withValues(alpha: 0.4),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                userCount != null ? '$userCount/${maxUsers ?? "?"}' : '0/0',
                style: TextStyle(
                  color: theme.colorScheme.foreground.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(
    ShadThemeData theme, {
    double? width,
    ShadButtonSize? size,
  }) {
    return SizedBox(
      width: width,
      child: RumbleTooltip(
        message: 'Connect to this server',
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
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return ServerActions(
      provider: provider,
      server: server,
      onShowAddServerDialog: (context, s) => onEdit(s!),
      onArchiveServerWithUndo: (context, p, s) =>
          _archiveServerWithUndo(context, p, s),
    );
  }

  void _archiveServerWithUndo(
    BuildContext context,
    ServerProvider provider,
    MumbleServer server,
  ) {
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

  Color _getPingColor(int ping) {
    if (ping < 50) return Colors.green;
    if (ping < 150) return Colors.orange;
    return Colors.red;
  }
}
