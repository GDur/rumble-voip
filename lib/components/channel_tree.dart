import 'package:flutter/material.dart';
import 'package:dumble/dumble.dart' as dumble;
import 'package:shadcn_ui/shadcn_ui.dart';

class ChannelTree extends StatelessWidget {
  final List<dumble.Channel> channels;
  final List<dumble.User> users;
  final dumble.Self? self;
  final Function(dumble.Channel) onChannelTap;

  const ChannelTree({
    super.key,
    required this.channels,
    required this.users,
    this.self,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    // Root channels are those with no parent, OR specifically channel 0
    final rootChannels = channels.where((c) => c.parent == null || c.channelId == 0).toList();
    
    // De-duplicate if needed (though channelId 0 should be the unique root)
    final uniqueRoots = { for (var c in rootChannels) c.channelId : c }.values.toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: uniqueRoots.map((c) => _buildChannelItem(context, c, 0)).toList(),
    );
  }

  Widget _buildChannelItem(BuildContext context, dumble.Channel channel, int depth) {
    final theme = ShadTheme.of(context);
    final subChannels = channels.where((c) => c.parent?.channelId == channel.channelId).toList();
    
    // Count users in this channel
    int userCount = users.where((u) => u.channel.channelId == channel.channelId).length;
    if (self != null && self!.channel.channelId == channel.channelId) {
      userCount++;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChannelTap(channel),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 + (depth * 20.0),
              right: 16.0,
              top: 8.0,
              bottom: 8.0,
            ),
            child: Row(
              children: [
                Icon(
                  subChannels.isNotEmpty ? Icons.folder_open : Icons.folder_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    channel.name ?? 'Channel ${channel.channelId}',
                    style: theme.textTheme.list,
                  ),
                ),
                if (userCount > 0)
                   ShadBadge.secondary(
                    child: Text('$userCount'),
                  ),
              ],
            ),
          ),
        ),
        // Recursively build children
        ...subChannels.map((c) => _buildChannelItem(context, c, depth + 1)),
      ],
    );
  }
}
