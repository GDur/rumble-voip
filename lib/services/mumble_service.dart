import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:rumble/services/background_service.dart';
import 'package:rumble/models/certificate.dart';
import 'package:rumble/models/chat_message.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:rumble/src/rust/mumble/config.dart';
import 'package:rumble/src/rust/mumble/hardware/audio.dart';
import 'package:rumble/utils/html_utils.dart';
import 'package:dumble/dumble.dart' as dumble;

abstract class DeviceLister {
  Future<List<AudioDevice>> listInputDevices();
  Future<List<AudioDevice>> listOutputDevices();
}

class DefaultDeviceLister implements DeviceLister {
  @override
  Future<List<AudioDevice>> listInputDevices() => listAudioInputDevices();
  @override
  Future<List<AudioDevice>> listOutputDevices() => listAudioOutputDevices();
}

class MumbleService extends ChangeNotifier with dumble.MumbleClientListener {
  final RustAudioEngine _rustEngine;
  final DeviceLister _deviceLister;

  MumbleService({
    RustAudioEngine? rustEngine,
    DeviceLister? deviceLister,
  }) : _rustEngine = rustEngine ?? RustAudioEngine(),
       _deviceLister = deviceLister ?? DefaultDeviceLister();
  dumble.MumbleClient? _dumbleClient;
  bool _isConnected = false;
  String? _error;
  List<MumbleChannel> _channels = [];
  final Map<int, MumbleUser> _users = {};
  final Set<int> _talkingUsers = {};
  final List<ChatMessage> _messages = [];
  int? _selfSession;
  int _unreadMessagesCount = 0;
  bool _isLocalPttActive = false;
  late SettingsService _settings;
  MumbleServer? _currentServer;
  int? _targetChannelId;
  void Function(MumbleServer)? onServerUpdated;
  bool _audioInitialized = false;

