// lib/bloc/user_profile/user_profile_event.dart

sealed class UserProfileEvent {}

// Triggered when the user logs in
class LoadUserProfile extends UserProfileEvent {
  final String uid;
  LoadUserProfile(this.uid);
}

// Triggered when user logs out
class ClearUserProfile extends UserProfileEvent {}