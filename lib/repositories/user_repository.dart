import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  // This is the tool that talks to the database
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // METHOD 1: Fetch user data (Live Feed)
  // Purpose: Ask Firestore for the document "users/123"
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // METHOD 2: Update user data (Future Feature)
  // Purpose: Tell Firestore to change the "age" or "name"
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }
}