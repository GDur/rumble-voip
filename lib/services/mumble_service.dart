import 'dart:async';
import 'package:dumble/dumble.dart';
import 'package:flutter/foundation.dart';
import 'package:rumble/models/server.dart';

class MumbleService extends ChangeNotifier with MumbleClientListener, ChannelListener, UserListener {
  MumbleClient? _client;
  bool _isConnected = false;
  String? _error;
  List<Channel> _channels = [];
  
  MumbleClient? get client => _client;
  bool get isConnected => _isConnected;
  String? get error => _error;
  List<Channel> get channels => _channels;

  Future<void> connect(MumbleServer server) async {
    _error = null;
    _channels = [];
    notifyListeners();

    try {
      debugPrint('[MumbleService] Connecting to ${server.host}:${server.port}...');
      _client = await MumbleClient.connect(
        options: ConnectionOptions(
          host: server.host,
          port: server.port,
          name: server.username,
          password: server.password.isEmpty ? null : server.password,
        ),
        onBadCertificate: (cert) => true,
      );

      _client?.add(this as MumbleClientListener);
      
      // Add user listener to self to track channel changes
      _client?.self.add(this as UserListener);
      
      // Initialize channels
      _updateChannelsInternal();
      
      _isConnected = true;
      notifyListeners();
      debugPrint('[MumbleService] Connected and initial sync done.');
    } catch (e) {
      debugPrint('[MumbleService] Connection error: $e');
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _updateChannelsInternal() {
    if (_client != null) {
      final currentChannels = _client!.getChannels().values.toList();
      _channels = currentChannels;
      
      // Ensure we are listening to all channels
      for (final channel in _channels) {
        // dumble helps us adding listeners multiple times doesn't hurt if we use Notifier
        channel.add(this as ChannelListener);
      }
      
      // Also ensure we are listening to all users to update counts
      for (final user in _client!.getUsers().values) {
        user.add(this as UserListener);
      }
      
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _client?.close();
    _client = null;
    _isConnected = false;
    _channels = [];
    notifyListeners();
  }

  @override
  void onChannelAdded(Channel channel) {
    debugPrint('[MumbleService] Channel added: ${channel.name}');
    channel.add(this as ChannelListener);
    _updateChannelsInternal();
  }

  @override
  void onChannelRemoved(Channel channel) {
    debugPrint('[MumbleService] Channel removed: ${channel.name}');
    _updateChannelsInternal();
  }

  @override
  void onChannelChanged(Channel channel, ChannelChanges changes) {
    _updateChannelsInternal();
  }

  @override
  void onUserAdded(User user) {
    debugPrint('[MumbleService] User added: ${user.name}');
    user.add(this as UserListener);
    notifyListeners();
  }

  @override
  void onUserChanged(User user, User? actor, UserChanges changes) {
    notifyListeners();
  }

  @override
  void onUserRemoved(User user, User? actor, String? reason, bool? ban) {
    notifyListeners();
  }

  @override
  void onTextMessage(IncomingTextMessage message) {}

  @override
  void onBanListReceived(List<BanEntry> bans) {}

  @override
  void onQueryUsersResult(Map<int, String> idToName) {}

  @override
  void onUserListReceived(List<RegisteredUser> users) {}

  @override
  void onPermissionDenied(PermissionDeniedException e) {}

  @override
  void onCryptStateChanged() {}

  @override
  void onDropAllChannelPermissions() {}

  @override
  void onChannelPermissionsReceived(Channel channel, Permission permission) {}

  @override
  void onUserStats(User user, UserStats stats) {}

  @override
  void onError(Object error, [StackTrace? stackTrace]) {
    debugPrint('[MumbleService] OnError: $error');
    _error = error.toString();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void onDone() {
    debugPrint('[MumbleService] Connection closed by server.');
    _isConnected = false;
    notifyListeners();
  }
}
