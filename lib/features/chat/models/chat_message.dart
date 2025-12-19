import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isSticker; 
  bool isTyped;

  ChatMessage({
    required this.id,
     
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isSticker = false,
    this.isTyped  = false,
  });

  // Factory: Converts Firebase Document -> Dart Object
  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      // Handle Server Timestamp properly
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSticker: data['isSticker'] ?? false,
    );
  }
}