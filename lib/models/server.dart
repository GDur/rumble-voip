class MumbleServer {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;

  MumbleServer({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password = '',
  });
}

final List<MumbleServer> initialServers = [
  MumbleServer(
    name: 'chat.revslair.net',
    host: 'chat.revslair.net',
    port: 64738,
    username: 'Rumble - Mumble Reloaded',
  ),
  MumbleServer(
    name: 'Rogue Server',
    host: 'mumble.rogueserver.com',
    port: 64738,
    username: 'Rumble - Mumble Reloaded',
  ),
];
