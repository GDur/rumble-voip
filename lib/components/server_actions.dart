import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/server_provider.dart';

// Component: server-actions
class ServerActions extends StatelessWidget {
  final ServerProvider provider;
  final MumbleServer server;
  final Function(BuildContext, MumbleServer?) onShowAddServerDialog;
  final Function(BuildContext, ServerProvider, MumbleServer) onArchiveServerWithUndo;

  const ServerActions({
    super.key,
    required this.provider,
    required this.server,
    required this.onShowAddServerDialog,
    required this.onArchiveServerWithUndo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isArchived = server.isArchived;
    
    return ShadContextMenuRegion(
      tapEnabled: true,
      items: [
        ShadContextMenuItem(
          onPressed: () => onShowAddServerDialog(context, server),
          leading: const Icon(LucideIcons.pencil, size: 16),
          child: const Text('Edit'),
        ),
        ShadContextMenuItem(
          onPressed: () {
            if (isArchived) {
              provider.unarchiveServer(server.id);
            } else {
              onArchiveServerWithUndo(context, provider, server);
            }
          },
          leading: Icon(isArchived ? LucideIcons.archiveRestore : LucideIcons.archive, size: 16),
          child: Text(isArchived ? 'Restore' : 'Archive'),
        ),
      ],
      child: ShadButton.ghost(
        padding: EdgeInsets.zero,
        size: ShadButtonSize.sm,
        child: Icon(
          LucideIcons.ellipsisVertical,
          size: 16,
          color: theme.colorScheme.foreground.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
