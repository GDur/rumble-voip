import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rumble/models/server.dart';

class ServerProvider extends ChangeNotifier {
  List<MumbleServer> _servers = [];
  bool _isLoading = true;

  List<MumbleServer> get servers => _servers;
  bool get isLoading => _isLoading;

  ServerProvider() {
    _loadServers();
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

  Future<void> removeServer(String id) async {
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
