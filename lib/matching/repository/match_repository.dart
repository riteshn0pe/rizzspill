import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. JOIN QUEUE (Updated with Heartbeat)
  Future<void> joinQueue({
    required String myGender,
    required String interestedIn,
    required int myLevel,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    await _firestore.collection('match_queue').doc(uid).set({
      'uid': uid,
      'gender': myGender,
      'interestedIn': interestedIn,
      'level': myLevel,
      'timestamp': FieldValue.serverTimestamp(), // Join Time (FIFO)
      'lastSeen': FieldValue.serverTimestamp(), // HEARTBEAT (Liveness)
      'status': 'waiting',
    });
  }

  // 2. KEEP ALIVE (New Function)
  // Call this every 10 seconds while searching
  Future<void> keepAlive() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // We use .update() so we don't overwrite the original 'timestamp'
      await _firestore.collection('match_queue').doc(uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
        // Ignore errors (if doc deleted, we just stop pinging)
        print("KeepAlive failed: $e");
      });
    }
  }

  // 3. ATTEMPT MATCH (Updated with Zombie Cleanup)
  Future<String?> attemptMatch({
    required String myGender,
    required String interestedIn,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return null;

    try {
      // Step A: Find Candidates (Fetching more to handle zombies)
      final querySnapshot = await _firestore
          .collection('match_queue')
          .where('gender', isEqualTo: interestedIn)
          .where('interestedIn', isEqualTo: myGender)
          .where('status', isEqualTo: 'waiting')
          .orderBy('timestamp', descending: false)
          .limit(20) // Fetch extra in case some are dead
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      DocumentSnapshot? targetUser;
      
      // Step B: Filter Logic (The Self-Cleaning Loop)
      for (var doc in querySnapshot.docs) {
        // 1. Skip myself
        if (doc['uid'] == myUid) continue;

        // 2. Check Liveness
        final data = doc.data() as Map<String, dynamic>;
        
        // If 'lastSeen' is missing or older than 30 seconds, it's a ZOMBIE
        if (data['lastSeen'] == null || !_isUserOnline(data['lastSeen'])) {
          print("Found Zombie User: ${doc.id} - Deleting...");
          // Delete the dead entry so no one else matches with them
          await doc.reference.delete(); 
          continue; // Skip to next candidate
        }

        // 3. Found a valid, online user!
        targetUser = doc;
        break;
      }

      if (targetUser == null) return null; // Only found zombies or myself

      // Step C: The Transaction (Standard Match Logic)
      return await _firestore.runTransaction((transaction) async {
        final freshSnap = await transaction.get(targetUser!.reference);
        
        if (!freshSnap.exists || freshSnap['status'] != 'waiting') {
           throw Exception("Match stolen or user left");
        }

        // Generate Hierarchical ID
        final List<String> pair = [myUid, targetUser.id];
        pair.sort(); 
        final coupleId = "${pair[0]}_${pair[1]}";
        final coupleRef = _firestore.collection('couples').doc(coupleId);

        // Update Couple Doc
        final coupleSnap = await transaction.get(coupleRef);
        if (!coupleSnap.exists) {
          transaction.set(coupleRef, {
            'participants': pair,
            'matchCount': 1,
            'lastMatchAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(coupleRef, {
            'matchCount': FieldValue.increment(1),
            'lastMatchAt': FieldValue.serverTimestamp(),
          });
        }

        // Create Session
        final sessionRef = coupleRef.collection('sessions').doc();
        transaction.set(sessionRef, {
          'participants': [myUid, targetUser.id],
          'status': 'active',
          'startedBy': myUid,
          'createdAt': FieldValue.serverTimestamp(),
          'fullPath': sessionRef.path, 
        });

        // Cleanup Queue
        transaction.delete(targetUser.reference);
        transaction.delete(_firestore.collection('match_queue').doc(myUid));

        return sessionRef.path; 
      });

    } catch (e) {
      print("Match Error: $e");
      return null;
    }
  }

  // Helper: Checks if timestamp is recent (within 30 seconds)
  bool _isUserOnline(Timestamp? lastSeen) {
    if (lastSeen == null) return false;
    final diff = DateTime.now().difference(lastSeen.toDate());
    return diff.inSeconds < 30; // 30s Timeout
  }

  Future<void> leaveQueue() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('match_queue').doc(uid).delete();
    }
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class MatchRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // 1. JOIN QUEUE (Unchanged - No data loss)
//   Future<void> joinQueue({
//     required String myGender,
//     required String interestedIn,
//     required int myLevel,
//   }) async {
//     final uid = _auth.currentUser?.uid;
//     if (uid == null) throw Exception("User not logged in");

