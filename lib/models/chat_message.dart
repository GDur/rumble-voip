import 'package:dumble/dumble.dart';

class ChatMessage {
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSelf;
  final bool isSystem;
  final User? sender;

  ChatMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isSelf = false,
    this.isSystem = false,
    this.sender,
  });
}
