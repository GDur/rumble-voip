import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/rumble_tooltip.dart';

// Component: server-actions
class ServerActions extends StatefulWidget {
  final ServerProvider provider;
  final MumbleServer server;
  final Function(BuildContext, MumbleServer?) onShowAddServerDialog;
  final Function(BuildContext, ServerProvider, MumbleServer)
  onArchiveServerWithUndo;

  const ServerActions({
    super.key,
    required this.provider,
    required this.server,
    required this.onShowAddServerDialog,
    required this.onArchiveServerWithUndo,
  });

  @override
  State<ServerActions> createState() => _ServerActionsState();
}

class _ServerActionsState extends State<ServerActions> {
  final controller = ShadPopoverController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isArchived = widget.server.isArchived;

    return ShadPopover(
      controller: controller,
      popover: (context) {
        return SizedBox(
          width: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadButton.ghost(
                onPressed: () {
                  controller.hide();
                  widget.onShowAddServerDialog(context, widget.server);
                },
                leading: const Icon(LucideIcons.pencil, size: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                mainAxisAlignment: MainAxisAlignment.start,
                child: const Text('Edit'),
              ),
              ShadButton.ghost(
                onPressed: () {
                  controller.hide();
                  if (isArchived) {
                    widget.provider.unarchiveServer(widget.server.id);
                  } else {
                    widget.onArchiveServerWithUndo(
                      context,
                      widget.provider,
                      widget.server,
                    );
                  }
                },
                leading: Icon(
                  isArchived ? LucideIcons.archiveRestore : LucideIcons.archive,
                  size: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                mainAxisAlignment: MainAxisAlignment.start,
                child: Text(isArchived ? 'Restore' : 'Archive'),
              ),
            ],
          ),
        );
      },
      child: RumbleTooltip(
        message: 'Server Actions',
        child: ShadIconButton.ghost(
          icon: Icon(
            LucideIcons.ellipsisVertical,
            size: 16,
            color: theme.colorScheme.foreground.withValues(alpha: 0.5),
          ),
          width: 32,
          height: 32,
          padding: EdgeInsets.zero,
          decoration: ShadDecoration(shape: BoxShape.circle),
          onPressed: () => controller.toggle(),
        ),
      ),
    );
  }
}
