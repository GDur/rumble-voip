import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MumbleServer {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final bool isArchived;
  final int? lastChannelId;
  // Transient data for server list
  final int? ping;
  final int? userCount;
  final int? maxUsers;

  MumbleServer({
    String? id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password = '',
    this.isArchived = false,
    this.lastChannelId,
    this.ping,
    this.userCount,
    this.maxUsers,
  }) : id = id ?? '${host}_$port';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'isArchived': isArchived,
    'lastChannelId': lastChannelId,
    if (ping != null) 'ping': ping,
    if (userCount != null) 'userCount': userCount,
    if (maxUsers != null) 'maxUsers': maxUsers,
  };

  factory MumbleServer.fromJson(Map<String, dynamic> json) => MumbleServer(
    id: json['id'],
    name: json['name'],
    host: json['host'],
    port: json['port'],
    username: json['username'],
    password: json['password'] ?? '',
    isArchived: json['isArchived'] ?? false,
    lastChannelId: json['lastChannelId'],
    ping: json['ping'],
    userCount: json['userCount'],
    maxUsers: json['maxUsers'],
  );

  MumbleServer copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? isArchived,
    int? lastChannelId,
    int? ping,
    int? userCount,
    int? maxUsers,
  }) => MumbleServer(
    id: id,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    isArchived: isArchived ?? this.isArchived,
    lastChannelId: lastChannelId ?? this.lastChannelId,
    ping: ping ?? this.ping,
    userCount: userCount ?? this.userCount,
    maxUsers: maxUsers ?? this.maxUsers,
  );
}

String generateDefaultUsername() {
  // Use BRANCH_NAME from .env or fallback to 'RustPluginDumble'
  final branch = dotenv.env['BRANCH_NAME'] ?? 'RustPluginDumble';
  String platform;
  if (kIsWeb) {
    platform = 'Web';
  } else if (Platform.isAndroid) {
    platform = 'Android';
  } else if (Platform.isIOS) {
    platform = 'Ios';
  } else if (Platform.isMacOS) {
    platform = 'Macos';
  } else if (Platform.isWindows) {
    platform = 'Windows';
  } else if (Platform.isLinux) {
    platform = 'Linux';
  } else {
    platform = 'Unknown';
  }

  const gameNames = [
    'Glados',
    'MasterChief',
    'DoomSlayer',
    'Geralt',
    'Triss',
    'Yennefer',
    'Arthas',
    'DrStrange',
    'SonGoku',
    'Bulma',
    'Vegeta',
    'Frieza',
    'TonyStark',
    'Thor',
    'Loki',
  ];
  final randomName = gameNames[Random().nextInt(gameNames.length)];
  return 'Rumble$branch$platform$randomName';
}

final List<MumbleServer> initialServers = [];