  // Trackers to avoid adding duplicate listeners
  final Set<int> _trackedUserListeners = {};
  final Set<int> _trackedChannelListeners = {};

  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.0);
  String? _pttErrorMessage;

  StreamSubscription? _audioEventSubscription;
  Timer? _pttStartTimer;
  Timer? _pttHoldTimer;

  bool get isConnected => _isConnected;
  String? get error => _error;
  List<MumbleChannel> get channels => _channels;
  List<MumbleUser> get users => _users.values.toList();
  List<ChatMessage> get messages => _messages;
  int get unreadMessagesCount => _unreadMessagesCount;
  int? get selfSession => _selfSession;
  Map<int, bool> get talkingUsers {
    final res = {for (var uid in _talkingUsers) uid: true};
    if (_isLocalPttActive && _selfSession != null) {
      res[_selfSession!] = true;
    }
    return res;
  }
  MumbleUser? get self => _selfSession != null ? _users[_selfSession] : null;
  int? get maxUsers => _dumbleClient?.serverInfo.config?.maxUsers ?? _currentServer?.maxUsers;

  // UI-specific getters
  String get currentChannelName => self?.channelId != null 
      ? _channels.firstWhere((c) => c.id == self!.channelId).name 
      : 'Not Connected';
  bool get isTalking => _isLocalPttActive || _talkingUsers.contains(_selfSession);
  double get currentVolume => volumeNotifier.value;
  bool get isSuppressed => self?.isSuppressed ?? false;

  bool get hasMicPermission => true; // For now
  String? get pttErrorMessage => _pttErrorMessage;

  Stream<double> get volumeStream => const Stream.empty();

  Future<void> initialize(
    SettingsService settings,
    double inputGain,
    double outputVolume,
    String? captureDeviceId,
    String? playbackDeviceId,
  ) async {
    _settings = settings;
    
    // Wire up Rust audio engine events
    _audioEventSubscription = _rustEngine.getEventStream().listen((event) {
      event.when(
        audioVolume: (vol) {
          volumeNotifier.value = vol;
        },
        userTalking: (sessionId, isTalking) {
          if (isTalking) {
            _talkingUsers.add(sessionId);
          } else {
            _talkingUsers.remove(sessionId);
          }
          _syncUsers();
        },
        disconnected: (reason) {
          developer.log(
            'Audio Engine Disconnected',
            error: reason,
            name: 'MumbleService',
            level: 1000,
          );
          _error = reason;
          disconnect();
        },
      );
    });

    await updateAudioSettings(
      bitrate: settings.outgoingAudioBitrate,
      msPerPacket: settings.outgoingAudioMsPerPacket,
      jitterBuffer: settings.incomingJitterBufferMs,
      playbackHwBufferMs: settings.playbackHwBufferMs,
      captureDevice: captureDeviceId,
      playbackDevice: playbackDeviceId,
      inputGain: inputGain,
      outputVolume: outputVolume,
    );
    
    await _refreshDevices();
  }

  List<AudioDevice> _inputDevices = [];
  List<AudioDevice> _outputDevices = [];

  List<AudioDevice> get inputDevices => _inputDevices;
  List<AudioDevice> get outputDevices => _outputDevices;

  Future<void> _refreshDevices() async {
    _inputDevices = await _deviceLister.listInputDevices();
    _outputDevices = await _deviceLister.listOutputDevices();
    notifyListeners();
  }

  Future<void> connect(MumbleServer server, {MumbleCertificate? certificate}) async {
    _error = null;
    _channels = [];
    _users.clear();
    _talkingUsers.clear();
    _messages.clear();
    _selfSession = null;
    _targetChannelId = null;
    _trackedUserListeners.clear();
    _trackedChannelListeners.clear();
    notifyListeners();

    try {
      _currentServer = server;
      SecurityContext? context;
      if (certificate != null) {
        context = SecurityContext();
        context.useCertificateChainBytes(utf8.encode(certificate.certificatePem));
        context.usePrivateKeyBytes(utf8.encode(certificate.privateKeyPem));
      }

      final options = dumble.ConnectionOptions(
        host: server.host,
        port: server.port,
        name: server.username,
        password: server.password.isEmpty ? null : server.password,
        context: context,
      );

      // DebugGING for iOS resolution and connection
      debugPrint('[MumbleService] Attempting to connect to ${server.host}:${server.port}');
      if (Platform.isIOS) {
        try {
          final addresses = await InternetAddress.lookup(server.host);
          debugPrint('[MumbleService] Resolved addresses: ${addresses.map((a) => a.address).join(', ')}');
        } catch (dnsError) {
          debugPrint('[MumbleService] DNS Resolution failed (but trying dumble connect anyway): $dnsError');
        }
        // Small delay as an experimental fix for some iOS networking race conditions
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _dumbleClient = await dumble.MumbleClient.connect(
        options: options,
        onBadCertificate: (cert) => true,
        useUdp: true, 
      ).timeout(const Duration(seconds: 10)); // Added a timeout to avoid hangs on iOS
      
      _isConnected = true; 
      _dumbleClient!.add(this);
      
      _selfSession = _dumbleClient!.self.session;
      debugPrint('Mumble: Handshake finished. Self session: $_selfSession');

      // Start background service to prevent sleep
      await BackgroundService.start(serverName: server.name);
      
      // Target channel to join once sync is stable
      if (_settings.rememberLastChannel && server.lastChannelId != null) {
        _targetChannelId = server.lastChannelId;
        debugPrint('Mumble: Target channel set: $_targetChannelId');
      }

      // Hand over crypt keys to rust
      final crypt = _dumbleClient!.cryptState;
      if (!_audioInitialized) {
        await _rustEngine.initializeAudio(
          host: server.host,
          port: server.port,
          key: crypt.key,
          encryptNonce: crypt.clientNonce,
          decryptNonce: crypt.serverNonce,
        );
        _audioInitialized = true;
      }

      _syncChannels();
      _syncUsers();

      // Initial attempt (in case channels are already fully synced)
      _tryJoinTargetChannel();

      _addSystemMessage('Connected.');
      notifyListeners();

    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      _currentServer = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    developer.log('MumbleService: Disconnecting...', name: 'MumbleService');
    try {
      await _dumbleClient?.close();
      _dumbleClient = null;
      await _rustEngine.disconnect();
    } catch (e, st) {
      developer.log(
        'Error during disconnect',
        error: e,
        stackTrace: st,
        name: 'MumbleService',
      );
    } finally {
      // Stop background service
      await BackgroundService.stop();
      
      _isConnected = false;
      _currentServer = null;
      _selfSession = null;
      _targetChannelId = null;
      _channels = [];
      _users.clear();
      _talkingUsers.clear();
      _trackedUserListeners.clear();
      _trackedChannelListeners.clear();
      _audioInitialized = false;
      notifyListeners();
      developer.log('MumbleService: Disconnected.', name: 'MumbleService');
    }
  }

  // --- dumble.MumbleClientListener implementation ---

  @override
  void onUserAdded(dumble.User user) {
     debugPrint('Mumble: User added: ${user.name} (session: ${user.session})');
     if (!_trackedUserListeners.contains(user.session)) {
       user.add(_GenericUserListener(this));
       _trackedUserListeners.add(user.session);
     }
     if (user.comment == null && user.commentHash != null) {
       debugPrint('Mumble: Requesting comment for ${user.name}');
       user.requestUserComment();
     }
     _syncUsers();
  }

  @override
  void onChannelAdded(dumble.Channel channel) {
     if (!_trackedChannelListeners.contains(channel.channelId)) {
       channel.add(_GenericChannelListener(this));
       _trackedChannelListeners.add(channel.channelId);
     }
     _syncChannels();
  }

  @override
  void onTextMessage(dumble.IncomingTextMessage message) {
    _messages.add(
      ChatMessage(
        senderName: message.actor?.name ?? 'System',
        content: HtmlUtils.sanitizeMumbleHtml(message.message),
        timestamp: DateTime.now(),
        isSelf: message.actor?.session == _selfSession,
      ),
    );
    if (message.actor?.session != _selfSession) {
      _unreadMessagesCount++;
    }
    notifyListeners();
  }

  void clearUnreadCount() {
    if (_unreadMessagesCount != 0) {
      _unreadMessagesCount = 0;
      notifyListeners();
    }
  }

  @override
  void onDone() {
    disconnect();
  }

  @override
  void onError(Object error, [StackTrace? stackTrace]) {
    developer.log(
      'Mumble Runtime Error',
      error: error,
      stackTrace: stackTrace,
      name: 'MumbleService',
      level: 1000,
    );
    _error = error.toString();
    disconnect();
  }

  @override
  void onCryptStateChanged() {
    final crypt = _dumbleClient?.cryptState;
    if (crypt != null && _isConnected && !_audioInitialized) {
       _rustEngine.initializeAudio(
          host: _dumbleClient!.options.host,
          port: _dumbleClient!.options.port,
          key: crypt.key,
          encryptNonce: crypt.clientNonce,
          decryptNonce: crypt.serverNonce,
        );
        _audioInitialized = true;
    }
  }
  
  @override
  void onBanListReceived(List<dumble.BanEntry> bans) {}
  @override
  void onDropAllChannelPermissions() {}
  @override
  void onPermissionDenied(dumble.PermissionDeniedException e) {
    _addSystemMessage('Permission Denied: ${e.reason}');
    _syncUsers();
  }
  @override
  void onQueryUsersResult(Map<int, String> idToName) {}
  @override
  void onUserListReceived(List<dumble.RegisteredUser> users) {}

  // --- End Listener implementation ---

  void _syncChannels() {
    if (_dumbleClient == null) return;
    
    _channels = _dumbleClient!.getChannels().values.map((c) {
      if (!_trackedChannelListeners.contains(c.channelId)) {
        c.add(_GenericChannelListener(this));
        _trackedChannelListeners.add(c.channelId);
      }
      return MumbleChannel(
        id: c.channelId,
        name: c.name ?? 'Unknown',
        parentId: c.parent?.channelId,
        position: c.position ?? 0,
        description: c.description,
        isEnterRestricted: c.isEnterRestricted ?? false,
      );
    }).toList();
    
    notifyListeners();
    _tryJoinTargetChannel();
  }

  void _tryJoinTargetChannel() {
    if (_targetChannelId == null || _dumbleClient == null) return;
    
    final chan = _dumbleClient!.getChannels()[_targetChannelId!];
    if (chan != null) {
      debugPrint('Mumble: Rejoining target channel: ${_targetChannelId}');
      _dumbleClient!.self.moveToChannel(channel: chan);
      // We don't clear it here, we clear it in _syncUsers once we are actually there
    }
  }

  void _syncUsers() {
    if (_dumbleClient == null) return;
    
    _users.clear();
    final allUsers = _dumbleClient!.getUsers();
    
    // Process all known users
    for (var u in allUsers.values) {
      if (!_trackedUserListeners.contains(u.session)) {
        debugPrint('Mumble: Attaching listener to ${u.name} (${u.session})');
        u.add(_GenericUserListener(this));
        _trackedUserListeners.add(u.session);
      }
      
      // Auto-request comment if missing but hash exists
      if (u.comment == null && u.commentHash != null) {
        u.requestUserComment();
      }
      
      _users[u.session] = _mapUser(u);
    }
    
    // Process self - prioritize the one in the user map to ensure consistency
    final selfObj = _dumbleClient!.self;
    final selfFromMap = allUsers[selfObj.session] ?? selfObj;
    
    if (!_trackedUserListeners.contains(selfFromMap.session)) {
      selfFromMap.add(_GenericUserListener(this));
      _trackedUserListeners.add(selfFromMap.session);
    }
    _users[selfFromMap.session] = _mapUser(selfFromMap);
    
    notifyListeners();

    final currentChannelId = selfFromMap.channel.channelId;

    // If we've reached our target channel, clear the sticky target
    if (_targetChannelId != null && currentChannelId == _targetChannelId) {
      debugPrint('Mumble: Target channel reached. Clearing target sticky.');
      _targetChannelId = null;
    }

    // Update last channel if it changed (and only if we are not still trying to move to a target)
    if (_currentServer != null && _settings.rememberLastChannel && _targetChannelId == null) {
      if (currentChannelId != _currentServer!.lastChannelId) {
        debugPrint('Mumble: Updating last joined channel to $currentChannelId');
        _currentServer = _currentServer!.copyWith(lastChannelId: currentChannelId);
        onServerUpdated?.call(_currentServer!);
      }
    }
  }

  MumbleUser _mapUser(dumble.User u) {
    return MumbleUser(
      session: u.session,
      name: u.name ?? 'Unknown',
      channelId: u.channel.channelId,
      isTalking: (_isLocalPttActive && u.session == _selfSession) || _talkingUsers.contains(u.session),
      isMuted: (u.mute == true) || (u.selfMute == true),
      isDeafened: (u.deaf == true) || (u.selfDeaf == true),
      isSuppressed: u.suppress == true,
      comment: u.comment,
    );
  }

  void _addSystemMessage(String content) {
    _messages.add(ChatMessage(
      senderName: 'System',
      content: content,
      timestamp: DateTime.now(),
      isSelf: false,
    ));
    notifyListeners();
  }

  // --- Direct Commands ---

  void joinChannel(int channelId) {
    _targetChannelId = null; // Manual move cancels autojoin
    final chan = _dumbleClient?.getChannels()[channelId];
    if (chan != null) {
      _dumbleClient?.self.moveToChannel(channel: chan);
    }
  }

  void sendTextMessage(String message) {
    if (_dumbleClient == null) return;
    final currentChannel = _dumbleClient!.self.channel;
    
    final sanitizedMessage = HtmlUtils.sanitizeMumbleHtml(message);
    
    _dumbleClient!.sendMessage(
      message: dumble.OutgoingTextMessage(
        message: sanitizedMessage,
        channels: [currentChannel],
      ),
    );
    
    _messages.add(ChatMessage(
      senderName: _dumbleClient!.self.name ?? 'Me',
      content: sanitizedMessage,
      timestamp: DateTime.now(),
      isSelf: true,
    ));
    notifyListeners();
  }

  void setPtt(bool active) {
    if (active) {
      startPushToTalk();
    } else {
      stopPushToTalk();
    }
  }

  void setMute(bool mute) {
    _dumbleClient?.self.setSelfMute(mute: mute);
  }

  void setDeafen(bool deaf) {
    _dumbleClient?.self.setSelfDeaf(deaf: deaf);
  }

  void setInputGain(double gain) {
    _rustEngine.setInputGain(gain: gain);
  }

  void setOutputVolume(double volume) {
    _rustEngine.setOutputVolume(volume: volume);
  }

  void setUserVolume(int sessionId, double volume) {
    _rustEngine.setUserVolume(sessionId: sessionId, volume: volume);
  }

  void toggleMute() {
    if (_dumbleClient == null) return;
    final isCurrentlyMuted = _dumbleClient!.self.selfMute ?? false;
    _dumbleClient!.self.setSelfMute(mute: !isCurrentlyMuted);
    _syncUsers(); // Immediate local sync for snappy UI
  }

  void toggleDeafen() {
    if (_dumbleClient == null) return;
    final isCurrentlyDeaf = _dumbleClient!.self.selfDeaf ?? false;
    _dumbleClient!.self.setSelfDeaf(deaf: !isCurrentlyDeaf);
    _syncUsers(); // Immediate local sync for snappy UI
  }

  bool get isMuted => _dumbleClient?.self.selfMute ?? false;
  bool get isDeafened => _dumbleClient?.self.selfDeaf ?? false;

  void setComment(String comment) {
    if (_dumbleClient == null) return;
    _dumbleClient!.self.setComment(comment: comment);
    _syncUsers(); // Immediate local sync
  }

  double getUserVolume(MumbleUser user) {
    return _settings.getUserVolume(user.name);
  }

  Future<void> updateAudioSettings({
    int? bitrate,
    int? msPerPacket,
    int? jitterBuffer,
    String? captureDevice,
    String? playbackDevice,
    double? inputGain,
    double? outputVolume,
    int? outgoingAudioBitrate,
    int? outgoingAudioMsPerPacket,
    int? incomingJitterBufferMs,
    int? playbackHwBufferMs,
    String? captureDeviceId,
    String? playbackDeviceId,
  }) async {
    final bridgeConfig = MumbleConfig(
      outgoingAudioBitrate: outgoingAudioBitrate ?? bitrate ?? _settings.outgoingAudioBitrate,
      outgoingAudioMsPerPacket: outgoingAudioMsPerPacket ?? msPerPacket ?? _settings.outgoingAudioMsPerPacket,
      incomingJitterBufferMs: incomingJitterBufferMs ?? jitterBuffer ?? _settings.incomingJitterBufferMs,
      playbackHwBufferSize: (playbackHwBufferMs ?? _settings.playbackHwBufferMs) > 0 
          ? AudioBufferSize.fixed((playbackHwBufferMs ?? _settings.playbackHwBufferMs) * 48) // 48 samples per ms @ 48kHz
          : const AudioBufferSize.default_(),
      captureHwBufferSize: const AudioBufferSize.default_(),
      captureDeviceId: captureDeviceId ?? captureDevice,
      playbackDeviceId: playbackDeviceId ?? playbackDevice,
    );
    await _rustEngine.setConfig(config: bridgeConfig);

    if (inputGain != null) {
      await _rustEngine.setInputGain(gain: inputGain);
    }
    if (outputVolume != null) {
      await _rustEngine.setOutputVolume(volume: outputVolume);
    }
  }

  Future<void> startPushToTalk() async {
    _pttHoldTimer?.cancel();
    _pttHoldTimer = null;

    final delay = _settings.pttStartDelayMs;
    if (delay > 0) {
      _pttStartTimer?.cancel();
      _pttStartTimer = Timer(Duration(milliseconds: delay), () async {
        _isLocalPttActive = true;
        notifyListeners();
        await _rustEngine.setPtt(active: true);
        _pttStartTimer = null;
      });
    } else {
      _isLocalPttActive = true;
      notifyListeners();
      await _rustEngine.setPtt(active: true);
    }
  }

  Future<void> stopPushToTalk() async {
    _pttStartTimer?.cancel();
    _pttStartTimer = null;

    final hold = _settings.pttHoldMs;
    if (hold > 0) {
      _pttHoldTimer?.cancel();
      _pttHoldTimer = Timer(Duration(milliseconds: hold), () async {
        _isLocalPttActive = false;
        notifyListeners();
        await _rustEngine.setPtt(active: false);
        _pttHoldTimer = null;
      });
    } else {
      _isLocalPttActive = false;
      notifyListeners();
      await _rustEngine.setPtt(active: false);
    }
  }

  void refreshInputDevices() => _refreshDevices();
  void refreshOutputDevices() => _refreshDevices();
  void clearPttErrorMessage() => _pttErrorMessage = null;
  void sendMessage(String message) => sendTextMessage(message);

  @override
  void dispose() {
    _audioEventSubscription?.cancel();
    _pttStartTimer?.cancel();
    _pttHoldTimer?.cancel();
    _dumbleClient?.close();
    super.dispose();
  }
}

class _GenericUserListener with dumble.UserListener {
  final MumbleService service;
  _GenericUserListener(this.service);

  @override
  void onUserChanged(dumble.User user, dumble.User? actor, dumble.UserChanges changes) {
    debugPrint('Mumble: onUserChanged for ${user.name} (comment: ${changes.comment}, hash: ${changes.commentHash})');
    if (changes.commentHash && user.comment == null) {
      user.requestUserComment();
    }
    service._syncUsers();
  }

  @override
  void onUserRemoved(dumble.User user, dumble.User? actor, String? reason, bool? ban) {
    service._trackedUserListeners.remove(user.session);
    service._syncUsers();
  }
  
  @override
  void onUserStats(dumble.User user, dumble.UserStats stats) {
    service._syncUsers();
  }
}

class _GenericChannelListener with dumble.ChannelListener {
  final MumbleService service;
  _GenericChannelListener(this.service);

  @override
  void onChannelChanged(dumble.Channel channel, dumble.ChannelChanges changes) {
    service._syncChannels();
  }

  @override
  void onChannelRemoved(dumble.Channel channel) {
    service._trackedChannelListeners.remove(channel.channelId);
    service._syncChannels();
  }

  @override
  void onChannelPermissionsReceived(dumble.Channel channel, dumble.Permission permission) {}
}
