import 'package:dumble/dumble.dart';

class ChatMessage {
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSelf;
  final User? sender;

  ChatMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isSelf = false,
    this.sender,
  });
}
