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

  // --- NEW: AI SESSION ARCHIVE (Step 3) ---
  
  /// Performs a "Single Write" to save the entire AI session to Firestore.
  /// Returns TRUE if successful, FALSE if network failed.
  Future<bool> archiveAiSession({
    required String roomId,
    required String partnerName,
    required List<Map<String, dynamic>> messages,
    required Map<String, double> stats,
    required int turnCount,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return false;

    try {
      // Create a dedicated collection for analytics/history
      // Structure: ai_chats_archived/{sessionId}
      await _firestore.collection('ai_chats_archived').doc(roomId).set({
        'userId': myUid,
        'partnerName': partnerName,
        'roomId': roomId,
        'archivedAt': FieldValue.serverTimestamp(),
        
        // Save Stats
        'finalStats': {
          'vibe': stats['vibe'],
          'trust': stats['trust'],
          'tension': stats['tension'],
          'turns': turnCount,
        },

        // Save Full History (Optimized: One Array)
        // We limit to last 100 messages to respect Firestore document size limits (1MB)
        'messages': messages.take(100).map((m) {
          // Convert DateTime to Firestore Timestamp for consistency
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
      });
      
      return true; // Sync Success
    } catch (e) {
      print("Archive Failed (Offline?): $e");
      return false; // Sync Failed (Will retry later)
    }
  }
}

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
