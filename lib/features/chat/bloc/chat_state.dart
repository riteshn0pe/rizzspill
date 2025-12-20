import '../models/chat_message.dart';
// Note: No extra imports needed, keeps consistent

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

class AiChatLoaded extends ChatState {
  final List<Map<String, dynamic>> messages;
  final double vibe;
  final double trust;
  final double tension;
  final int turn;
  
  // NEW: Tracks if this session is saved to cloud
  final bool isSynced; 

  AiChatLoaded({
    required this.messages,
    required this.vibe,
    required this.trust,
    required this.tension,
    required this.turn,
    this.isSynced = false, // Default is unsynced
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'AiChatLoaded',
      'vibe': vibe,
      'trust': trust,
      'tension': tension,
      'turn': turn,
      'isSynced': isSynced, // Save the sync status
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
      vibe: (map['vibe'] as num).toDouble(),
      trust: (map['trust'] as num).toDouble(),
      tension: (map['tension'] as num).toDouble(),
      turn: (map['turn'] as num).toInt(),
      isSynced: map['isSynced'] ?? false, // Load sync status
      messages: (map['messages'] as List).map((e) {
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


// import '../models/chat_message.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Required for Timestamp handling

// abstract class ChatState {
//   // Base serialization methods
//   Map<String, dynamic>? toJson() => null;
//   static ChatState? fromJson(Map<String, dynamic> json) {
//     try {
//       final type = json['type'];
      
//       if (type == 'AiChatLoaded') {
//         return AiChatLoaded.fromMap(json);
//       } else if (type == 'ChatLoaded') {
//         return ChatLoaded.fromMap(json);
//       }
//     } catch (_) {
//       return null; // Fallback if data is corrupted
//     }
//     return null;
//   }
// }

// class ChatInitial extends ChatState {}
// class ChatLoading extends ChatState {}

// // --- HUMAN CHAT STATE (With Persistence) ---
// class ChatLoaded extends ChatState {
//   final List<ChatMessage> messages;
//   ChatLoaded(this.messages);

//   @override
//   Map<String, dynamic> toJson() {
//     return {
//       'type': 'ChatLoaded',
//       'messages': messages.map((m) => m.toMap()).toList(),
//     };
//   }

//   static ChatLoaded fromMap(Map<String, dynamic> map) {
//     return ChatLoaded(
//       (map['messages'] as List).map((x) => ChatMessage.fromMap(x)).toList(),
//     );
//   }
// }

// // --- AI CHAT STATE (With Persistence) ---
// class AiChatLoaded extends ChatState {
//   final List<Map<String, dynamic>> messages;
//   final double vibe;
//   final double trust;
//   final double tension;
//   final int turn;

//   AiChatLoaded({
//     required this.messages,
//     required this.vibe,
//     required this.trust,
//     required this.tension,
//     required this.turn,
//   });

//   @override
//   Map<String, dynamic> toJson() {
//     return {
//       'type': 'AiChatLoaded',
//       'vibe': vibe,
//       'trust': trust,
//       'tension': tension,
//       'turn': turn,
//       'messages': messages.map((m) {
//         // Convert DateTime to ISO String for JSON safety
//         final cleanMap = Map<String, dynamic>.from(m);
//         if (cleanMap['timestamp'] is DateTime) {
//           cleanMap['timestamp'] = (cleanMap['timestamp'] as DateTime).toIso8601String();
//         }
//         return cleanMap;
//       }).toList(),
//     };
//   }

//   static AiChatLoaded fromMap(Map<String, dynamic> map) {
//     return AiChatLoaded(
//       vibe: (map['vibe'] as num).toDouble(),
//       trust: (map['trust'] as num).toDouble(),
//       tension: (map['tension'] as num).toDouble(),
//       turn: (map['turn'] as num).toInt(),
//       messages: (map['messages'] as List).map((e) {
//         final m = Map<String, dynamic>.from(e);
//         // Convert String back to DateTime
//         if (m['timestamp'] is String) {
//           m['timestamp'] = DateTime.parse(m['timestamp']);
//         }
//         return m;
//       }).toList(),
//     );
//   }
// }

// class ChatError extends ChatState {
//   final String error;
//   ChatError(this.error);
// }

// class ChatEnded extends ChatState {}
// import '../models/chat_message.dart';

// abstract class ChatState {}

// class ChatInitial extends ChatState {}

// class ChatLoading extends ChatState {}

// // --- HUMAN CHAT STATE ---
// class ChatLoaded extends ChatState {
//   final List<ChatMessage> messages;
//   ChatLoaded(this.messages);
// }

// // --- NEW: AI CHAT STATE (Step 1) ---
// class AiChatLoaded extends ChatState {
//   // We store the full list of messages and stats here
//   final List<Map<String, dynamic>> messages;
//   final double vibe;
//   final double trust;
//   final double tension;
//   final int turn;

//   AiChatLoaded({
//     required this.messages,
//     required this.vibe,
//     required this.trust,
//     required this.tension,
//     required this.turn,
//   });
// }

// class ChatError extends ChatState {
//   final String error;
//   ChatError(this.error);
// }

// class ChatEnded extends ChatState {}

// // import '../models/chat_message.dart';

// // abstract class ChatState {}

// // class ChatInitial extends ChatState {}

// // class ChatLoading extends ChatState {}

// // class ChatLoaded extends ChatState {
// //   final List<ChatMessage> messages;
// //   ChatLoaded(this.messages);
// // }

// // class ChatError extends ChatState {
// //   final String error;
// //   ChatError(this.error);
// // }

// // class ChatEnded extends ChatState {} // Navigation Trigger