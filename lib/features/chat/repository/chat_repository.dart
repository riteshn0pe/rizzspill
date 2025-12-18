import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. LISTEN TO MESSAGES
  // Changed arg to 'chatPath' (e.g., "couples/A_B/sessions/xyz")
  Stream<List<ChatMessage>> getMessages(String chatPath) {
    return _firestore
        .doc(chatPath) // Uses the full path directly
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromDocument(doc))
              .toList();
        });
  }

  // 2. SEND MESSAGE
  Future<void> sendMessage(String chatPath, String text) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .doc(chatPath) // Uses full path
        .collection('messages')
        .add({
      'text': text,
      'senderId': myUid,
      'timestamp': FieldValue.serverTimestamp(),
      'isSticker': false,
    });
    
    // Optional: Update the Session document with last message for previews
    await _firestore.doc(chatPath).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  // 3. END CHAT (Soft Delete)
  Future<void> endChat(String chatPath) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    // Soft delete just THIS session
    await _firestore.doc(chatPath).update({
      'status': 'ended',
      'endedBy': myUid,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/chat_message.dart';

// class ChatRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // 1. LISTEN TO MESSAGES (Realtime Stream)
//   Stream<List<ChatMessage>> getMessages(String roomId) {
//     return _firestore
//         .collection('rooms')
//         .doc(roomId)
//         .collection('messages') // Sub-collection query
//         .orderBy('timestamp', descending: true) // Newest first
//         .snapshots()
//         .map((snapshot) {
//           return snapshot.docs
//               .map((doc) => ChatMessage.fromDocument(doc))
//               .toList();
//         });
//   }

//   // 2. SEND MESSAGE
//   Future<void> sendMessage(String roomId, String text) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     await _firestore
//         .collection('rooms')
//         .doc(roomId)
//         .collection('messages')
//         .add({
//       'text': text,
//       'senderId': myUid,
//       'timestamp': FieldValue.serverTimestamp(),
//       'isSticker': false,
//     });
    
//     // Optional: Update parent room "lastMessage" for the home screen preview
//     await _firestore.collection('rooms').doc(roomId).update({
//       'lastMessage': text,
//       'lastMessageTime': FieldValue.serverTimestamp(),
//     });
//   }

//   // 3. END CHAT (Soft Delete / Unmatch)
//   Future<void> endChat(String roomId) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     // We DO NOT delete data. We mark it as 'ended'.
//     // This hides it from the UI but keeps it safe in DB.
//     await _firestore.collection('rooms').doc(roomId).update({
//       'status': 'ended',
//       'endedBy': myUid,
//       'endedAt': FieldValue.serverTimestamp(),
//     });
//   }
// }