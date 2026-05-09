import '../models/chat_message.dart';

abstract class ChatState {
  Map<String, dynamic>? toJson() => null;
  static ChatState? fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'];
      if (type == 'AiChatLoaded') {
        return AiChatLoaded.fromMap(json);
      } else if (type == 'ChatLoaded') {
        return ChatLoaded.fromMap(json);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  ChatLoaded(this.messages);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'ChatLoaded',
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  static ChatLoaded fromMap(Map<String, dynamic> map) {
    return ChatLoaded(
      (map['messages'] as List).map((x) => ChatMessage.fromMap(x)).toList(),
    );
  }
}

// UPDATED STATE WITH METADATA
class AiChatLoaded extends ChatState {
  final List<Map<String, dynamic>> messages;
  final double vibe;
  final double trust;
  final double tension;
  final int turn;
  final bool isSynced;
  
  // New Session Metadata
  final String roomId;
  final String partnerName;
  final String userGender;
  final String userAge;
  final String roomType;

  AiChatLoaded({
    required this.messages,
    required this.vibe,
    required this.trust,
    required this.tension,
    required this.turn,
    required this.roomId, // Crucial for session checking
    this.partnerName = "Unknown",
    this.userGender = "Unknown",
    this.userAge = "Unknown",
    this.roomType = "Unknown",
    this.isSynced = false,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'AiChatLoaded',
      'roomId': roomId,
      'partnerName': partnerName,
      'userGender': userGender,
      'userAge': userAge,
      'roomType': roomType,
      'vibe': vibe,
      'trust': trust,
      'tension': tension,
      'turn': turn,
      'isSynced': isSynced,
      'messages': messages.map((m) {
        final cleanMap = Map<String, dynamic>.from(m);
        if (cleanMap['timestamp'] is DateTime) {
          cleanMap['timestamp'] = (cleanMap['timestamp'] as DateTime).toIso8601String();
        }
        return cleanMap;
      }).toList(),
    };
  }

  static AiChatLoaded fromMap(Map<String, dynamic> map) {
    return AiChatLoaded(
      roomId: map['roomId'] ?? 'unknown_session',
      partnerName: map['partnerName'] ?? 'Unknown',
      userGender: map['userGender'] ?? 'Unknown',
      userAge: map['userAge'] ?? 'Unknown',
      roomType: map['roomType'] ?? 'Unknown',
      vibe: (map['vibe'] as num? ?? 0.3).toDouble(),
      trust: (map['trust'] as num? ?? 0.1).toDouble(),
      tension: (map['tension'] as num? ?? 0.05).toDouble(),
      turn: (map['turn'] as num? ?? 1).toInt(),
      isSynced: map['isSynced'] ?? false,
      messages: (map['messages'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e);
        if (m['timestamp'] is String) {
          m['timestamp'] = DateTime.parse(m['timestamp']);
        }
        return m;
      }).toList(),
    );
  }
}

class ChatError extends ChatState {
  final String error;
  ChatError(this.error);
}

class ChatEnded extends ChatState {}

class ChatPartnerLeft extends ChatState {
  final String? endedBy;
  ChatPartnerLeft({this.endedBy});
}
