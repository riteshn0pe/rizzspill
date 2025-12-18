import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:virtual_dating/auth_service.dart'; // Make sure this points to your updated FirebaseService file
import 'package:virtual_dating/my_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. Create the Service Instance
  final FirebaseService _authService = FirebaseService();
  
  // NEW: Loading state to hide the button while we check if you are already logged in
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    
    // 2. The Listener (Kept from your code)
    _authService.googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // --- NEW FEATURE: AUTO-LOGIN CHECK ---
  // This runs immediately when the app starts.
  Future<void> _checkAutoLogin() async {
    // Call the new helper we added to FirebaseService
    final User? user = await _authService.tryAutoLogin();

    if (!mounted) return;

    if (user != null) {
      // User is already logged in! Skip the button and go Home.
      print("Auto-login successful: ${user.email}");
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const MyHomePage())
      );
    } else {
      // User is NOT logged in. Stop loading and show the button.
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center( 
        child: _isLoading 
          ? const CircularProgressIndicator() // Show spinner while checking auto-login
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Your image can go here (Placeholder kept)
                // Image.asset('assets/logo.png'), 
                const SizedBox(height: 20),

                // 3. The Button
                SignInButton(
                  Buttons.google, 
                  onPressed: () async {
                    // Set loading true while the popup is open
                    setState(() => _isLoading = true);

                    // A. Call the Login Function
                    final User? user = await _authService.signInWithGoogle();

                    // B. Handle the Result
                    if (!mounted) return; 

                    if (user != null) {
                      // SUCCESS: Navigate to Home
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (context) => const MyHomePage())
                      );
                    } else {
                      // FAILURE: Show Error Message
                      setState(() => _isLoading = false); // Stop loading so they can try again
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Google Sign-In Failed or Cancelled"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                })
              ],
            ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_button/sign_in_button.dart';
// import 'package:virtual_dating/auth_service.dart';
// import 'package:virtual_dating/my_home_page.dart';


// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   // 1. Create the Service Instance
//   // Ensure the class name inside 'auth_service.dart' matches this (FirebaseService or AuthService)
//   final FirebaseService _authService = FirebaseService();

//   @override
//   void initState() {
//     super.initState();
//     // 2. The Listener
//     // We listen to the googleSignIn instance from our service to update the UI
//     _authService.googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
//       if (mounted) {
//         setState(() {
//           // Rebuild the UI if the user status changes
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center( // Added Center to make it look better
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Your image can go here
            
//             // 3. The Button
//             SignInButton(
//               Buttons.google, 
//               onPressed: () async {
//                 // Show a loading indicator (optional but good UX)
//                 // showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

//                 // A. Call the Login Function
//                 // We expect this to return a User object if successful, or null if failed
//                 final User? user = await _authService.signInWithGoogle();

//                 // B. Handle the Result
//                 if (!mounted) return; // Safety check

//                 if (user != null) {
//                   // SUCCESS: Navigate to Home
//                   Navigator.pushReplacement(
//                     context, 
//                     MaterialPageRoute(builder: (context) => const MyHomePage())
//                   );
//                 } else {
//                   // FAILURE: Show Error Message
//                   // FIX: You must use ScaffoldMessenger to actually SHOW the snackbar
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text("Google Sign-In Failed or Cancelled"),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//             })
//           ],
//         ),
//       ),
//     );
//   }
// }