import 'package:flutter/material.dart';
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
    // Root channel is always expanded
    if (channelId == 0) return true;
    
    // If it has users (directly or in descendants), it should be expanded
    // unless the user specifically toggled it (we can decide priority here)
    // The user request says: "as soon as a user is in the folder all parents are expanded"
    // This implies auto-expansion.
    if (_channelsWithUsers.contains(channelId)) return true;

    return _manualToggles.contains(channelId);
  }

  void _toggleChannel(int channelId) {
    if (channelId == 0) return; // Root is not collapsible
    setState(() {
      if (_manualToggles.contains(channelId)) {
        _manualToggles.remove(channelId);
      } else {
        _manualToggles.add(channelId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    // Root channels are those with no parent, OR specifically channel 0
    final rootChannels = widget.channels.where((c) => c.parent == null || c.channelId == 0).toList();
    
    // De-duplicate if needed (though channelId 0 should be the unique root)
    final uniqueRoots = { for (var c in rootChannels) c.channelId : c }.values.toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: uniqueRoots.map((c) => _buildChannelItem(context, c, 0)).toList(),
    );
  }

  Widget _buildChannelItem(BuildContext context, dumble.Channel channel, int depth) {
    final theme = ShadTheme.of(context);
    final subChannels = widget.channels.where((c) => c.parent?.channelId == channel.channelId).toList();
    
    // Get users in this channel
    final usersInChannel = widget.users.where((u) => u.channel.channelId == channel.channelId).toList();
    if (widget.self != null && widget.self!.channel.channelId == channel.channelId) {
      if (!usersInChannel.any((u) => u.session == widget.self!.session)) {
        usersInChannel.add(widget.self!);
      }
    }
    
    int userCount = usersInChannel.length;
    final bool isMyChannel = widget.self?.channel.channelId == channel.channelId;
    final bool expanded = _isExpanded(channel.channelId);
    final bool hasChildren = subChannels.isNotEmpty || usersInChannel.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            widget.onChannelTap(channel);
            // If it's a folder, maybe we also want to toggle it on tap?
            // The user didn't specify, but usually clicking the name joins, 
            // and clicking icons toggles. Let's see.
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: isMyChannel 
                ? theme.colorScheme.primary.withValues(alpha: 0.05) 
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
                    child: SizedBox(
                      width: 20,
                      child: hasChildren && channel.channelId != 0
                        ? Icon(
                            expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                            size: 16,
                            color: isMyChannel 
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
                              color: isMyChannel ? Colors.white : Colors.white.withValues(alpha: 0.8),
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
        if (expanded) ...[
          // List users in this channel
          ...usersInChannel.map((u) {
            final isTalking = widget.talkingUsers[u.session] ?? false;
            final bool isMe = widget.self?.session == u.session;

            return Padding(
              padding: EdgeInsets.only(
                left: 28.0 + (depth * 20.0) + 20.0,
                right: 16.0,
                top: 4.0,
                bottom: 4.0,
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
                        color: isTalking ? Colors.white : Colors.white60,
                        fontWeight: isTalking || isMe ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Recursively build children
          ...subChannels.map((c) => _buildChannelItem(context, c, depth + 1)),
        ],
      ],
    );
  }
}

