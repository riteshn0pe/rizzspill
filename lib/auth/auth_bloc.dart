import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:virtual_dating/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseService _authService;
  
  AuthBloc({required FirebaseService authService}) 
      : _authService = authService, 
        super(AuthInitial()) {

    // 1. App Start: Listen to the Firebase Stream
    on<AuthStarted>((event, emit) async {
      emit(AuthLoading()); // Show splash screen/spinner
      
      // emit.forEach automatically handles the stream!
      await emit.forEach(
        FirebaseAuth.instance.authStateChanges(),
        onData: (User? user) {
          if (user != null) {
            return AuthAuthenticated(user.uid);
          } else {
            return AuthUnauthenticated();
          }
        },
      );
    });

    // 2. Handle Logout
    on<AuthLogoutRequested>((event, emit) async {
      await _authService.googleSignOut();
      // The stream above will automatically fire 'AuthUnauthenticated', 
      // so we don't need to manually emit here.
    });
  }
}