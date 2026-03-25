import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rumble/models/chat_message.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/models/certificate.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:rumble/src/rust/mumble/types.dart';
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
  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.0);
  List<ChatMessage> _messages = [];
  String? _pttErrorMessage;
  List<AudioDevice> _inputDevices = [];
  List<AudioDevice> _outputDevices = [];
  SettingsService? _settings;
  MumbleConfig _config = const MumbleConfig(
    audioBitrate: 72000,
    audioFrameMs: 10,
    opusComplexity: 10,
    jitterBufferMs: 40,
    outputBufferSize: AudioBufferSize.default_(),
    inputBufferSize: AudioBufferSize.default_(),
  );

  bool get isConnected => _isConnected;
  String? get error => _error;
  List<MumbleChannel> get channels => _channels;
  bool get isTalking => _selfSession != null && (_talkingUsers[_selfSession!] ?? false);
  double get currentVolume => volumeNotifier.value;
  Map<int, bool> get talkingUsers => _talkingUsers;
  List<MumbleUser> get users => _users.values.toList();
  List<AudioDevice> get inputDevices => _inputDevices;
  List<AudioDevice> get outputDevices => _outputDevices;
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
    _config = MumbleConfig(
      audioBitrate: 72000,
      audioFrameMs: 10,
      opusComplexity: 10,
      jitterBufferMs: 40,
      outputBufferSize: const AudioBufferSize.default_(),
      inputBufferSize: const AudioBufferSize.default_(),
      inputDeviceId: inputId,
      outputDeviceId: outputId,
    );
    _client.setConfig(config: _config);
    await _refreshDevices();
  }

  Future<void> setInputDevice(String? deviceId) async {
    _config = MumbleConfig(
      audioBitrate: _config.audioBitrate,
      audioFrameMs: _config.audioFrameMs,
      opusComplexity: _config.opusComplexity,
      jitterBufferMs: _config.jitterBufferMs,
      outputBufferSize: _config.outputBufferSize,
      inputBufferSize: _config.inputBufferSize,
      inputDeviceId: deviceId,
      outputDeviceId: _config.outputDeviceId,
    );
    await _client.setConfig(config: _config);
    if (_settings != null) {
      await _settings!.setInputDeviceId(deviceId);
    }
    notifyListeners();
  }

  Future<void> setOutputDevice(String? deviceId) async {
    _config = MumbleConfig(
      audioBitrate: _config.audioBitrate,
      audioFrameMs: _config.audioFrameMs,
      opusComplexity: _config.opusComplexity,
      jitterBufferMs: _config.jitterBufferMs,
      outputBufferSize: _config.outputBufferSize,
      inputBufferSize: _config.inputBufferSize,
      inputDeviceId: _config.inputDeviceId,
      outputDeviceId: deviceId,
    );
    await _client.setConfig(config: _config);
    if (_settings != null) {
      await _settings!.setOutputDeviceId(deviceId);
    }
    notifyListeners();
  }

  Future<void> updateAudioSettings({
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
  }) async {
    if (inputDeviceId != null) {
      await setInputDevice(inputDeviceId);
    }
    if (outputDeviceId != null) {
      await setOutputDevice(outputDeviceId);
    }
    if (inputGain != null) {
      await _client.setInputGain(gain: inputGain);
    }
    if (outputVolume != null) {
      await _client.setOutputVolume(volume: outputVolume);
    }
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
      _eventSubscription?.cancel();
      _eventSubscription = _client.getEventStream().listen(_handleEvent, onError: (e) {
        _error = e.toString();
        _isConnected = false;
        notifyListeners();
      });

      await _client.connect(
        host: server.host,
        port: server.port,
        username: server.username,
        password: server.password.isEmpty ? null : server.password,
      );
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

      // Apply audio settings upon connection
      if (_settings != null) {
        _client.setInputGain(gain: _settings!.inputGain);
        _client.setOutputVolume(volume: _settings!.outputVolume);
      }
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

      // If it's a new user with a name, apply their saved volume
      if (existing == null && user.name.isNotEmpty) {
        final savedVolume = getUserVolume(user);
        if (savedVolume != 1.0) {
          _client.setUserVolume(sessionId: user.session, volume: savedVolume);
        }
      }

      if (existing != null) {
        // If the name was previously empty and now we have it, apply saved volume
        if (existing.name.isEmpty && user.name.isNotEmpty) {
          final savedVolume = _settings?.getUserVolume(user.name) ?? 1.0;
          if (savedVolume != 1.0) {
            _client.setUserVolume(sessionId: user.session, volume: savedVolume);
          }
        }

        final updatedUser = MumbleUser(
          session: user.session,
          name: user.name.isEmpty ? existing.name : user.name,
          channelId: user.channelId,
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
      volumeNotifier.value = event.field0;
      return; // Early return to NOT trigger notifyListeners() for the entire service
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
      await _client.setUserVolume(sessionId: user.session, volume: volume);
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