//     await _firestore.collection('match_queue').doc(uid).set({
//       'uid': uid,
//       'gender': myGender,
//       'interestedIn': interestedIn,
//       'level': myLevel,
//       'timestamp': FieldValue.serverTimestamp(),
//       'status': 'waiting',
//     });
//   }

//   // 2. ATTEMPT MATCH (Updated for Hierarchical Structure)
//   Future<String?> attemptMatch({
//     required String myGender,
//     required String interestedIn,
//   }) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return null;

//     try {
//       // Step A: Find Candidates
//       final querySnapshot = await _firestore
//           .collection('match_queue')
//           .where('gender', isEqualTo: interestedIn)
//           .where('interestedIn', isEqualTo: myGender)
//           .where('status', isEqualTo: 'waiting')
//           .orderBy('timestamp', descending: false)
//           .limit(10) 
//           .get();

//       if (querySnapshot.docs.isEmpty) return null;

//       // Step B: Filter out myself
//       DocumentSnapshot? targetUser;
//       for (var doc in querySnapshot.docs) {
//         if (doc['uid'] != myUid) {
//           targetUser = doc;
//           break;
//         }
//       }

//       if (targetUser == null) return null;

//       // Step C: The Transaction
//       return await _firestore.runTransaction((transaction) async {
//         final freshSnap = await transaction.get(targetUser!.reference);
        
//         if (!freshSnap.exists || freshSnap['status'] != 'waiting') {
//            throw Exception("Match stolen by someone else");
//         }

//         // --- NEW LOGIC: PARENT COUPLE DOCUMENT ---
//         // 1. Generate Couple ID (Sorted so A_B is same as B_A)
//         final List<String> pair = [myUid, targetUser.id];
//         pair.sort(); 
//         final coupleId = "${pair[0]}_${pair[1]}";
//         final coupleRef = _firestore.collection('couples').doc(coupleId);

//         // 2. Update/Create Parent Doc (For Research Stats)
//         final coupleSnap = await transaction.get(coupleRef);
//         if (!coupleSnap.exists) {
//           transaction.set(coupleRef, {
//             'participants': pair,
//             'matchCount': 1, // First date!
//             'lastMatchAt': FieldValue.serverTimestamp(),
//           });
//         } else {
//           transaction.update(coupleRef, {
//             'matchCount': FieldValue.increment(1), // Repeat match!
//             'lastMatchAt': FieldValue.serverTimestamp(),
//           });
//         }

//         // --- NEW LOGIC: SESSION DOCUMENT ---
//         // 3. Create the specific Date Session (Random ID)
//         final sessionRef = coupleRef.collection('sessions').doc();
        
//         transaction.set(sessionRef, {
//           'participants': [myUid, targetUser.id],
//           'status': 'active', // Only this session is active
//           'startedBy': myUid,
//           'createdAt': FieldValue.serverTimestamp(),
//           // Store this path so the other user knows where to join
//           'fullPath': sessionRef.path, 
//         });

//         // 4. Cleanup Queue
//         transaction.delete(targetUser.reference);
//         transaction.delete(_firestore.collection('match_queue').doc(myUid));

//         // RETURN THE FULL PATH (e.g., "couples/A_B/sessions/xyz")
//         return sessionRef.path; 
//       });

//     } catch (e) {
//       throw Exception(e.toString());
//     }
//   }

//   // 3. LEAVE QUEUE (Unchanged)
//   Future<void> leaveQueue() async {
//     final uid = _auth.currentUser?.uid;
//     if (uid != null) {
//       await _firestore.collection('match_queue').doc(uid).delete();
//     }
//   }
// }
