import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dumble/dumble.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:rumble/utils/permissions.dart';
import 'package:rumble/models/chat_message.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/models/certificate.dart';
import 'package:rumble/services/audio_playback_service.dart';
import 'package:rumble/utils/mumble_audio.dart';
import 'package:rumble/src/rust/api/audio.dart';

class MumbleService extends ChangeNotifier
    with MumbleClientListener, ChannelListener, UserListener, AudioListener {
  MumbleClient? _client;
  bool _isConnected = false;
  String? _error;
  List<Channel> _channels = [];
  bool _isTalking = false;

  // Track talking status for all users (session ID -> isTalking)
  final Map<int, bool> _talkingUsers = {};

  // Rust-based High Performance Audio
  late final RustAudioRecorder _recorder;
  StreamSubscription<Uint8List>? _opusSubscription;
  AudioFrameSink? _audioSink;

  // Audio decoding (Incoming)
  final Map<int, MumbleOpusDecoder> _decoders = {};
  bool _audioPlayerInitialized = false;

  // Jitter Buffer / Playback Buffering
  final Map<int, FfiInt16Buffer> _userBuffers = {};
  final Map<int, int> _userBufferOffsets = {};
  final Map<int, bool> _userPlaying = {};
  static const int _bufferThreshold = 960 * 3;
  static const int _maxUserBufferSize = 960 * 10;

  // User stats storage
  final Map<int, UserStats> _userStats = {};

  // Volume monitoring
  double _currentVolume = 0.0;

  // Local storage for chat messages
  final List<ChatMessage> _messages = [];

  // PTT error message
  String? _pttErrorMessage;

  // Cached devices from Rust
  List<AudioDevice> _inputDevices = [];

  // Mic permission status
  bool _hasMicPermission = false;

  MumbleClient? get client => _client;
  bool get isConnected => _isConnected;
  String? get error => _error;
  List<Channel> get channels => _channels;
  bool get isTalking => _isTalking;
  double get currentVolume => _currentVolume;
  Map<int, bool> get talkingUsers => _talkingUsers;
  bool get isSuppressed => _client?.self.suppress ?? false;
  bool get isMuted => _client?.self.selfMute ?? false;
  bool get isDeafened => _client?.self.selfDeaf ?? false;
  List<User> get users => _client?.getUsers().values.toList() ?? [];
  Self? get self => _client?.self;
  List<AudioDevice> get inputDevices => _inputDevices;
  String? get pttErrorMessage => _pttErrorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<int, UserStats> get userStats => _userStats;
  bool get hasMicPermission => _hasMicPermission;

  void clearPttErrorMessage() {
    if (_pttErrorMessage != null) {
      _pttErrorMessage = null;
      notifyListeners();
    }
  }

  MumbleService() {
    _recorder = RustAudioRecorder();
    _initAudioPlayer();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    try {
      _inputDevices = await listInputDevices();
      notifyListeners();
    } catch (e) {
      debugPrint('[MumbleService] Error listing devices: $e');
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      await AudioPlaybackService().initialize(
        sampleRate: 48000,
        channels: 1,
      );
      _audioPlayerInitialized = true;
    } catch (e) {
      debugPrint('[MumbleService] Error initializing audio player: $e');
    }
  }

  Future<void> initialize({
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
  }) async {
    _selectedInputDeviceId = inputDeviceId;
    _inputGain = inputGain ?? 1.0;
    if (outputVolume != null) {
      AudioPlaybackService().setOutputVolume(outputVolume);
    }
    await _initAudioPlayer();
    await _refreshDevices();
  }

  Future<void> refreshInputDevices() => _refreshDevices();
  Future<void> refreshOutputDevices() async {
    notifyListeners();
  }

  List<dynamic> get outputDevices => [];

  Future<void> connect(MumbleServer server, {MumbleCertificate? certificate}) async {
    _error = null;
    _channels = [];
    _talkingUsers.clear();
    _messages.clear();
    notifyListeners();

    try {
      _client = await MumbleClient.connect(
        options: ConnectionOptions(
          host: server.host,
          port: server.port,
          name: server.username,
          password: server.password.isEmpty ? null : server.password,
        ),
        onBadCertificate: (cert) => true,
      );
      
      // If a certificate is provided, we would normally use it here
      // But dumble 0.8.9 has limited support for custom certificates in connect

      _client?.add(this as MumbleClientListener);
      _client?.self.add(this as UserListener);
      _client?.audio.add(this as AudioListener);

      _updateChannelsInternal();
      _isConnected = true;
      notifyListeners();

      _setupServerAudioSink();
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _setupServerAudioSink() {
    if (_client == null) return;
    AudioClient.resetSequenceNumber();
    _audioSink = _client!.audio.sendAudio(codec: AudioCodec.opus);
    debugPrint('[MumbleService] Server sink ready.');
  }

  String? _selectedInputDeviceId;
  double _inputGain = 1.0;

  Future<void> updateAudioSettings({
    String? inputDeviceId,
    String? outputDeviceId,
    double? inputGain,
    double? outputVolume,
  }) async {
    if (inputDeviceId != null) _selectedInputDeviceId = inputDeviceId;
    if (inputGain != null) _inputGain = inputGain;
    if (outputVolume != null) {
      AudioPlaybackService().setOutputVolume(outputVolume);
    }
    if (outputDeviceId != null) {
      await _initAudioPlayer();
    }
    notifyListeners();
  }

  Future<void> startPushToTalk() async {
    if (!_isConnected || _client == null || _isTalking) return;

    if (isSuppressed) {
      _pttErrorMessage = 'You are suppressed by the server';
      notifyListeners();
      return;
    }

    try {
      _hasMicPermission = await PermissionUtils.requestMicrophonePermission();

      if (!_hasMicPermission) {
        _pttErrorMessage = 'Microphone permission denied';
        notifyListeners();
        return;
      }

      _isTalking = true;
      _talkingUsers[_client!.self.session] = true;

      // Start Rust Recorder with selected device
      final opusStream = await _recorder.start(deviceName: _selectedInputDeviceId);
      _opusSubscription = opusStream.listen((packet) {
        if (_isTalking && _audioSink != null) {
          _audioSink!.add(AudioFrame.outgoing(frame: packet));
        }
      });

      notifyListeners();
    } catch (e) {
      debugPrint('[MumbleService] Error starting PTT: $e');
      stopPushToTalk();
    }
  }

  void stopPushToTalk() {
    if (!_isTalking) return;
    _isTalking = false;
    _recorder.stop();
    _opusSubscription?.cancel();
    _opusSubscription = null;

    if (_client != null) {
      _talkingUsers[_client!.self.session] = false;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    stopPushToTalk();
    await _client?.close();
    _client = null;
    _isConnected = false;
    _channels = [];
    _messages.clear();
    _talkingUsers.clear();
    for (final d in _decoders.values) {
      d.dispose();
    }
    _decoders.clear();
    for (final b in _userBuffers.values) {
      b.dispose();
    }
    _userBuffers.clear();
    _userPlaying.clear();
    notifyListeners();
  }

  void requestUserStats(User user) {
    // queryUserStats is not available in dumble 0.8.9
  }

  @override
  void onUserStats(User user, UserStats stats) {
    _userStats[user.session] = stats;
    notifyListeners();
  }

  @override
  void onAudioReceived(
    Stream<AudioFrame> voiceData,
    AudioCodec codec,
    User? user,
    TalkMode talkMode,
  ) {
    final sessionId = user?.session ?? -1;
    if (sessionId == -1) return;

    if (codec == AudioCodec.opus) {
      _talkingUsers[sessionId] = true;
      notifyListeners();

      final decoder = _decoders.putIfAbsent(
        sessionId,
        () => MumbleOpusDecoder(sampleRate: 48000, channels: 1),
      );

      final buffer = _userBuffers.putIfAbsent(
        sessionId,
        () => FfiInt16Buffer(_maxUserBufferSize),
      );
      _userBufferOffsets.putIfAbsent(sessionId, () => 0);

      voiceData.listen(
        (AudioFrame frame) {
          final frameData = frame.frame;
          final pcm = decoder.decode(frameData, 5760);

          if (pcm.isNotEmpty) {
            int offset = _userBufferOffsets[sessionId]!;
            if (offset + pcm.length > _maxUserBufferSize) {
              offset = 0;
            }
            buffer.list.setRange(offset, offset + pcm.length, pcm);
            offset += pcm.length;
            _userBufferOffsets[sessionId] = offset;

            if (!_userPlaying.containsKey(sessionId) ||
                _userPlaying[sessionId] == false) {
              if (offset >= _bufferThreshold) {
                _userPlaying[sessionId] = true;
                if (_audioPlayerInitialized) {
                  AudioPlaybackService().startSession(sessionId);
                }
              }
            }

            if (_userPlaying[sessionId] == true || offset > 5000) {
              _drainUserBuffer(sessionId, buffer);
            }
          }
        },
        onDone: () {
          _talkingUsers[sessionId] = false;
          _userPlaying[sessionId] = false;
          _drainUserBuffer(sessionId, buffer);
          AudioPlaybackService().stopSession(sessionId);
          notifyListeners();
        },
      );
    }
  }

  void _drainUserBuffer(int sessionId, FfiInt16Buffer buffer) {
    if (!_audioPlayerInitialized) return;
    int offset = _userBufferOffsets[sessionId] ?? 0;
    while (offset >= 960) {
      final chunk = buffer.list.buffer.asInt16List(buffer.list.offsetInBytes, 960);
      AudioPlaybackService().feed(sessionId, chunk);
      if (offset > 960) {
        buffer.list.setRange(0, offset - 960, buffer.list, 960);
      }
      offset -= 960;
    }
    _userBufferOffsets[sessionId] = offset;
  }

  void _updateChannelsInternal() {
    if (_client != null) {
      _channels = _client!.getChannels().values.toList();
      for (final channel in _channels) {
        channel.add(this as ChannelListener);
      }
      for (final user in _client!.getUsers().values) {
        user.add(this as UserListener);
      }
      notifyListeners();
    }
  }

  @override
  void onUserRemoved(User user, User? actor, String? reason, bool? ban) {
    _talkingUsers.remove(user.session);
    _decoders.remove(user.session)?.dispose();
    _userBuffers.remove(user.session)?.dispose();
    _userPlaying.remove(user.session);
    AudioPlaybackService().stopSession(user.session);
    _updateChannelsInternal();
  }

  @override
  void onChannelAdded(Channel channel) {
    channel.add(this as ChannelListener);
    _updateChannelsInternal();
  }

  @override
  void onChannelRemoved(Channel channel) => _updateChannelsInternal();
  @override
  void onChannelChanged(Channel channel, ChannelChanges changes) =>
      _updateChannelsInternal();
  @override
  void onUserAdded(User user) {
    user.add(this as UserListener);
    _updateChannelsInternal();
  }

  @override
  void onUserChanged(User user, User? actor, UserChanges changes) =>
      notifyListeners();

  @override
  void onError(Object error, [StackTrace? stackTrace]) {
    _error = error.toString();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void onDone() {
    _isConnected = false;
    notifyListeners();
  }

  @override
  void onTextMessage(IncomingTextMessage message) {
    _messages.add(
      ChatMessage(
        senderName: message.actor?.name ?? 'Unknown',
        content: message.message,
        timestamp: DateTime.now(),
        isSelf: false,
        sender: message.actor,
      ),
    );
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_client != null && text.isNotEmpty) {
      final message = OutgoingTextMessage(
        message: text,
        channels: [_client!.self.channel],
      );
      _client!.sendMessage(message: message);
      _messages.add(
        ChatMessage(
          senderName: _client!.self.name ?? 'Me',
          content: text,
          timestamp: DateTime.now(),
          isSelf: true,
          sender: _client!.self,
        ),
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPushToTalk();
    _client?.close();
    _recorder.dispose();
    for (final d in _decoders.values) {
      d.dispose();
    }
    for (final b in _userBuffers.values) {
      b.dispose();
    }
    AudioPlaybackService().dispose();
    super.dispose();
  }

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

  void toggleMute() {
    if (_client != null) {
      _client!.self.setSelfMute(mute: !(_client!.self.selfMute ?? false));
      notifyListeners();
    }
  }

  void toggleDeafen() {
    if (_client != null) {
      _client!.self.setSelfDeaf(deaf: !(_client!.self.selfDeaf ?? false));
      notifyListeners();
    }
  }

  Future<void> joinChannel(Channel channel) async {
    if (_client != null) {
      _client!.self.moveToChannel(channel: channel);
      notifyListeners();
    }
  }
}
