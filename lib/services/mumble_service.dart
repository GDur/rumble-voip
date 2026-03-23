import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rumble/models/chat_message.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/models/certificate.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:rumble/src/rust/frb_generated.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/utils/html_utils.dart';

class MumbleService extends ChangeNotifier {
  final RustMumbleClient _client = RustMumbleClient();
  bool _isConnected = false;
  String? _error;
  List<MumbleChannel> _channels = [];
  Map<int, MumbleUser> _users = {};
  bool _isTalking = false;

  final Map<int, bool> _talkingUsers = {};
  double _currentVolume = 0.0;
  final List<ChatMessage> _messages = [];
  String? _pttErrorMessage;
  List<String> _inputDevices = [];
  List<String> _outputDevices = [];
  SettingsService? _settings;

  bool get isConnected => _isConnected;
  String? get error => _error;
  List<MumbleChannel> get channels => _channels;
  bool get isTalking => _isTalking;
  double get currentVolume => _currentVolume;
  Map<int, bool> get talkingUsers => _talkingUsers;
  List<MumbleUser> get users => _users.values.toList();
  List<String> get inputDevices => _inputDevices;
  List<String> get outputDevices => _outputDevices;
  String? get pttErrorMessage => _pttErrorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool get isSuppressed => _users[_selfSession]?.isSuppressed ?? false;
  bool get isMuted => _users[_selfSession]?.isMuted ?? false;
  bool get isDeafened => _users[_selfSession]?.isDeafened ?? false;
  bool get hasMicPermission => true; 
  MumbleUser? get self => _selfSession != null ? _users[_selfSession] : null;

  String get currentChannelName {
    final s = self;
    if (s == null) return 'Not Connected';
    final channel = _channels.cast<MumbleChannel?>().firstWhere(
          (c) => c?.id == s.channelId,
          orElse: () => null,
        );
    return channel?.name ?? 'Unknown Channel';
  }

  StreamSubscription<MumbleEvent>? _eventSubscription;
  int? _selfSession;
  int? get currentSelfSession => _selfSession;

  MumbleService() {
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    try {
      _inputDevices = await listAudioInputDevices();
      _outputDevices = await listAudioOutputDevices();
      notifyListeners();
    } catch (e) {
      debugPrint('[MumbleService] Error listing devices: $e');
    }
  }

  void clearPttErrorMessage() {
    if (_pttErrorMessage != null) {
      _pttErrorMessage = null;
      notifyListeners();
    }
  }

  Future<void> initialize(
    SettingsService settings,
    double inputGain,
    double outputVolume,
    String? inputId,
    String? outputId,
  ) async {
    _settings = settings;
    await _refreshDevices();
    // In Rust-based plugin, we might need to pass these settings to Rust eventually
    // For now, we just store them.
  }

  Future<void> updateAudioSettings({
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
  }) async {
    // Rust-based plugin handles these internally or via future API calls
    notifyListeners();
  }

  Future<void> refreshInputDevices() => _refreshDevices();
  Future<void> refreshOutputDevices() => _refreshDevices();

