import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:provider/provider.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rumble/src/rust/api/client.dart';

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
    if (channelId == 0) return true;
    if (_channelsWithUsers.contains(channelId)) return true;
    return _manualToggles.contains(channelId);
  }

  void _toggleChannel(int channelId) {
    if (channelId == 0) return;
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
      _selectedUserSession = user.session as int;
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

    // This functionality might need a Rust side implementation
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
              // Rust set_comment functionality needed here
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
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _ArrowIntent.right(),
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
                final channel = widget.channels.firstWhere((c) => c.id == _selectedChannelId);
                _onEnterChannel(channel);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
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
          (a, b) => (a.name).toLowerCase().compareTo(
            (b.name).toLowerCase(),
          ),
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
            final parent = widget.channels.firstWhere((c) => c.id == channel.parentId);
            _selectChannel(parent);
          }
        }
      } else if (_selectedUserSession != null) {
        final user = widget.users.firstWhere(
          (u) => u.session == _selectedUserSession,
          orElse: () => widget.self!,
        );
        final channel = widget.channels.firstWhere((c) => c.id == user.channelId);
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

    // Sort sub-channels by position, then name
    subChannels.sort((a, b) {
      if (a.position != b.position) {
        return (a.position).compareTo(b.position);
      }
      return (a.name).toLowerCase().compareTo(
        (b.name).toLowerCase(),
      );
    });

    // Sort users by name
    usersInChannel.sort(
      (a, b) =>
          (a.name).toLowerCase().compareTo((b.name).toLowerCase()),
    );

    int userCount = usersInChannel.length;
    final bool isMyChannel =
        widget.self?.channelId == channel.id;
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
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredChannelId = channel.id),
            onExit: (_) => setState(() => _hoveredChannelId = null),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
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
                              color: theme.colorScheme.mutedForeground,
                            )
                          : null,
                    ),
                  ),
                  Icon(
                    channel.id == 0 ? LucideIcons.house : LucideIcons.hash,
                    size: 16,
                    color: isMyChannel
                        ? theme.colorScheme.primary
                        : theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      channel.name,
                      style: theme.textTheme.small.copyWith(
                        fontWeight:
                            isMyChannel ? FontWeight.bold : FontWeight.normal,
                        color: isMyChannel
                            ? theme.colorScheme.primary
                            : theme.textTheme.small.color,
                      ),
                    ),
                  ),
                  if (userCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
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
                    Icon(LucideIcons.lock,
                        size: 12, color: theme.colorScheme.mutedForeground),
                  ],
                  if (channel.description != null &&
                      channel.description!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _PopoverButton(
                      popoverContent: Container(
                        width: 300,
                        padding: const EdgeInsets.all(12),
                        child: HtmlWidget(
                          channel.description!,
                          onTapUrl: (url) => launchUrl(Uri.parse(url)),
                          textStyle: theme.textTheme.small,
                        ),
                      ),
                      icon: Icon(LucideIcons.info,
                          size: 14, color: theme.colorScheme.mutedForeground),
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
    final isTalking = widget.talkingUsers[u.session as int] ?? false;
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

    return GestureDetector(
      onTapDown: (_) => _selectUser(u),
      onTap: () {},
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredUserSession = u.session as int),
        onExit: (_) => setState(() => _hoveredUserSession = null),
        child: Container(
          margin: EdgeInsets.only(
            left: 48.0 + 8.0 + (depth * 16.0),
            right: 16,
            top: 1,
            bottom: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : isHovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
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
              if (u.comment != null && u.comment!.isNotEmpty) ...[
                const SizedBox(width: 4),
                _PopoverButton(
                  popoverContent: Container(
                    width: 300,
                    padding: const EdgeInsets.all(12),
                    child: HtmlWidget(
                      u.comment!,
                      onTapUrl: (url) => launchUrl(Uri.parse(url)),
                      textStyle: theme.textTheme.small,
                    ),
                  ),
                  icon: Icon(LucideIcons.messageSquare,
                      size: 14, color: theme.colorScheme.mutedForeground),
                ),
              ],
              if (isMuted || isSuppressed) ...[
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.micOff,
                  size: 14,
                  color: (isMuted || isSuppressed)
                      ? theme.colorScheme.destructive.withValues(alpha: 0.7)
                      : theme.colorScheme.foreground.withValues(alpha: 0.4),
                ),
              ],
              if (isDeaf) ...[
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.headphones,
                  size: 14,
                  color: theme.colorScheme.foreground.withValues(alpha: 0.4),
                ),
              ],
            ],
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

class _PopoverButton extends StatefulWidget {
  final Widget icon;
  final Widget popoverContent;

  const _PopoverButton({
    required this.icon,
    required this.popoverContent,
  });

  @override
  State<_PopoverButton> createState() => _PopoverButtonState();
}

class _PopoverButtonState extends State<_PopoverButton> {
  final _controller = ShadPopoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadPopover(
      controller: _controller,
      popover: (context) => widget.popoverContent,
      child: ShadButton.ghost(
        padding: EdgeInsets.zero,
        width: 20,
        height: 20,
        onPressed: _controller.toggle,
        child: widget.icon,
      ),
    );
  }
}

