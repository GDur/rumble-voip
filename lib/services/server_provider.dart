import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/mumble_ping_service.dart';

class ServerProvider extends ChangeNotifier {
  List<MumbleServer> _servers = [];
  bool _isLoading = true;
  Timer? _pingTimer;

  List<MumbleServer> get servers => _servers;
  bool get isLoading => _isLoading;

  ServerProvider() {
    _loadServers();
    _startPeriodicPings();
  }

  void _startPeriodicPings() {
     _pingTimer?.cancel();
     _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
       refreshAllPings();
     });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadServers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? serversJson = prefs.getString('mumble_servers');
      
      if (serversJson != null) {
        final List<dynamic> decoded = jsonDecode(serversJson);
        _servers = decoded.map((item) => MumbleServer.fromJson(item)).toList();
      } else {
        _servers = List.from(initialServers);
      }
    } catch (e) {
      debugPrint('Error loading servers: $e');
      _servers = List.from(initialServers);
    } finally {
      _isLoading = false;
      notifyListeners();
      refreshAllPings();
    }
  }

  Future<void> refreshAllPings() async {
    for (int i = 0; i < _servers.length; i++) {
      _pingServer(i);
    }
  }

  Future<void> _pingServer(int index) async {
    final server = _servers[index];
    try {
      final response = await MumblePingService.ping(server.host, server.port);
      _servers[index] = _servers[index].copyWith(
        ping: response.latency,
        userCount: response.users,
        maxUsers: response.maxUsers,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Ping failed for ${server.host}: $e');
      // Optionally clear old data if it fails
      // _servers[index] = _servers[index].copyWith(ping: null);
      // notifyListeners();
    }
  }

  Future<void> _saveServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_servers.map((s) => s.toJson()).toList());
      await prefs.setString('mumble_servers', encoded);
    } catch (e) {
      debugPrint('Error saving servers: $e');
    }
  }

  Future<void> addServer(MumbleServer server) async {
    _servers.add(server);
    await _saveServers();
    notifyListeners();
  }

  Future<void> archiveServer(String id) async {
    final index = _servers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _servers[index] = _servers[index].copyWith(isArchived: true);
      await _saveServers();
      notifyListeners();
    }
  }

  Future<void> unarchiveServer(String id) async {
    final index = _servers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _servers[index] = _servers[index].copyWith(isArchived: false);
      await _saveServers();
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    await _saveServers();
    notifyListeners();
  }

  Future<void> updateServer(MumbleServer server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      _servers[index] = server;
      await _saveServers();
      notifyListeners();
    }
  }
}
