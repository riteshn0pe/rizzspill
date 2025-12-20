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

  // 1. Convert Object to Map (for saving)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      // Save as string ISO format for local storage safety
      'timestamp': timestamp.toIso8601String(),
      'isTyped': isTyped,
    };
  }

  // 2. Create Object from Map (for loading)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      // Handle both String (local) and Timestamp (Firestore) formats safely
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.parse(map['timestamp']),
      isTyped: map['isTyped'] ?? false,
    );
  }

}