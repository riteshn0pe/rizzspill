import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- EXISTING HUMAN CHAT METHODS (UNCHANGED) ---

  Stream<List<ChatMessage>> getMessages(String chatPath) {
    return _firestore
        .doc(chatPath) 
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromDocument(doc))
              .toList();
        });
  }

  Future<void> sendMessage(String chatPath, String text) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .doc(chatPath) 
        .collection('messages')
        .add({
      'text': text,
      'senderId': myUid,
      'timestamp': FieldValue.serverTimestamp(),
      'isSticker': false,
    });
    
    await _firestore.doc(chatPath).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endChat(String chatPath) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _firestore.doc(chatPath).update({
      'status': 'ended',
      'endedBy': myUid,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- NEW: AI SESSION ARCHIVE (FIXED) ---

  Future<bool> archiveAiSession({
    required String roomId,
    required String partnerName,
    required String userGender,
    required String userAge,
    required String roomType,
    required List<Map<String, dynamic>> messages,
    required Map<String, double> stats,
    required int turnCount,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;

    try {
      // 1. Sanitize Room ID for Firestore
      final String safeId = roomId.replaceAll("/", "_");

      await _firestore.collection('ai_chats_archived').doc(safeId).set({
        // HEADER INFO
        'userId': myUid,
        'partnerName': partnerName,
        'userGender': userGender,
        'userAge': userAge,
        'roomType': roomType, // This writes whatever the Bloc passed to it
        
        'roomId': roomId, 
        'archivedAt': FieldValue.serverTimestamp(),
        
        // 2. STATS (CRITICAL FIX)
        // Instead of hardcoding 'vibe'/'trust', we save the entire map dynamically.
        // This ensures 'your_edge' (Debate) or 'chaos' (Random) are saved correctly.
        'finalStats': {
          ...stats, 
          'turns': turnCount,
        },

        // 3. MESSAGES
        'messages': messages.take(100).map((m) {
          final timestamp = m['timestamp'] is DateTime 
              ? Timestamp.fromDate(m['timestamp']) 
              : Timestamp.now();
          return {
            'text': m['text'],
            'isMe': m['isMe'],
            'isAction': m['isAction'] ?? false,
            'timestamp': timestamp,
          };
        }).toList(),
      }, SetOptions(merge: true)); // Merge ensures we don't overwrite if it exists
      
      return true;
    } catch (e) {
      print("Archive Failed: $e");
      return false;
    }
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/chat_message.dart';

// class ChatRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // --- EXISTING HUMAN CHAT METHODS (UNCHANGED) ---

//   Stream<List<ChatMessage>> getMessages(String chatPath) {
//     return _firestore
//         .doc(chatPath) 
//         .collection('messages')
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .map((snapshot) {
//           return snapshot.docs
//               .map((doc) => ChatMessage.fromDocument(doc))
//               .toList();
//         });
//   }

//   Future<void> sendMessage(String chatPath, String text) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     await _firestore
//         .doc(chatPath) 
//         .collection('messages')
//         .add({
//       'text': text,
//       'senderId': myUid,
//       'timestamp': FieldValue.serverTimestamp(),
//       'isSticker': false,
//     });
    
//     await _firestore.doc(chatPath).update({
//       'lastMessage': text,
//       'lastMessageTime': FieldValue.serverTimestamp(),
//     });
//   }

//   Future<void> endChat(String chatPath) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     await _firestore.doc(chatPath).update({
//       'status': 'ended',
//       'endedBy': myUid,
//       'endedAt': FieldValue.serverTimestamp(),
//     });
//   }

//   // --- NEW: AI SESSION ARCHIVE (Step 3) ---

//   Future<bool> archiveAiSession({
//     required String roomId,
//     required String partnerName,
//     required String userGender,
//     required String userAge,
//     required String roomType,
//     required List<Map<String, dynamic>> messages,
//     required Map<String, double> stats,
//     required int turnCount,
//   }) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return false;

//     try {
//       // --- THE SANITIZATION FIX ---
//       // We replace slashes with underscores. 
//       // Input: "sessions/ai_session_123" -> Output: "sessions_ai_session_123"
//       // This makes it a valid Document ID for Firestore.
//       final String safeId = roomId.replaceAll("/", "_");

//       await _firestore.collection('ai_chats_archived').doc(safeId).set({
//         // HEADER INFO (Metadata)
//         'userId': myUid,
//         'partnerName': partnerName,
//         'userGender': userGender,
//         'userAge': userAge,
//         'roomType': roomType,
        
//         'roomId': roomId, // We keep the original ID inside the data for reference
//         'archivedAt': FieldValue.serverTimestamp(),
        
//         'finalStats': {
//           'vibe': stats['vibe'],
//           'trust': stats['trust'],
//           'tension': stats['tension'],
//           'turns': turnCount,
//         },
//         'messages': messages.take(100).map((m) {
//           final timestamp = m['timestamp'] is DateTime 
//               ? Timestamp.fromDate(m['timestamp']) 
//               : Timestamp.now();
//           return {
//             'text': m['text'],
//             'isMe': m['isMe'],
//             'isAction': m['isAction'] ?? false,
//             'timestamp': timestamp,
//           };
//         }).toList(),
//       });
//       return true;
//     } catch (e) {
//       print("Archive Failed: $e");
//       return false;
//     }
//   }
// }

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/chat_message.dart';

// class ChatRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // 1. LISTEN TO MESSAGES
//   // Changed arg to 'chatPath' (e.g., "couples/A_B/sessions/xyz")
//   Stream<List<ChatMessage>> getMessages(String chatPath) {
//     return _firestore
//         .doc(chatPath) // Uses the full path directly
//         .collection('messages')
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .map((snapshot) {
//           return snapshot.docs
//               .map((doc) => ChatMessage.fromDocument(doc))
//               .toList();
//         });
//   }

//   // 2. SEND MESSAGE
//   Future<void> sendMessage(String chatPath, String text) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     await _firestore
//         .doc(chatPath) // Uses full path
//         .collection('messages')
//         .add({
//       'text': text,
//       'senderId': myUid,
//       'timestamp': FieldValue.serverTimestamp(),
//       'isSticker': false,
//     });
    
//     // Optional: Update the Session document with last message for previews
//     await _firestore.doc(chatPath).update({
//       'lastMessage': text,
//       'lastMessageTime': FieldValue.serverTimestamp(),
//     });
//   }

//   // 3. END CHAT (Soft Delete)
//   Future<void> endChat(String chatPath) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     // Soft delete just THIS session
//     await _firestore.doc(chatPath).update({
//       'status': 'ended',
//       'endedBy': myUid,
//       'endedAt': FieldValue.serverTimestamp(),
//     });
//   }
// }
