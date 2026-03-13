import 'dart:async';
import 'dart:typed_data';
import 'package:dumble/dumble.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm_sound;
import 'package:rumble/models/server.dart';
import 'package:rumble/utils/mumble_audio.dart';

class MumbleService extends ChangeNotifier 
    with MumbleClientListener, ChannelListener, UserListener, AudioListener {
  MumbleClient? _client;
  bool _isConnected = false;
  String? _error;
  List<Channel> _channels = [];
  bool _isTalking = false;
  
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
  
  MumbleClient? get client => _client;
  bool get isConnected => _isConnected;
  String? get error => _error;
  List<Channel> get channels => _channels;
  bool get isTalking => _isTalking;
  double get currentVolume => _currentVolume;
  Map<int, bool> get talkingUsers => _talkingUsers;

  MumbleService() {
    _recorder = AudioRecorder();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      debugPrint('[MumbleService] Initializing audio player (48kHz Mono, PlayAndRecord)...');
      await pcm_sound.FlutterPcmSound.setup(
        sampleRate: 48000, 
        channelCount: 1,
        iosAudioCategory: pcm_sound.IosAudioCategory.playAndRecord,
      );
      await pcm_sound.FlutterPcmSound.setFeedThreshold(1024 * 4);
      _audioPlayerInitialized = true;
      debugPrint('[MumbleService] Audio player initialized.');
    } catch (e) {
      debugPrint('[MumbleService] Error initializing audio player: $e');
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

  Future<void> stopMonitoring() async {
    _volumeTimer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _currentVolume = 0;
    notifyListeners();
  }

  Future<void> connect(MumbleServer server) async {
    _error = null;
    _channels = [];
    _talkingUsers.clear();
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
      _client?.self.add(this as UserListener);
      _client?.audio.add(this as AudioListener);
      
      _updateChannelsInternal();
      
      _isConnected = true;
      notifyListeners();
      
      _startVolumeMonitoring();
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startPushToTalk() async {
    if (!_isConnected || _isTalking || _client == null) return;
    
    try {
       if (!await _recorder.hasPermission()) {
        debugPrint('[MumbleService] Microphone permission denied.');
        return;
      }

      await stopMonitoring();

      _isTalking = true;
      _talkingUsers[_client!.self.session] = true;
      notifyListeners();

      const sampleRate = 48000;
      const channels = 1;
      const frameSize = 960; 

      _audioSink = _client!.audio.sendAudio(codec: AudioCodec.opus);
      _opusEncoder = MumbleOpusEncoder(
        sampleRate: sampleRate,
        channels: channels,
        application: opusApplicationVoip,
      );

      final micStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: channels,
        ),
      );

      _pcmBuffer.clear();
      _startVolumeMonitoring();

      _micSubscription = micStream.listen((data) {
        // Ensure data is typed list and aligned for 16-bit access
        final Uint8List bytes = Uint8List.fromList(data);
        final int16data = bytes.buffer.asInt16List();
        
        _pcmBuffer.addAll(int16data);

        while (_pcmBuffer.length >= frameSize) {
          final frameSamples = Int16List.fromList(_pcmBuffer.sublist(0, frameSize));
          _pcmBuffer.removeRange(0, frameSize);

          final encoded = _opusEncoder?.encode(frameSamples, frameSize);
          if (encoded != null && _audioSink != null) {
            _audioSink!.add(AudioFrame.outgoing(frame: encoded));
          }
        }
      });
    } catch (e) {
      debugPrint('[MumbleService] Error starting PTT: $e');
      stopPushToTalk();
    }
  }

  void stopPushToTalk() {
    if (!_isTalking) return;
    _isTalking = false;
    if (_client != null) {
       _talkingUsers[_client!.self.session] = false;
    }
    
    _volumeTimer?.cancel();
    _micSubscription?.cancel();
    _micSubscription = null;
    
    _recorder.stop();
    _audioSink?.close();
    _audioSink = null;
    
    _opusEncoder?.dispose();
    _opusEncoder = null;
    
    _currentVolume = 0;
    notifyListeners();
    
    _startVolumeMonitoring();
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
        if (frame.frame != null) {
           // Decode Opus frame to PCM samples (Int16List)
           final pcm = decoder.decode(frame.frame!, 5760); 
           
           if (pcm.isNotEmpty) {
              buffer.addAll(pcm);
              
              if (!_userPlaying.containsKey(sessionId) || _userPlaying[sessionId] == false) {
                if (buffer.length >= _bufferThreshold) {
                  _userPlaying[sessionId] = true;
                  if (_audioPlayerInitialized) {
                    pcm_sound.FlutterPcmSound.start();
                  }
                }
              }
              
              if (_userPlaying[sessionId] == true || buffer.length > 5000) {
                 while (buffer.length >= 960) {
                    final chunk = buffer.sublist(0, 960);
                    buffer.removeRange(0, 960);
                    if (_audioPlayerInitialized) {
                       pcm_sound.FlutterPcmSound.feed(pcm_sound.PcmArrayInt16.fromList(chunk));
                    }
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
    _volumeTimer?.cancel();
    _recorder.dispose();
    for (final d in _decoders.values) {
      d.dispose();
    }
    _audioPlayerInitialized = false;
    pcm_sound.FlutterPcmSound.release();
    super.dispose();
  }
}
