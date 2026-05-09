import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Private instance (keeps it safe)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- FIX: Public Getter ---
  // This line fixes the "getter not defined" error in your Login Page.
  // It lets the UI listen to changes without accessing the private variable directly.
  GoogleSignIn get googleSignIn => _googleSignIn;

  // --- 1. AUTO-LOGIN FEATURE ---
  // Checks if user is already logged in to skip the "Sign In" button.
  Future<User?> tryAutoLogin() async {
    // Check 1: Firebase Cache
    if (_auth.currentUser != null) {
      print("Auto-Login: Firebase user already cached.");
      return _auth.currentUser;
    }

    // Check 2: Google Silent Sign-In (Background)
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        print("Auto-Login: Found Google session, re-authenticating Firebase...");
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      print("Auto-Login Failed (User must click button): $e");
    }
    return null;
  }

  // --- 2. MANUAL LOGIN (Popup) ---
  Future<User?> signInWithGoogle() async {
    try {
      print("Step 1: Triggering Popup...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print("Step 1 Result: User closed the popup (Cancelled)");
        return null;
      }

      print("Step 2: Google User found: ${googleUser.email}");
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("Step 3: Signing in to Firebase...");
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      print("Step 4: Login Success!");      

      // Firestore Logic: Create Profile if new
      if (user != null) {
        final DocumentReference userDocRef = _firestore.collection("users").doc(user.uid);
        final DocumentSnapshot documentSnapshot = await userDocRef.get();

        if (!documentSnapshot.exists) {
          print("Creating new user profile...");
          await userDocRef.set({
              'uid' : user.uid,
              'email' : user.email,
              'fullName' : user.displayName,
              'profilePic' : user.photoURL,
              'createdAt' : FieldValue.serverTimestamp(),
              'role' : 'user',
              'coins': 50, // Start with 50 Coins (Game Economy)
              'gender': null,
              'interestedIn': null,
              'age': null,   
              'level' : 1,          
          });
          print("User profile created successfully");
        } else {
          print("Welcome back, loading existing profile");
        }
      }

      return user;

    } catch (e) {
      print("CRITICAL ERROR LOG: $e");
      return null;
    }
  }

  // --- 3. SIGN OUT (Does NOT remove account from chooser) ---
  Future<void> googleSignOut() async {
    try {
      await _googleSignIn.signOut(); 
      await _auth.signOut();
      print("User signed out successfully");
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // --- 4. DISCONNECT (Removes account permission completely) ---
  Future<void> disconnectGoogle() async {
    await _googleSignIn.disconnect();
    await _auth.signOut();
  }
}


