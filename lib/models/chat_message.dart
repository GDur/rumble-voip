import 'package:rumble/src/rust/api/client.dart';

class ChatMessage {
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSelf;
  final bool isSystem;
  final MumbleUser? sender;

  ChatMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isSelf,
    this.isSystem = false,
    this.sender,
  });
}
