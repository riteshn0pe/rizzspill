// lib/bloc/user_profile/user_profile_state.dart

sealed class UserProfileState {}

class UserProfileInitial extends UserProfileState {}

class UserProfileLoading extends UserProfileState {}

class UserProfileLoaded extends UserProfileState {
  final Map<String, dynamic> userData;

  // Helper Getters (Safety Logic)
  String get fullName => userData['fullName'] ?? 'No Name';
  String get email => userData['email'] ?? '';
  
  
  // Ensure we don't crash if profilePic is missing
  String get photoUrl => userData['profilePic'] ?? ''; 

  UserProfileLoaded(this.userData);
}

class UserProfileError extends UserProfileState {
  final String message;
  UserProfileError(this.message);
}