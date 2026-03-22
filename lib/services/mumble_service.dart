import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:dumble/dumble.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:rumble/models/certificate.dart';
import 'package:rumble/models/chat_message.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/audio_playback_service.dart';
import 'package:rumble/utils/mumble_audio.dart';

class MumbleService extends ChangeNotifier
    with MumbleClientListener, ChannelListener, UserListener, AudioListener {
  MumbleClient? _client;
  bool _isConnected = false;
  String? _error;
  List<Channel> _channels = [];
  bool _isTalking = false;
  bool _hasMicPermission = false;
  double _inputGain = 1.0;
  String? _inputDeviceId;
  String? _outputDeviceId;
  String? _pttErrorMessage;

  // Track talking status for all users (session ID -> isTalking)
  final Map<int, bool> _talkingUsers = {};

  // Chat messages
  final List<ChatMessage> _messages = [];

  // Audio recording and encoding (Outgoing)
  late final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _micSubscription;
  Timer? _processingTimer;
  AudioFrameSink? _audioSink;
  MumbleOpusEncoder? _opusEncoder;

  // Audio decoding (Incoming)
  final Map<int, MumbleOpusDecoder> _decoders = {};
  bool _audioPlayerInitialized = false;

  // (Jitter buffer fields moved down near onAudioReceived for clarity)

  // Volume monitoring
  double _currentVolume = 0.0;
  Timer? _volumeTimer;

  // Cached devices
  List<dynamic> _inputDevices = [];
  List<dynamic> _outputDevices = [];

  // Buffer for raw PCM data (Outgoing)
  final List<int> _pcmBuffer = [];

  // User stats storage (session ID -> stats)
  final Map<int, UserStats> _userStats = {};

  void _updateSync() {
    if (client != null) {
      _channels = client!.getChannels().values.toList();
      notifyListeners();
    }
  }

  MumbleClient? get client => _client;
  bool get isConnected => _isConnected;
  String? get error => _error;
  List<Channel> get channels => _channels;
  bool get isTalking => _isTalking;
  double get currentVolume => _currentVolume;
  Map<int, bool> get talkingUsers => _talkingUsers;
  Map<int, UserStats> get userStats => _userStats;
  bool get isSuppressed => _client?.self.suppress ?? false;
  bool get isMuted => _client?.self.selfMute ?? false;
  bool get isDeafened => _client?.self.selfDeaf ?? false;
  List<User> get users => _client?.getUsers().values.toList() ?? [];
  Self? get self => _client?.self;
  bool get hasMicPermission => _hasMicPermission;
  List<dynamic> get inputDevices => _inputDevices;
  List<dynamic> get outputDevices => _outputDevices;
  String? get pttErrorMessage => _pttErrorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void clearPttErrorMessage() {
    if (_pttErrorMessage != null) {
      _pttErrorMessage = null;
      notifyListeners();
    }
  }

  MumbleService() {
    _recorder = AudioRecorder();
  }

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

  void sendMessage(String text) {
    if (_client != null && text.isNotEmpty) {
      final message = OutgoingTextMessage(
        message: text,
        channels: [_client!.self.channel],
      );
      _client!.sendMessage(message: message);

      // Add to our own list since we don't get an onTextMessage for our own messages
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

  void _addSystemMessage(String text, {String senderName = 'System'}) {
    _messages.add(
      ChatMessage(
        senderName: senderName,
        content: text,
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    );
    notifyListeners();
  }

  void requestUserStats(User user) {
    user.requestUserStats();
  }

  // Called from main.dart after settings are ready
  Future<void> initialize(
    double inputGain,
    double outputVolume,
    String? inputId,
    String? outputId,
  ) async {
    _inputGain = inputGain;
    _inputDeviceId = inputId;
    _outputDeviceId = outputId;

    await _initAudioPlayer(outputVolume);
    await _initGlobalAudioResources();

    // Refresh device lists so they are available in the settings UI
    await refreshInputDevices();
    await refreshOutputDevices();
  }

  Future<void> _initGlobalAudioResources() async {
    // 1. Configure Audio Session for the entire app lifetime
    try {
      debugPrint('[MumbleService] Configuring Global Audio Session...');
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        ),
      );
      await session.setActive(true);
      debugPrint('[MumbleService] Global Audio Session configured.');
    } catch (e) {
      debugPrint('[MumbleService] Error configuring Global Audio Session: $e');
    }

    // 2. Pre-initialize the Opus Encoder
    _opusEncoder = MumbleOpusEncoder(
      sampleRate: 48000,
      channels: 1,
      application: opusApplicationVoip,
    );

    // 3. Start passive mic monitoring/streaming immediately (WARM UP)
    _startMicStream();
    _startVolumeMonitoring();

    debugPrint('[MumbleService] Global audio layer is WARM.');
  }

  Future<void> updateAudioSettings({
    double? inputGain,
    double? outputVolume,
    String? inputDeviceId,
    String? outputDeviceId,
  }) async {
    bool restartMic = false;
    bool restartPlayer = false;

    if (inputGain != null) _inputGain = inputGain;
    if (inputDeviceId != _inputDeviceId) {
      debugPrint('[MumbleService] Input device changing to $inputDeviceId');
      _inputDeviceId = inputDeviceId;
      restartMic = true;
    }
    if (outputVolume != null) {
      AudioPlaybackService().setOutputVolume(outputVolume);
    }
    if (outputDeviceId != _outputDeviceId) {
      debugPrint('[MumbleService] Output device changing to $outputDeviceId');
      _outputDeviceId = outputDeviceId;
      restartPlayer = true;
    }

    if (restartMic) {
      await _startMicStream();
    }
    if (restartPlayer) {
      // Re-initialize player with new device
      _audioPlayerInitialized = false;
      await AudioPlaybackService().dispose();
      await _initAudioPlayer(outputVolume ?? 1.0);
    }

    notifyListeners();
  }

  Future<List<dynamic>> getInputDevices() async {
    if (_inputDevices.isNotEmpty) return _inputDevices;
    return refreshInputDevices();
  }

  Future<List<dynamic>> refreshInputDevices() async {
    try {
      final devices = await _recorder.listInputDevices();
      _inputDevices = devices.where((d) {
        final label = d.label.toString().toLowerCase();
        // Ignore internal CoreAudio aggregate devices which aren't real mics
        // And ignore DACs that shouldn't be used as mic sources
        if (label.contains('aggregate') || label.contains('dac')) return false;
        return true;
      }).toList();
      notifyListeners();
      return _inputDevices;
    } catch (e) {
      debugPrint('[MumbleService] Error refreshing devices: $e');
      return [];
    }
  }

  Future<List<dynamic>> getOutputDevices() async {
    if (_outputDevices.isNotEmpty) return _outputDevices;
    return refreshOutputDevices();
  }

  Future<List<dynamic>> refreshOutputDevices() async {
    try {
      final devices = await AudioPlaybackService().getOutputDevices();
      _outputDevices = devices.where((d) {
        final name = d.name.toString().toLowerCase();
        // Ignore internal CoreAudio aggregate devices and DACs
        if (name.contains('aggregate') || name.contains('dac')) return false;
        return true;
      }).toList();
      notifyListeners();
      return _outputDevices;
    } catch (e) {
      debugPrint('[MumbleService] Error refreshing output devices: $e');
      return [];
    }
  }

  Future<void> _initAudioPlayer(double volume) async {
    try {
      debugPrint('[MumbleService] Initializing audio service...');
      await AudioPlaybackService().initialize(
        sampleRate: 48000,
        channels: 1,
        volume: volume,
        deviceId: _outputDeviceId,
      );
      _audioPlayerInitialized = true;
      debugPrint('[MumbleService] Audio service initialized.');
    } catch (e) {
      debugPrint('[MumbleService] Error initializing audio service: $e');
    }
  }

  void _startVolumeMonitoring() {
    if (_volumeTimer?.isActive ?? false) return;

    debugPrint('[MumbleService] Starting volume monitoring...');
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) async {
      try {
        if (await _recorder.isRecording()) {
          final amplitude = await _recorder.getAmplitude();
          if (amplitude.current <= -100) {
            _currentVolume = 0.0;
          } else {
            // Range -50dB to 0dB
            double v = (amplitude.current + 50) / 50;
            _currentVolume = v.clamp(0.01, 1.0);
          }
          notifyListeners();
        } else {
          if (_currentVolume > 0) {
            _currentVolume = 0;
            notifyListeners();
          }
        }
      } catch (e) {
        // Silent fail
      }
    });
  }

  Future<void> connect(
    MumbleServer server, {
    MumbleCertificate? certificate,
  }) async {
    _isConnected = false;
    _error = null;
    _channels = [];
    _talkingUsers.clear();
    notifyListeners();

    _addSystemMessage('Welcome to Rumble.');
    _addSystemMessage('Connecting to server ${server.host}:${server.port}.');

    try {
      debugPrint(
        '[MumbleService] Connecting to ${server.host}:${server.port}...',
      );

      SecurityContext? context;
      if (certificate != null) {
        context = SecurityContext();
        final certBytes = utf8.encode(certificate.certificatePem);
        final keyBytes = utf8.encode(certificate.privateKeyPem);
        context.useCertificateChainBytes(certBytes);
        context.usePrivateKeyBytes(keyBytes);
      }

      _client = await MumbleClient.connect(
        options: ConnectionOptions(
          host: server.host,
          port: server.port,
          name: server.username,
          password: server.password.isEmpty ? null : server.password,
          context: context,
        ),
        onBadCertificate: (cert) => true,
      );

      _client?.add(this as MumbleClientListener);
      _client?.self.add(this as UserListener);
      _client?.audio.add(this as AudioListener);

      _updateChannelsInternal();

      _isConnected = true;
      _addSystemMessage('Connected.');

      // Display server welcome message (MOTD) if available
      final welcomeMessage = _client?.serverInfo.config?.welcomeText;
      if (welcomeMessage != null && welcomeMessage.isNotEmpty) {
        _addSystemMessage(welcomeMessage, senderName: 'Welcome message');
      }

      notifyListeners();

      // Ensure hardware audio resources are active and warm on connect
      await _startMicStream();
      _startVolumeMonitoring();
      _setupServerAudioSink();
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _startMicStream() async {
    debugPrint('[MumbleService] Ensuring mic stream is active...');
    if (!await _recorder.hasPermission()) {
      _hasMicPermission = false;
      notifyListeners();
      debugPrint('[MumbleService] Microphone permission denied.');
      return;
    }
    _hasMicPermission = true;
    notifyListeners();

    // Clean up old state if any
    await _micSubscription?.cancel();
    _micSubscription = null;
    _processingTimer?.cancel();
    _processingTimer = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    const sampleRate = 48000;
    const channels = 1;

    /// Frame size of 480 (10ms @ 48kHz) is chosen for the best balance of
    /// low latency and mobile processing stability. 20ms (960) can be used
    /// for better bandwidth efficiency but may feel 'choppy' on slower networks.

    final devices = await _recorder.listInputDevices();
    dynamic selectedDevice;
    if (_inputDeviceId != null && devices.isNotEmpty) {
      for (final d in devices) {
        if (d.id == _inputDeviceId) {
          selectedDevice = d;
          break;
        }
      }
    }

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: channels,

      /// In 6.x, the 'device' parameter accepts an 'InputDevice' object.
      /// We grab it from listDevices if we have an ID.
      device: selectedDevice,
    );

    final micStream = await _recorder.startStream(config);

    _pcmBuffer.clear();
    _micSubscription = micStream.listen(
      (data) {
        final int16data = Uint8List.fromList(data).buffer.asInt16List();
        _pcmBuffer.addAll(int16data);
        _processPcmBuffer();
      },
      onDone: () => debugPrint('[MumbleService] Mic stream closed.'),
      onError: (e) => debugPrint('[MumbleService] Mic stream error: $e'),
    );

    _processingTimer = Timer.periodic(const Duration(milliseconds: 20), (
      timer,
    ) {
      if (!_isConnected || _client == null) {
        timer.cancel();
        return;
      }
      _processPcmBuffer();
    });
  }

  void _setupServerAudioSink() {
    if (_client == null || !_isConnected) return;

    debugPrint('[MumbleService] Initializing server-specific audio sink...');

    // CRITICAL: Clear any leftover audio from the previous server/session
    _pcmBuffer.clear();

    // Create the sink for THIS server
    _audioSink = _client!.audio.sendAudio(codec: AudioCodec.opus);

    debugPrint('[MumbleService] Server sink ready.');
  }

  void _processPcmBuffer() {
    const frameSize = 960; // 20ms frame size
    while (_pcmBuffer.length >= frameSize) {
      final sub = _pcmBuffer.sublist(0, frameSize);
      _pcmBuffer.removeRange(0, frameSize);

      // Apply input gain
      Int16List frameSamples;
      if (_inputGain != 1.0) {
        frameSamples = Int16List(frameSize);
        for (int i = 0; i < frameSize; i++) {
          frameSamples[i] = (sub[i] * _inputGain).round().clamp(-32768, 32767);
        }
      } else {
        frameSamples = Int16List.fromList(sub);
      }

      if (_isTalking && _opusEncoder != null && _audioSink != null) {
        try {
          final encoded = _opusEncoder!.encode(frameSamples, frameSize);
          debugPrint('[MumbleService] Encoded ${frameSamples.length} PCM -> ${encoded.length} bytes opus');
          _audioSink!.add(AudioFrame.outgoing(frame: encoded));
        } catch (e) {
          debugPrint('[MumbleService] Error sending audio frame: $e');
        }
      } else if (_isTalking) {
        debugPrint('[MumbleService] PTT active but encoder=${_opusEncoder != null}, sink=${_audioSink != null}');
      }
    }
  }

  Future<void> sendAudioSamples(Int16List samples) async {
    if (!_isConnected || _client == null) return;

    // Ensure we are in talking mode to send audio
    if (!_isTalking) {
      await startPushToTalk();
    }

    _pcmBuffer.addAll(samples);
    _processPcmBuffer();
  }

  Future<void> startPushToTalk() async {
    if (!_isConnected || _client == null) return;

    if (isSuppressed) {
      _pttErrorMessage = 'You are suppressed by the server';
      notifyListeners();
      return;
    }

    if (isMuted) {
      _pttErrorMessage = 'You are muted. Unmute to talk';
      notifyListeners();
      return;
    }

    if (_isTalking) return;

    try {
      debugPrint('[MumbleService] PTT Active');
      _isTalking = true;
      _talkingUsers[_client!.self.session] = true;

      // If sink was somehow dropped, recreate it
      if (_audioSink == null) {
        _setupServerAudioSink();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[MumbleService] Error starting PTT: $e');
      stopPushToTalk();
    }
  }

  void stopPushToTalk() {
    if (!_isTalking) return;
    debugPrint('[MumbleService] PTT Inactive');
    _isTalking = false;
    if (_client != null) {
      _talkingUsers[_client!.self.session] = false;
    }

    _audioSink?.close();
    _audioSink = null;

    notifyListeners();
  }

  void _updateChannelsInternal() {
    if (_client != null) {
      _channels = _client!.getChannels().values.toList();
      for (final channel in _channels) {
        channel.add(this as ChannelListener);
      }
      for (final user in _client!.getUsers().values) {
        user.add(this as UserListener);
        // If we see a user with a comment hash but no comment, request it
        if (user.commentHash != null) {
          user.requestUserComment();
        }
      }
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    stopPushToTalk();
    _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();
    _volumeTimer?.cancel();

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
    _userBuffers.clear();
    _userPlaying.clear();
    notifyListeners();
  }

  // Jitter Buffer / Playback Buffering
  final Map<int, List<int>> _userBuffers = {};
  final Map<int, bool> _userPlaying = {};
  // Lowered threshold to 60ms (3 * 20ms frames) for better responsiveness
  static const int _bufferThreshold = 960 * 4;

  // Volume monitoring
  @override
  void onAudioReceived(
    Stream<AudioFrame> voiceData,
    AudioCodec codec,
    User? user,
    TalkMode talkMode,
  ) {
    if (user != null && codec == AudioCodec.opus) {
      final sessionId = user.session;
      _talkingUsers[sessionId] = true;
      notifyListeners();

      final decoder = _decoders.putIfAbsent(
        sessionId,
        () => MumbleOpusDecoder(sampleRate: 48000, channels: 1),
      );
      final buffer = _userBuffers.putIfAbsent(sessionId, () => []);

      voiceData.listen(
        (AudioFrame frame) {
          final frameData = frame.frame;
          if (frameData.isEmpty) return;

          // Decode Opus frame to PCM samples (Int16List)
          // Mumble frames are typically 20ms (960 samples)
          final pcm = decoder.decode(frameData, 5760);

          if (pcm.isNotEmpty) {
            buffer.addAll(pcm);

            // Jitter Buffer Logic:
            // Wait until we have enough data to start smooth playback.
            if (!_userPlaying.containsKey(sessionId) ||
                _userPlaying[sessionId] == false) {
              if (buffer.length >= _bufferThreshold) {
                _userPlaying[sessionId] = true;
                if (_audioPlayerInitialized) {
                  AudioPlaybackService().startSession(sessionId);
                }
              }
            }

            // If we are in playing state, or buffer is getting dangerously large, feed the player.
            if (_userPlaying[sessionId] == true || buffer.length > 5000) {
              _drainUserBuffer(sessionId, buffer);
            }
          }
        },
        onDone: () {
          _talkingUsers[sessionId] = false;
          _userPlaying[sessionId] = false;

          // Drain what's left in the buffer so we don't have "tail" audio
          // playing at the start of the next talk burst.
          _drainUserBuffer(sessionId, buffer, isEnd: true);

          AudioPlaybackService().stopSession(sessionId);
          notifyListeners();
        },
        onError: (_) {
          _talkingUsers[sessionId] = false;
          _userPlaying[sessionId] = false;
          AudioPlaybackService().stopSession(sessionId);
          notifyListeners();
        },
      );
    }
  }

  /// Helper to feed the audio playback service in standard chunks.
  void _drainUserBuffer(int sessionId, List<int> buffer, {bool isEnd = false}) {
    if (!_audioPlayerInitialized) return;

    // Process complete 20ms chunks (960 samples)
    while (buffer.length >= 960) {
      final chunk = buffer.sublist(0, 960);
      buffer.removeRange(0, 960);
      AudioPlaybackService().feed(sessionId, Int16List.fromList(chunk));
    }

    // If this is the end of the voice burst, drain any remaining partial frame
    if (isEnd && buffer.isNotEmpty) {
      AudioPlaybackService().feed(sessionId, Int16List.fromList(buffer));
      buffer.clear();
    }
  }

  @override
  void onChannelAdded(Channel channel) {
    channel.add(this as ChannelListener);
    _updateSync();
  }

  @override
  void onChannelRemoved(Channel channel) => _updateSync();

  @override
  void onChannelChanged(Channel channel, ChannelChanges changes) =>
      _updateSync();

  @override
  void onUserAdded(User user) {
    user.add(this as UserListener);
    // Request comment if they have one
    if (user.commentHash != null) {
      user.requestUserComment();
    }
    _updateSync();
  }

  @override
  void onUserChanged(User user, User? actor, UserChanges changes) {
    if (changes.commentHash && user.commentHash != null) {
      user.requestUserComment();
    }
    notifyListeners();
  }

  @override
  void onUserRemoved(User user, User? actor, String? reason, bool? ban) {
    _talkingUsers.remove(user.session);
    _decoders.remove(user.session)?.dispose();
    _userBuffers.remove(user.session);
    _userPlaying.remove(user.session);
    AudioPlaybackService().stopSession(user.session);
    _updateChannelsInternal();
  }

  // --- Implement missing mixin methods to fix lint errors ---
  @override
  void onTextMessage(IncomingTextMessage message) {
    _messages.add(
      ChatMessage(
        senderName: message.actor?.name ?? 'Unknown',
        content: message.message,
        timestamp: DateTime.now(),
        isSelf: message.actor?.session == _client?.self.session,
        sender: message.actor,
      ),
    );
    notifyListeners();
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
  @override
  void onUserStats(User user, UserStats stats) {
    _userStats[user.session] = stats;
    notifyListeners();
  }

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
  void dispose() {
    _micSubscription?.cancel();
    _volumeTimer?.cancel();
    _audioSink?.close();
    _opusEncoder?.dispose();
    _client?.close();
    _client = null;
    _recorder.dispose();
    for (final d in _decoders.values) {
      d.dispose();
    }
    _audioPlayerInitialized = false;
    AudioPlaybackService().dispose();
    super.dispose();
  }
}
