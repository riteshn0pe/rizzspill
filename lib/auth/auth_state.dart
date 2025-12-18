sealed class AuthState {}

class AuthInitial extends AuthState {} // App just opened
class AuthLoading extends AuthState {} // Checking credentials...
class AuthAuthenticated extends AuthState {
  final String uid;
  AuthAuthenticated(this.uid);
}
class AuthUnauthenticated extends AuthState {} // User is Guest