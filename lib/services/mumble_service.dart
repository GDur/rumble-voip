import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:dumble/dumble.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:rumble/models/certificate.dart';
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
  
  // Track talking status for all users (session ID -> isTalking)
  final Map<int, bool> _talkingUsers = {};
  
  // Audio recording and encoding (Outgoing)
  late final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _micSubscription;
  AudioFrameSink? _audioSink;
  MumbleOpusEncoder? _opusEncoder;
  
  // Audio decoding (Incoming)
  final Map<int, MumbleOpusDecoder> _decoders = {};
  bool _audioPlayerInitialized = false;
  
  // Jitter Buffer / Playback Buffering
  final Map<int, List<int>> _userBuffers = {};
  final Map<int, bool> _userPlaying = {};
  static const int _bufferThreshold = 960 * 5; // 100ms jitter buffer
  
  // Volume monitoring
  double _currentVolume = 0.0;
  Timer? _volumeTimer;
  
  // Buffer for raw PCM data (Outgoing)
  final List<int> _pcmBuffer = [];

  // Diagnostic counters (debug mode only)
  int _diagFramesSent = 0;
  int _diagSinkAddErrors = 0;
  
  MumbleClient? get client => _client;
  bool get isConnected => _isConnected;
  String? get error => _error;
  List<Channel> get channels => _channels;
  bool get isTalking => _isTalking;
  double get currentVolume => _currentVolume;
  Map<int, bool> get talkingUsers => _talkingUsers;
  bool get isSuppressed => _client?.self.suppress ?? false;
  bool get hasMicPermission => _hasMicPermission;

  MumbleService() {
    _recorder = AudioRecorder();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      debugPrint('[MumbleService] Initializing audio service...');
      await AudioPlaybackService().initialize(
        sampleRate: 48000,
        channels: 1,
      );
      _audioPlayerInitialized = true;
      debugPrint('[MumbleService] Audio service initialized.');
    } catch (e) {
      debugPrint('[MumbleService] Error initializing audio service: $e');
    }
  }

  void _startVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
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

  Future<void> connect(MumbleServer server, {MumbleCertificate? certificate}) async {
    _isConnected = false;
    _error = null;
    _channels = [];
    _talkingUsers.clear();
    notifyListeners();

    try {
      debugPrint('[MumbleService] Connecting to ${server.host}:${server.port}...');

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
      notifyListeners();
      
      // Configure Audio Session for iOS/VOIP
      try {
        debugPrint('[MumbleService] Configuring Audio Session...');
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        ));
        await session.setActive(true);
        debugPrint('[MumbleService] Audio Session configured and active.');
      } catch (e) {
        debugPrint('[MumbleService] Error configuring Audio Session: $e');
      }

      // Start passive mic monitoring immediately on connect
      _startMicStream();
      _startVolumeMonitoring();

      // Auto-run diagnostic in debug mode
      if (kDebugMode) {
        Future.delayed(const Duration(seconds: 2), _runDiagnostic);
      }
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _startMicStream() async {
    if (!await _recorder.hasPermission()) {
      _hasMicPermission = false;
      notifyListeners();
      debugPrint('[MumbleService] Microphone permission denied.');
      return;
    }
    _hasMicPermission = true;
    notifyListeners();

    if (await _recorder.isRecording()) return;

    const sampleRate = 48000;
    const channels = 1;
    /// Frame size of 480 (10ms @ 48kHz) is chosen for the best balance of 
    /// low latency and mobile processing stability. 20ms (960) can be used
    /// for better bandwidth efficiency but may feel 'choppy' on slower networks.

    final micStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
      ),
    );

    _pcmBuffer.clear();
    _micSubscription = micStream.listen((data) {
      /// CRITICAL: Uint8List.fromList(data) ensures the underlying buffer is 
      /// ByteData-aligned for 16-bit interpretation. Directly using data.buffer 
      /// can cause Bus Errors or RangeErrors on some architectures.
      final int16data = Uint8List.fromList(data).buffer.asInt16List();
      _pcmBuffer.addAll(int16data);
      _processPcmBuffer();
    }, onDone: () {
      debugPrint('[MumbleService] Mic stream closed.');
    }, onError: (e) {
      debugPrint('[MumbleService] Mic stream error: $e');
    });

    // Also start a periodic timer to process the buffer in case the mic stream is inactive
    // but samples are being injected manually (e.g. for debug tests)
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_isConnected || _client == null) {
        timer.cancel();
        return;
      }
      _processPcmBuffer();
    });
  }

  void _processPcmBuffer() {
    const frameSize = 480;
    while (_pcmBuffer.length >= frameSize) {
      final frameSamples = Int16List.fromList(_pcmBuffer.sublist(0, frameSize));
      _pcmBuffer.removeRange(0, frameSize);

      if (_isTalking && _opusEncoder != null && _audioSink != null) {
        try {
          /// Encoder is configured with FEC (Forward Error Correction) 
          /// and VBR enabled in MumbleOpusEncoder constructor.
          final encoded = _opusEncoder!.encode(frameSamples, frameSize);
          _audioSink!.add(AudioFrame.outgoing(frame: encoded));
          _diagFramesSent++;
        } catch (e) {
          _diagSinkAddErrors++;
          debugPrint('[MumbleService] _processPcmBuffer error: $e');
        }
      }
    }
  }

  // Generates a 440Hz sine wave of the given duration in milliseconds.
  Int16List _generateTone(int durationMs) {
    const sampleRate = 48000;
    final numSamples = sampleRate * durationMs ~/ 1000;
    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fade = i < 500 ? i / 500.0 : (i > numSamples - 500 ? (numSamples - i) / 500.0 : 1.0);
      samples[i] = (math.sin(2 * math.pi * 440.0 * t) * 15000 * fade).toInt();
    }
    return samples;
  }

  void _logDiagState(String label) {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('[DIAG] $label');
    debugPrint('[DIAG]   _isTalking        = $_isTalking');
    debugPrint('[DIAG]   _audioSink        = ${_audioSink != null ? "EXISTS (done=${_audioSink!.done})" : "NULL"}');
    debugPrint('[DIAG]   _opusEncoder      = ${_opusEncoder != null ? "EXISTS" : "NULL"}');
    debugPrint('[DIAG]   sequenceNumber    = ${AudioClient.sequenceNumber}');
    debugPrint('[DIAG]   _pcmBuffer.length = ${_pcmBuffer.length}');
    debugPrint('[DIAG]   framesSent        = $_diagFramesSent');
    debugPrint('[DIAG]   sinkAddErrors     = $_diagSinkAddErrors');
    debugPrint('[DIAG]   isConnected       = $_isConnected');
    debugPrint('[DIAG]   isSuppressed      = $isSuppressed');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  Future<void> _runDiagnostic() async {
    if (!_isConnected) return;
    debugPrint('[DIAG] ============ DIAGNOSTIC START ============');

    // --- Round 1 ---
    debugPrint('[DIAG] Round 1: Starting PTT and injecting tone...');
    _diagFramesSent = 0;
    _diagSinkAddErrors = 0;
    await startPushToTalk();
    _logDiagState('After startPushToTalk() - Round 1');

    // Add an onError hook to the sink
    _audioSink?.onError = (e, [st]) {
      debugPrint('[DIAG] _audioSink.onError: $e');
    };

    // Inject 500ms of tone
    sendAudioSamples(_generateTone(500));
    _logDiagState('After sendAudioSamples() - Round 1 (immediate)');

    // Log state while transmitting
    await Future.delayed(const Duration(milliseconds: 250));
    _logDiagState('During transmission - Round 1 (250ms)');

    await Future.delayed(const Duration(milliseconds: 300));
    _logDiagState('After tone complete - Round 1 (550ms total)');

    stopPushToTalk();
    _logDiagState('After stopPushToTalk() - Round 1');

    // --- 500ms pause ---
    debugPrint('[DIAG] Pausing for 500ms...');
    await Future.delayed(const Duration(milliseconds: 500));
    _logDiagState('After pause (before Round 2)');

    // --- Round 2 ---
    debugPrint('[DIAG] Round 2: Starting PTT and injecting tone...');
    _diagFramesSent = 0;
    _diagSinkAddErrors = 0;
    await startPushToTalk();
    _logDiagState('After startPushToTalk() - Round 2');

    _audioSink?.onError = (e, [st]) {
      debugPrint('[DIAG] _audioSink.onError (Round 2): $e');
    };

    sendAudioSamples(_generateTone(500));
    _logDiagState('After sendAudioSamples() - Round 2 (immediate)');

    await Future.delayed(const Duration(milliseconds: 250));
    _logDiagState('During transmission - Round 2 (250ms)');

    await Future.delayed(const Duration(milliseconds: 300));
    _logDiagState('After tone complete - Round 2 (550ms total)');

    stopPushToTalk();
    _logDiagState('After stopPushToTalk() - Round 2');

    debugPrint('[DIAG] ============ DIAGNOSTIC COMPLETE ============');
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
    if (!_isConnected || _isTalking || _client == null) return;
    
    try {
      debugPrint('[MumbleService] Starting PTT...');
      _isTalking = true;
      _talkingUsers[_client!.self.session] = true;
      
      // Reset the static sequence counter before each new audio stream.
      // dumble's AudioClient._sequenceNumber is static and keeps growing forever.
      // Calling this ensures the new stream starts from 0, preventing the Mumble
      // server from discarding packets on a 2nd/3rd PTT press.
      AudioClient.resetSequenceNumber();

      // Initialize outgoing audio stream
      _audioSink = _client!.audio.sendAudio(codec: AudioCodec.opus);
      debugPrint('[MumbleService] _audioSink created: ${_audioSink != null}');
      
      _opusEncoder = MumbleOpusEncoder(
        sampleRate: 48000,
        channels: 1,
        application: opusApplicationVoip,
      );
      debugPrint('[MumbleService] _opusEncoder created: ${_opusEncoder != null}');
      
      notifyListeners();
    } catch (e) {
      debugPrint('[MumbleService] Error starting PTT: $e');
      stopPushToTalk();
    }
  }

  void stopPushToTalk() {
    if (!_isTalking) return;
    debugPrint('[MumbleService] Stopping PTT...');
    _isTalking = false;
    if (_client != null) {
       _talkingUsers[_client!.self.session] = false;
    }
    
    _audioSink?.close();
    _audioSink = null;
    
    _opusEncoder?.dispose();
    _opusEncoder = null;
    debugPrint('[MumbleService] PTT stopped and resources cleared.');
    
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
    _talkingUsers.clear();
    for (final d in _decoders.values) {
      d.dispose();
    }
    _decoders.clear();
    _userBuffers.clear();
    _userPlaying.clear();
    notifyListeners();
  }

  @override
  void onAudioReceived(Stream<AudioFrame> voiceData, AudioCodec codec, User? user, TalkMode talkMode) {
    if (user != null && codec == AudioCodec.opus) {
      final sessionId = user.session;
      _talkingUsers[sessionId] = true;
      notifyListeners();

      final decoder = _decoders.putIfAbsent(sessionId, () => MumbleOpusDecoder(sampleRate: 48000, channels: 1));
      final buffer = _userBuffers.putIfAbsent(sessionId, () => []);

      voiceData.listen((AudioFrame frame) {
        final frameData = frame.frame;
        // Decode Opus frame to PCM samples (Int16List)
        final pcm = decoder.decode(frameData, 5760); 
        
        if (pcm.isNotEmpty) {
          buffer.addAll(pcm);
          
          if (!_userPlaying.containsKey(sessionId) || _userPlaying[sessionId] == false) {
            if (buffer.length >= _bufferThreshold) {
              _userPlaying[sessionId] = true;
              if (_audioPlayerInitialized) {
                AudioPlaybackService().start();
              }
            }
          }
          
          if (_userPlaying[sessionId] == true || buffer.length > 5000) {
             while (buffer.length >= 960) {
                final chunk = buffer.sublist(0, 960);
                buffer.removeRange(0, 960);
                if (_audioPlayerInitialized) {
                   AudioPlaybackService().feed(Int16List.fromList(chunk));
                }
             }
          }
        }
      }, onDone: () {
        _talkingUsers[sessionId] = false;
        _userPlaying[sessionId] = false;
        notifyListeners();
      }, onError: (_) {
         _talkingUsers[sessionId] = false;
         _userPlaying[sessionId] = false;
         notifyListeners();
      });
    }
  }

  @override
  void onChannelAdded(Channel channel) {
    channel.add(this as ChannelListener);
    _updateChannelsInternal();
  }

  @override
  void onChannelRemoved(Channel channel) => _updateChannelsInternal();

  @override
  void onChannelChanged(Channel channel, ChannelChanges changes) => _updateChannelsInternal();

  @override
  void onUserAdded(User user) {
    user.add(this as UserListener);
    _updateChannelsInternal();
  }

  @override
  void onUserChanged(User user, User? actor, UserChanges changes) => notifyListeners();

  @override
  void onUserRemoved(User user, User? actor, String? reason, bool? ban) {
    _talkingUsers.remove(user.session);
    _decoders.remove(user.session)?.dispose();
    _userBuffers.remove(user.session);
    _userPlaying.remove(user.session);
    _updateChannelsInternal();
  }

  // --- Implement missing mixin methods to fix lint errors ---
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
    _recorder.dispose();
    for (final d in _decoders.values) {
      d.dispose();
    }
    _audioPlayerInitialized = false;
    AudioPlaybackService().dispose();
    super.dispose();
  }
}
