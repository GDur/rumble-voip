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
    
    return ShadContextMenu(
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
        const Divider(), // ShadContextMenu doesn't have a specific divider, using Divider or just list
        ShadContextMenuItem(
          onPressed: () {
            showShadDialog(
              context: context,
              builder: (context) => ShadDialog.alert(
                title: const Text('Delete Server'),
                description: Text(
                  'Are you sure you want to delete "${server.name}"? This action cannot be undone.',
                ),
                actions: [
                  ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ShadButton.destructive(
                    onPressed: () {
                      provider.deleteServer(server.id);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          leading: const Icon(LucideIcons.trash2, size: 16),
          child: const Text('Delete'),
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
