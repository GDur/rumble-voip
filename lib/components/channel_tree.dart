import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:rumble/utils/html_utils.dart';

class ChannelTree extends StatefulWidget {
  final List<MumbleChannel> channels;
  final List<MumbleUser> users;
  final Map<int, bool> talkingUsers;
  final MumbleUser? self;
  final bool hasMicPermission;
  final Function(MumbleChannel) onChannelTap;

  const ChannelTree({
    super.key,
    required this.channels,
    required this.users,
    required this.talkingUsers,
    this.self,
    required this.hasMicPermission,
    required this.onChannelTap,
  });

  @override
  State<ChannelTree> createState() => _ChannelTreeState();
}

class _ChannelTreeState extends State<ChannelTree> {
  final Set<int> _manualToggles = {};

  // Selection state
  int? _selectedChannelId;
  int? _selectedUserSession;

  // Hover state
  int? _hoveredChannelId;
  int? _hoveredUserSession;

  // Track flattened list of visible items for keyboard navigation
  final List<dynamic> _visibleItems = [];

  Set<int> get _channelsWithUsers {
    final result = <int>{};

    void addPath(int? channelId) {
      int? currentId = channelId;
      while (currentId != null) {
        result.add(currentId);
        final current = widget.channels.cast<MumbleChannel?>().firstWhere(
          (c) => c?.id == currentId,
          orElse: () => null,
        );
        currentId = current?.parentId;
      }
    }

    for (final user in widget.users) {
      addPath(user.channelId);
    }

    if (widget.self != null) {
      addPath(widget.self!.channelId);
    }

    return result;
  }

  bool _isExpanded(int channelId) {
    if (_channelsWithUsers.contains(channelId)) return true;
    return _manualToggles.contains(channelId);
  }

  void _toggleChannel(int channelId) {
    setState(() {
      if (_manualToggles.contains(channelId)) {
        _manualToggles.remove(channelId);
      } else {
        _manualToggles.add(channelId);
      }
    });
  }

  void _onEnterChannel(MumbleChannel channel) {
    widget.onChannelTap(channel);
  }

  void _selectChannel(MumbleChannel channel) {
    setState(() {
      _selectedChannelId = channel.id;
      _selectedUserSession = null;
    });
  }

  void _selectUser(MumbleUser user) {
    setState(() {
      _selectedUserSession = user.session;
      _selectedChannelId = null;
    });
  }

