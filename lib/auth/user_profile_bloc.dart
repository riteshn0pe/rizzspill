// lib/bloc/user_profile/user_profile_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_dating/repositories/user_repository.dart'; 
import 'user_profile_event.dart';
import 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserRepository _userRepository;

  UserProfileBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(UserProfileInitial()) {
    
    // 1. Handle Load (and Automatic Updates)
    on<LoadUserProfile>((event, emit) async {
      emit(UserProfileLoading());

      // emit.forEach is the modern way to handle Streams in Bloc.
      // It subscribes to the stream and emits a new state every time data changes.
      await emit.forEach(
        _userRepository.getUserStream(event.uid),
        onData: (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return UserProfileLoaded(snapshot.data() as Map<String, dynamic>);
          } else {
            return UserProfileError("User profile not found.");
          }
        },
        onError: (error, stackTrace) {
          return UserProfileError(error.toString());
        },
      );
    });

    // 2. Handle Logout
    on<ClearUserProfile>((event, emit) {
      // emit.forEach automatically cancels the stream above when state changes
      emit(UserProfileInitial());
    });
  }
}