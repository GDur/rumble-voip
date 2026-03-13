import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dumble/dumble.dart' as dumble;
import 'package:shadcn_ui/shadcn_ui.dart';

class ChannelTree extends StatefulWidget {
  final List<dumble.Channel> channels;
  final List<dumble.User> users;
  final Map<int, bool> talkingUsers;
  final dumble.Self? self;
  final Function(dumble.Channel) onChannelTap;

  const ChannelTree({
    super.key,
    required this.channels,
    required this.users,
    required this.talkingUsers,
    this.self,
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
    
    void addPath(dumble.Channel? channel) {
      dumble.Channel? current = channel;
      while (current != null) {
        result.add(current.channelId);
        current = current.parent;
      }
    }

    for (final user in widget.users) {
      addPath(user.channel);
    }
    
    if (widget.self != null) {
      addPath(widget.self!.channel);
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

  void _onEnterChannel(dumble.Channel channel) {
    widget.onChannelTap(channel);
  }

  void _selectChannel(dumble.Channel channel) {
    setState(() {
      _selectedChannelId = channel.channelId;
      _selectedUserSession = null;
    });
  }

  void _selectUser(dumble.User user) {
    setState(() {
      _selectedUserSession = user.session;
      _selectedChannelId = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    final rootChannels = widget.channels.where((c) => c.parent == null || c.channelId == 0).toList();
    final uniqueRoots = { for (var c in rootChannels) c.channelId : c }.values.toList();
    
    // Sort root channels
    uniqueRoots.sort((a, b) {
      if (a.position != b.position) {
        return (a.position ?? 0).compareTo(b.position ?? 0);
      }
      return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
    });

    _visibleItems.clear();
    _buildVisibleItems(uniqueRoots);

    return FocusableActionDetector(
      autofocus: true,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          if (_selectedChannelId != null) {
            final channel = widget.channels.firstWhere((c) => c.channelId == _selectedChannelId);
            _onEnterChannel(channel);
          }
          return null;
        }),
        DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(onInvoke: (intent) {
          _handleNavigation(intent.direction);
          return null;
        }),
      },
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        physics: const BouncingScrollPhysics(),
        children: uniqueRoots.map((c) => _buildChannelItem(context, c, 0)).toList(),
      ),
    );
  }

  void _buildVisibleItems(List<dumble.Channel> currentChannels) {
    for (var channel in currentChannels) {
      _visibleItems.add(channel);
      if (_isExpanded(channel.channelId)) {
        // Add users
        final usersInChannel = widget.users.where((u) => u.channel.channelId == channel.channelId).toList();
        if (widget.self != null && widget.self!.channel.channelId == channel.channelId) {
           if (!usersInChannel.any((u) => u.session == widget.self!.session)) {
             usersInChannel.add(widget.self!);
           }
        }
        
        // Sort users by name
        usersInChannel.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
        
        for (var user in usersInChannel) {
          _visibleItems.add(user);
        }
        
        // Add subchannels
        final subChannels = widget.channels.where((c) => c.parent?.channelId == channel.channelId).toList();
        
        // Sort subchannels
        subChannels.sort((a, b) {
          if (a.position != b.position) {
            return (a.position ?? 0).compareTo(b.position ?? 0);
          }
          return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
        });
        
        _buildVisibleItems(subChannels);
      }
    }
  }

  void _handleNavigation(TraversalDirection direction) {
    if (_visibleItems.isEmpty) return;
    
    int currentIndex = -1;
    if (_selectedChannelId != null) {
      currentIndex = _visibleItems.indexWhere((item) => item is dumble.Channel && item.channelId == _selectedChannelId);
    } else if (_selectedUserSession != null) {
      currentIndex = _visibleItems.indexWhere((item) => item is dumble.User && item.session == _selectedUserSession);
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
      return; // No index change
    } else if (direction == TraversalDirection.left) {
      if (_selectedChannelId != null) {
        if (_isExpanded(_selectedChannelId!)) {
          _toggleChannel(_selectedChannelId!);
        } else {
          // Move selection to parent if not collapsed or already collapsed
          final channel = widget.channels.firstWhere((c) => c.channelId == _selectedChannelId);
          if (channel.parent != null) {
            _selectChannel(channel.parent!);
          }
        }
      } else if (_selectedUserSession != null) {
        // If user is selected, left moves to the channel they are in
        final user = widget.users.firstWhere((u) => u.session == _selectedUserSession, 
            orElse: () => widget.self!);
        _selectChannel(user.channel);
      }
      return; // No index change
    }

    if (currentIndex != -1) {
      final item = _visibleItems[currentIndex];
      if (item is dumble.Channel) {
        _selectChannel(item);
      } else if (item is dumble.User) {
        _selectUser(item);
      }
    }
  }

  Widget _buildChannelItem(BuildContext context, dumble.Channel channel, int depth) {
    final theme = ShadTheme.of(context);
    final subChannels = widget.channels.where((c) => c.parent?.channelId == channel.channelId).toList();
    final usersInChannel = widget.users.where((u) => u.channel.channelId == channel.channelId).toList();
    if (widget.self != null && widget.self!.channel.channelId == channel.channelId) {
      if (!usersInChannel.any((u) => u.session == widget.self!.session)) {
        usersInChannel.add(widget.self!);
      }
    }
    
    // Sort sub-channels by position, then name
    subChannels.sort((a, b) {
      if (a.position != b.position) {
        return (a.position ?? 0).compareTo(b.position ?? 0);
      }
      return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
    });
    
    // Sort users by name
    usersInChannel.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    
    int userCount = usersInChannel.length;
    final bool isMyChannel = widget.self?.channel.channelId == channel.channelId;
    final bool expanded = _isExpanded(channel.channelId);
    final bool hasChildren = subChannels.isNotEmpty || usersInChannel.isNotEmpty;
    final bool isSelected = _selectedChannelId == channel.channelId;
    final bool isHovered = _hoveredChannelId == channel.channelId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredChannelId = channel.channelId),
          onExit: (_) => setState(() => _hoveredChannelId = null),
          child: GestureDetector(
            onTapDown: (_) => _selectChannel(channel),
            onTap: () {
              final isTouch = Theme.of(context).platform == TargetPlatform.iOS || 
                             Theme.of(context).platform == TargetPlatform.android;
              if (isTouch) {
                ShadSonner.of(context).show(
                  const ShadToast(
                    description: Text('Long press to enter channel'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            },
            onDoubleTap: () => _onEnterChannel(channel),
            onLongPress: () => _onEnterChannel(channel),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : isHovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : isMyChannel 
                      ? theme.colorScheme.primary.withValues(alpha: 0.05) 
                      : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : isHovered
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent, // Always have a border to prevent layout shift
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12.0 + (depth * 20.0),
                  right: 12.0,
                  top: 10.0,
                  bottom: 10.0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleChannel(channel.channelId),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 20,
                        child: hasChildren && channel.channelId != 0
                          ? Icon(
                              expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                              size: 16,
                              color: isMyChannel || isSelected
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.foreground.withValues(alpha: 0.4),
                            )
                          : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              channel.name ?? 'Channel ${channel.channelId}',
                              style: theme.textTheme.list.copyWith(
                              fontWeight: isMyChannel ? FontWeight.bold : FontWeight.w500,
                              color: (isMyChannel || isSelected) ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              fontSize: 15,
                              fontFamily: 'Outfit',
                            ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isEnterRestricted == true) ...[
                            const SizedBox(width: 6),
                            Icon(
                              LucideIcons.lock,
                              size: 14,
                              color: theme.colorScheme.foreground.withValues(alpha: 0.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (userCount > 0)
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                           color: theme.colorScheme.primary.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                         ),
                         child: Text(
                           '$userCount',
                           style: TextStyle(
                             color: theme.colorScheme.primary,
                             fontSize: 11,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                  ],
                ),
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

  Widget _buildUserItem(BuildContext context, dumble.User u, int depth) {
    final theme = ShadTheme.of(context);
    final isTalking = widget.talkingUsers[u.session] ?? false;
    final bool isMe = widget.self?.session == u.session;
    final bool isSelected = _selectedUserSession == u.session;
    final bool isHovered = _hoveredUserSession == u.session;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredUserSession = u.session),
      onExit: (_) => setState(() => _hoveredUserSession = null),
      child: GestureDetector(
        onTapDown: (_) => _selectUser(u),
        onTap: () {}, // Handled by onTapDown for instant feel
        child: Container(
          margin: EdgeInsets.only(left: 48.0 + (depth * 20.0), right: 16, top: 2, bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  : Colors.transparent, // Always have a border to prevent layout shift
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
                  color: isTalking ? const Color(0xFF00B4D8) : const Color(0xFF64FFDA).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  boxShadow: isTalking ? [
                    BoxShadow(
                      color: const Color(0xFF00B4D8).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ] : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isMe ? '${u.name} (You)' : (u.name ?? 'Unknown User'),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: (isTalking || isSelected) ? Colors.white : Colors.white60,
                    fontWeight: (isTalking || isMe || isSelected) ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (u.suppress == true) ...[
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.micOff,
                  size: 14,
                  color: theme.colorScheme.destructive.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