  void _showSetNoticeDialog(BuildContext context, MumbleUser self) {
    final initialText = self.comment ?? '';
    final controller = TextEditingController(text: initialText);
    if (initialText.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    }

    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Set Personal Notice'),
        description: const Text('This notice will be visible to other users.'),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ShadButton(
            child: const Text('Save Notice'),
            onPressed: () {
              // Rust set_comment functionality would go here
              Navigator.of(context).pop();
            },
          ),
        ],
        child: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ShadInput(
            controller: controller,
            placeholder: const Text('Enter your notice...'),
            maxLines: 3,
            autofocus: true,
          ),
        ),
      ),
    );
  }

  void _showUserVolumeDialog(BuildContext context, MumbleUser user) {
    final mumbleService = Provider.of<MumbleService>(context, listen: false);
    double volume = mumbleService.getUserVolume(user);

    showShadDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = ShadTheme.of(context);
          return ShadDialog(
            title: Text('Volume for ${user.name}'),
            description: const Text(
              'Adjust the playback volume for this user individually.',
            ),
            actions: [
              ShadButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            child: Container(
              width: 400,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ShadSlider(
                      initialValue: volume,
                      min: 0.0,
                      max: 2.0,
                      onChanged: (v) {
                        setState(() => volume = v);
                        mumbleService.setUserVolume(user, v);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${(volume * 100).round()}%',
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _visibleItems.clear();
    final rootChannels = widget.channels
        .where((c) => c.parentId == null || c.id == 0)
        .toList();

    // Sort root channels
    rootChannels.sort((a, b) => a.position.compareTo(b.position));

    _buildVisibleItems(rootChannels);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _ArrowIntent.up(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _ArrowIntent.down(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _ArrowIntent.left(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _ArrowIntent.right(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _EnterIntent(),
      },
      child: Actions(
        actions: {
          _ArrowIntent: CallbackAction<_ArrowIntent>(
            onInvoke: (intent) => _handleNavigation(intent.direction),
          ),
          _EnterIntent: CallbackAction<_EnterIntent>(
            onInvoke: (intent) {
              if (_selectedChannelId != null) {
                final channel = widget.channels.firstWhere(
                  (c) => c.id == _selectedChannelId,
                );
                _onEnterChannel(channel);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rootChannels
                    .map((c) => _buildChannelItem(context, c, 0))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _buildVisibleItems(List<MumbleChannel> currentChannels) {
    for (var channel in currentChannels) {
      _visibleItems.add(channel);
      if (_isExpanded(channel.id)) {
        // Add users
        final usersInChannel = widget.users
            .where((u) => u.channelId == channel.id)
            .toList();

        // Sort users by name
        usersInChannel.sort(
          (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
        );

        for (var user in usersInChannel) {
          _visibleItems.add(user);
        }

        // Add subchannels
        final subChannels = widget.channels
            .where((c) => c.parentId == channel.id)
            .toList();

        // Sort subchannels
        subChannels.sort((a, b) {
          if (a.position != b.position) {
            return (a.position).compareTo(b.position);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        _buildVisibleItems(subChannels);
      }
    }
  }

  void _handleNavigation(TraversalDirection direction) {
    if (_visibleItems.isEmpty) return;

    int currentIndex = -1;
    if (_selectedChannelId != null) {
      currentIndex = _visibleItems.indexWhere(
        (item) => item is MumbleChannel && item.id == _selectedChannelId,
      );
    } else if (_selectedUserSession != null) {
      currentIndex = _visibleItems.indexWhere(
        (item) => item is MumbleUser && item.session == _selectedUserSession,
      );
    }

    if (direction == TraversalDirection.down) {
      currentIndex = (currentIndex + 1).clamp(0, _visibleItems.length - 1);
    } else if (direction == TraversalDirection.up) {
      currentIndex = (currentIndex - 1).clamp(0, _visibleItems.length - 1);
    } else if (direction == TraversalDirection.right) {
      if (_selectedChannelId != null) {
        if (!_isExpanded(_selectedChannelId!)) {
          _toggleChannel(_selectedChannelId!);
        }
      }
      return;
    } else if (direction == TraversalDirection.left) {
      if (_selectedChannelId != null) {
        if (_isExpanded(_selectedChannelId!)) {
          _toggleChannel(_selectedChannelId!);
        } else {
          final channel = widget.channels.firstWhere(
            (c) => c.id == _selectedChannelId,
          );
          if (channel.parentId != null) {
            final parent = widget.channels.firstWhere(
              (c) => c.id == channel.parentId,
            );
            _selectChannel(parent);
          }
        }
      } else if (_selectedUserSession != null) {
        final user = widget.users.firstWhere(
          (u) => u.session == _selectedUserSession,
          orElse: () => widget.self!,
        );
        final channel = widget.channels.firstWhere(
          (c) => c.id == user.channelId,
        );
        _selectChannel(channel);
      }
      return;
    }

    if (currentIndex != -1) {
      final item = _visibleItems[currentIndex];
      if (item is MumbleChannel) {
        _selectChannel(item);
      } else if (item is MumbleUser) {
        _selectUser(item);
      }
    }
  }

  Widget _buildChannelItem(
    BuildContext context,
    MumbleChannel channel,
    int depth,
  ) {
    final theme = ShadTheme.of(context);
    final subChannels = widget.channels
        .where((c) => c.parentId == channel.id)
        .toList();
    final usersInChannel = widget.users
        .where((u) => u.channelId == channel.id)
        .toList();

    subChannels.sort((a, b) {
      if (a.position != b.position) {
        return (a.position).compareTo(b.position);
      }
      return (a.name).toLowerCase().compareTo((b.name).toLowerCase());
    });

    usersInChannel.sort(
      (a, b) => (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
    );

    int userCount = usersInChannel.length;
    final bool isMyChannel = widget.self?.channelId == channel.id;
    final bool expanded = _isExpanded(channel.id);
    final bool hasChildren =
        subChannels.isNotEmpty || usersInChannel.isNotEmpty;
    final bool isSelected = _selectedChannelId == channel.id;
    final bool isHovered = _hoveredChannelId == channel.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onDoubleTap: () => _onEnterChannel(channel),
          onTap: () => _selectChannel(channel),
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredChannelId = channel.id),
            onExit: (_) => setState(() => _hoveredChannelId = null),
            child: Container(
              margin: const EdgeInsets.only(
                left: 4,
                right: 12,
                top: 1,
                bottom: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : isHovered
                    ? theme.colorScheme.accent.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(width: depth * 16.0),
                  GestureDetector(
                    onTap: () => _toggleChannel(channel.id),
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      child: hasChildren && channel.id != 0
                          ? Icon(
                              expanded
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronRight,
                              size: 14,
                              color: theme.colorScheme.foreground.withValues(
                                alpha: 0.4,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      channel.name,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: isMyChannel
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isMyChannel
                            ? theme.colorScheme.primary
                            : theme.textTheme.small.color,
                      ),
                    ),
                  ),
                  if (userCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.muted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$userCount',
                        style: theme.textTheme.muted.copyWith(fontSize: 10),
                      ),
                    ),
                  if (channel.isEnterRestricted == true) ...[
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.lock,
                      size: 12,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                  if (channel.description != null &&
                      channel.description!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    NoticeButton(
                      title: 'Channel Description',
                      notice: HtmlUtils.sanitizeMumbleHtml(
                        channel.description!,
                      ),
                      icon: LucideIcons.info,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          ...usersInChannel.map((u) => _buildUserItem(context, u, depth)),
          ...subChannels.map((c) => _buildChannelItem(context, c, depth + 1)),
        ],
      ],
    );
  }

  Widget _buildUserItem(BuildContext context, MumbleUser u, int depth) {
    final theme = ShadTheme.of(context);
    final mumbleService = Provider.of<MumbleService>(context, listen: false);
    final isTalking = widget.talkingUsers[u.session] ?? false;
    final bool isMe = widget.self?.session == u.session;
    final bool isSelected = _selectedUserSession == u.session;
    final bool isHovered = _hoveredUserSession == u.session;
    final bool isMuted = u.isMuted;
    final bool isDeaf = u.isDeafened;
    final bool isSuppressed = u.isSuppressed;

    Color statusColor;
    if (isTalking) {
      statusColor = Colors.blueAccent;
    } else {
      if (isDeaf) {
        statusColor = Colors.redAccent.withValues(alpha: 0.6);
      } else if (isMuted || isSuppressed) {
        statusColor = Colors.grey;
      } else {
        final bool hasMic = isMe ? widget.hasMicPermission : true;
        statusColor = hasMic ? Colors.greenAccent : Colors.grey;
      }
    }

    Widget content = Container(
      /**
       * Very important. Visually the user is no perfeclty aligned
       * with other channels (with their indicator point.)
       * 38 px is the standard distance and the root has a depths of 0.
       * And the next ones then + 1 * 16 , + 2 * 16 etc 
       */
      margin: EdgeInsets.only(
        left: 38.0 + ((depth) * 16.0),
        right: 16,
        top: 1,
        bottom: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : isHovered
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : isHovered
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: isTalking ? 8 : 4,
                  spreadRadius: isTalking ? 2 : 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${u.name} (You)' : (u.name),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: (isTalking || isSelected)
                    ? theme.colorScheme.foreground
                    : theme.colorScheme.foreground.withValues(alpha: 0.6),
                fontWeight: (isTalking || isMe || isSelected)
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          if (isMuted || isSuppressed) ...[
            const SizedBox(width: 8),
            ShadButton.ghost(
              padding: EdgeInsets.zero,
              width: 20,
              height: 20,
              onPressed: () {},
              child: ShadPopover(
                controller: ShadPopoverController(),
                popover: (context) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      isSuppressed ? 'Suppressed by Server' : 'Muted',
                      style: theme.textTheme.small,
                    ),
                  );
                },
                child: Icon(
                  LucideIcons.micOff,
                  size: 14,
                  color: theme.colorScheme.destructive.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          if (isDeaf) ...[
            const SizedBox(width: 4),
            ShadButton.ghost(
              padding: EdgeInsets.zero,
              width: 20,
              height: 20,
              onPressed: () {},
              child: ShadPopover(
                controller: ShadPopoverController(),
                popover: (context) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Text('Deafened', style: theme.textTheme.small),
                  );
                },
                child: Icon(
                  LucideIcons.headphoneOff,
                  size: 14,
                  color: theme.colorScheme.destructive.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
          if (u.comment != null && u.comment!.isNotEmpty) ...[
            const SizedBox(width: 6),
            NoticeButton(
              title: 'User Notice',
              notice: HtmlUtils.sanitizeMumbleHtml(u.comment!),
              icon: LucideIcons.fileText,
            ),
          ],
        ],
      ),
    );

    final List<Widget> contextMenuItems = [];

    if (isMe && widget.self != null) {
      contextMenuItems.addAll([
        ShadContextMenuItem(
          onPressed: () => _showSetNoticeDialog(context, widget.self!),
          leading: const Icon(LucideIcons.filePenLine, size: 16),
          child: const Text('Set Self Notice'),
        ),
        const Divider(height: 1),
        ShadContextMenuItem(
          onPressed: () => mumbleService.toggleMute(),
          leading: Icon(
            mumbleService.isMuted ? LucideIcons.mic : LucideIcons.micOff,
            size: 16,
          ),
          child: Text(mumbleService.isMuted ? 'Unmute' : 'Mute'),
        ),
        ShadContextMenuItem(
          onPressed: () => mumbleService.toggleDeafen(),
          leading: Icon(
            mumbleService.isDeafened
                ? LucideIcons.headphones
                : LucideIcons.headphoneOff,
            size: 16,
          ),
          child: Text(mumbleService.isDeafened ? 'Undeafen' : 'Deafen'),
        ),
      ]);
    }

    if (!isMe) {
      contextMenuItems.add(
        ShadContextMenuItem(
          onPressed: () => _showUserVolumeDialog(context, u),
          leading: const Icon(LucideIcons.volume2, size: 16),
          child: const Text('Adjust User Volume'),
        ),
      );
    }

    if (contextMenuItems.isNotEmpty) {
      content = ShadContextMenuRegion(
        longPressEnabled: true,
        items: contextMenuItems,
        child: content,
      );
    }

    return GestureDetector(
      onTapDown: (_) => _selectUser(u),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredUserSession = u.session),
        onExit: (_) => setState(() => _hoveredUserSession = null),
        child: content,
      ),
    );
  }
}

class NoticeButton extends StatefulWidget {
  final String title;
  final String notice;
  final IconData icon;

  const NoticeButton({
    super.key,
    required this.title,
    required this.notice,
    required this.icon,
  });

  @override
  State<NoticeButton> createState() => _NoticeButtonState();
}

class _NoticeButtonState extends State<NoticeButton> {
  final controller = ShadPopoverController();
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _showPopover() {
    _hideTimer?.cancel();
    if (!controller.isOpen) controller.show();
  }

  void _hidePopover() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) controller.hide();
    });
  }

  void _showImageModal(String imageUrl) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Image Preview'),
        description: const Text('Click outside to close'),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InteractiveViewer(
              child: imageUrl.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(imageUrl.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return MouseRegion(
      onEnter: (_) => _showPopover(),
      onExit: (_) => _hidePopover(),
      child: ShadPopover(
        controller: controller,
        popover: (context) => MouseRegion(
          onEnter: (_) => _showPopover(),
          onExit: (_) => _hidePopover(),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  HtmlWidget(
                    widget.notice,
                    onTapImage: (imageData) {
                      _showImageModal(imageData.sources.first.url);
                    },
                    onTapUrl: (url) async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                      return true;
                    },
                    textStyle: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.foreground.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: ShadButton.ghost(
          padding: EdgeInsets.zero,
          width: 24,
          height: 24,
          onPressed: () => controller.toggle(),
          child: Icon(
            widget.icon,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _ArrowIntent extends Intent {
  final TraversalDirection direction;
  const _ArrowIntent.up() : direction = TraversalDirection.up;
  const _ArrowIntent.down() : direction = TraversalDirection.down;
  const _ArrowIntent.left() : direction = TraversalDirection.left;
  const _ArrowIntent.right() : direction = TraversalDirection.right;
}

class _EnterIntent extends Intent {
  const _EnterIntent();
}
