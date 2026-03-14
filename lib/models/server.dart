import 'dart:convert';

class MumbleServer {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;

  MumbleServer({
    String? id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password = '',
  }) : id = id ?? '${host}_$port';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  factory MumbleServer.fromJson(Map<String, dynamic> json) => MumbleServer(
    id: json['id'],
    name: json['name'],
    host: json['host'],
    port: json['port'],
    username: json['username'],
    password: json['password'] ?? '',
  );

  MumbleServer copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
  }) => MumbleServer(
    id: id,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
  );
}

final List<MumbleServer> initialServers = [
  MumbleServer(
    name: 'chat.revslair.net',
    host: 'chat.revslair.net',
    port: 64738,
    username: 'RumbleUser',
  ),
  MumbleServer(
    name: 'Rogue Server',
    host: 'mumble.rogueserver.com',
    port: 64738,
    username: 'RumbleUser',
  ),
  MumbleServer(
    name: 'TWC Server',
    host: 'mumble.twcclan.org',
    port: 64738,
    username: 'RumbleUser',
  ),
];