  Future<void> connect(MumbleServer server, {MumbleCertificate? certificate}) async {
    _error = null;
    _channels = [];
    _users.clear();
    _talkingUsers.clear();
    _messages.clear();
    _selfSession = null;
    notifyListeners();

    try {
      final events = await _client.connect(
        host: server.host,
        port: server.port,
        username: server.username,
        password: server.password.isEmpty ? null : server.password,
      );
      
      _eventSubscription = events.listen(_handleEvent, onError: (e) {
        _error = e.toString();
        _isConnected = false;
        notifyListeners();
      });

    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _handleEvent(MumbleEvent event) {
    if (event is MumbleEvent_Connected) {
      _isConnected = true;
      _selfSession = event.field0;
      _addSystemMessage('Connected.');
    } else if (event is MumbleEvent_Disconnected) {
      _isConnected = false;
      _error = event.field0;
      _addSystemMessage('Disconnected: ${event.field0}');
    } else if (event is MumbleEvent_ChannelUpdate) {
      final channel = event.field0;
      _channels.removeWhere((c) => c.id == channel.id);
      _channels.add(channel);
    } else if (event is MumbleEvent_UserUpdate) {
      final user = event.field0;
      final existing = _users[user.session];
      if (existing != null) {
        final updatedUser = MumbleUser(
          session: user.session,
          name: user.name.isEmpty ? existing.name : user.name,
          channelId: user.channelId == 0 ? existing.channelId : user.channelId,
          isTalking: user.isTalking,
          isMuted: user.isMuted,
          isDeafened: user.isDeafened,
          isSuppressed: user.isSuppressed,
          comment: user.comment ?? existing.comment,
        );
        _users[user.session] = updatedUser;
      } else {
        _users[user.session] = user;
      }
      _talkingUsers[user.session] = _users[user.session]!.isTalking;
    } else if (event is MumbleEvent_UserTalking) {
      final session = event.field0;
      final isTalking = event.field1;
      _talkingUsers[session] = isTalking;
      final user = _users[session];
      if (user != null) {
        _users[session] = MumbleUser(
          session: user.session,
          name: user.name,
          channelId: user.channelId,
          isTalking: isTalking,
          isMuted: user.isMuted,
          isDeafened: user.isDeafened,
          isSuppressed: user.isSuppressed,
          comment: user.comment,
        );
      }
    } else if (event is MumbleEvent_UserRemoved) {
      final session = event.field0;
      _users.remove(session);
      _talkingUsers.remove(session);
    } else if (event is MumbleEvent_TextMessage) {
      final tm = event.field0;
      _messages.add(
        ChatMessage(
          senderName: tm.senderName,
          content: HtmlUtils.sanitizeMumbleHtml(tm.message),
          timestamp: DateTime.now(),
          isSelf: false, 
        ),
      );
    } else if (event is MumbleEvent_AudioVolume) {
      _currentVolume = event.field0;
    }
    notifyListeners();
  }

  void _addSystemMessage(String text, {String senderName = 'System'}) {
    _messages.add(
      ChatMessage(
        senderName: senderName,
        content: text,
        timestamp: DateTime.now(),
        isSystem: true,
        isSelf: false,
      ),
    );
    notifyListeners();
  }

  void startPushToTalk() {
    _client.setPtt(active: true);
    _isTalking = true;
    if (_selfSession != null) {
      _talkingUsers[_selfSession!] = true;
    }
    notifyListeners();
  }

  void stopPushToTalk() {
    _client.setPtt(active: false);
    _isTalking = false;
    if (_selfSession != null) {
      _talkingUsers[_selfSession!] = false;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _client.disconnect();
    _eventSubscription?.cancel();
    _isConnected = false;
    _channels = [];
    _users.clear();
    _messages.clear();
    _talkingUsers.clear();
    _selfSession = null;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (text.isNotEmpty) {
      _client.sendTextMessage(message: text);
      _messages.add(
        ChatMessage(
          senderName: self?.name ?? 'Me',
          content: HtmlUtils.sanitizeMumbleHtml(text),
          timestamp: DateTime.now(),
          isSelf: true,
          sender: self,
        ),
      );
      notifyListeners();
    }
  }

  void toggleMute() {
    final current = isMuted;
    _client.setMute(mute: !current);
  }

  void toggleDeafen() {
    final current = isDeafened;
    _client.setDeafen(deafen: !current);
  }

  Future<void> joinChannel(MumbleChannel channel) async {
    _client.joinChannel(channelId: channel.id);
  }

  Future<void> setUserVolume(MumbleUser user, double volume) async {
    if (_settings != null) {
      await _settings!.setUserVolume(user.name, volume);
      // Rust plugin doesn't support per-user volume in API yet, but we store it in settings
      notifyListeners();
    }
  }

  double getUserVolume(MumbleUser user) {
    if (_settings != null) {
      return _settings!.getUserVolume(user.name);
    }
    return 1.0;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
