sealed class AuthEvent {}

// Fired automatically when the app starts
class AuthStarted extends AuthEvent {}

// Fired internally when Firebase tells us the state changed
class AuthStateChanged extends AuthEvent {
  final String? uid;
  AuthStateChanged(this.uid);
}

// Fired when user clicks Logout button
class AuthLogoutRequested extends AuthEvent {}