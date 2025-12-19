import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:virtual_dating/services/ai/ai_cluster_manager.dart';
import '../repository/match_repository.dart';
import 'match_event.dart';
import 'match_state.dart';

class MatchBloc extends Bloc<MatchEvent, MatchState> {
  final MatchRepository _repository;
  Timer? _pollingTimer;
  StreamSubscription? _roomSubscription;
  
  bool _isProcessing = false; 
  int _secondsWaiting = 0; // TRACKER FOR AI FALLBACK

  MatchBloc(this._repository) : super(MatchInitial()) {
    on<StartMatching>(_onStartMatching);
    on<CheckMatchStatus>(_onCheckMatchStatus);
    on<CancelMatching>(_onCancelMatching);
  }

Future<void> _onStartMatching(StartMatching event, Emitter<MatchState> emit) async {
  emit(MatchSearching(statusMessage: "Fetching Profile..."));
  _secondsWaiting = 0; // Reset timer

  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      emit(MatchFailed("User not logged in"));
      return;
    }

    // 1. Fetch Profile Data
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      emit(MatchFailed("Profile not found. Please complete profile."));
      return;
    }

    // Capture userData here so it is available in the Timer closure below
    final Map<String, dynamic> userData = userDoc.data()!; 
    final myGender = userData['gender'] ?? 'male'; 
    final interestedIn = userData['interestedIn'] ?? 'female';

    // 2. Join Queue
    emit(MatchSearching(statusMessage: "Joining Queue..."));
    
    await _repository.joinQueue(
      myGender: myGender,
      interestedIn: interestedIn,
      myLevel: 1, 
    );

    emit(MatchSearching(statusMessage: "Searching...", attemptCount: 0));

    // 3. UPDATED POLLING & HEARTBEAT + AI LOGIC
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) return;

      _secondsWaiting++;

      // A. PRE-WARM AI (Lazy Initialization)
      if (_secondsWaiting == 7) {
        AiClusterManager().init(); 
      }

      // B. GHOST PROTOCOL (AI Fallback at 13s)
      if (_secondsWaiting >= 13 && !_isProcessing) {
        // Now userData and event.roomType are correctly in scope
        _triggerAiFallback(
          emit, 
          userData, 
          event.roomType
        );
        return;
      }

      // C. REAL HUMAN SEARCH (Every 5 seconds)
      if (_secondsWaiting % 5 == 0 && !_isProcessing) {
         _repository.keepAlive();
         add(CheckMatchStatus(myGender, interestedIn));
      }
    });

    // 4. REAL-TIME LISTENER
    _roomSubscription?.cancel();
    _roomSubscription = FirebaseFirestore.instance
        .collectionGroup('sessions') 
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .snapshots() 
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && !isClosed && !_isProcessing) {
             final sessionPath = snapshot.docs.first.reference.path;
             _stopEverything();
             // Pass default parameters for human match to maintain consistency
             emit(MatchFound(
               sessionPath, 
               isAi: false,
               partnerName: "Stranger", // Or fetch partner name from session
             )); 
          }
        });

  } catch (e) {
    emit(MatchFailed("Error joining queue: $e"));
  }
}

void _triggerAiFallback(Emitter<MatchState> emit, Map<String, dynamic> userData, String roomType) {
  _stopEverything();
  
  // 1. Identify who the bot should be based on user's 'interestedIn'
  final String botGender = userData['interestedIn'] ?? 'female';
  final String userGender = userData['gender'] ?? 'male';
  final String userAge = userData['age']?.toString() ?? '22';

  // 2. Leave the real queue
  _repository.leaveQueue();

  // / This prevents the "Invalid document path" crash.
  final String fakePath = "sessions/ai_session_${DateTime.now().millisecondsSinceEpoch}";

  // 3. Pass EVERYTHING to the Found state
  emit(MatchFound(
    fakePath,
    
    isAi: true, 
    partnerName: "Neon",
    roomType: roomType, // dating, debate, etc.
    aiGender: botGender,
    userGender: userGender,
    userAge: userAge,
  ));
}

  // void _triggerAiFallback(Emitter<MatchState> emit) {
  //   _stopEverything();
    
  //   // We generate a local "Virtual Room" ID
  //   final String aiRoomId = "ai_session_${DateTime.now().millisecondsSinceEpoch}";
    
  //   // Tell the repository we are leaving the real queue because we found an AI match
  //   _repository.leaveQueue();

  //   emit(MatchFound(
  //     aiRoomId, 
  //     isAi: true, 
  //     partnerName: "Neon (AI)"
  //   ));
  // }

  Future<void> _onCheckMatchStatus(CheckMatchStatus event, Emitter<MatchState> emit) async {
    if (_isProcessing) return; 
    _isProcessing = true; 

    try {
      final sessionPath = await _repository.attemptMatch(
        myGender: event.myGender,
        interestedIn: event.interestedIn,
      );

      if (sessionPath != null) {
        _stopEverything();
        emit(MatchFound(sessionPath, isAi: false));
      } else {
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        
        final activeSessionQuery = await FirebaseFirestore.instance
            .collectionGroup('sessions') 
            .where('participants', arrayContains: myUid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
            
        if (activeSessionQuery.docs.isNotEmpty) {
          _stopEverything();
          emit(MatchFound(activeSessionQuery.docs.first.reference.path, isAi: false));
        } else {
           if (state is MatchSearching) {
             final currentCount = (state as MatchSearching).attemptCount;
             emit(MatchSearching(
               statusMessage: "Searching... ($_secondsWaiting s)", 
               attemptCount: currentCount + 1
             ));
           }
        }
      }
    } catch (e) {
      // Don't kill the app on a minor polling failure
      print("Check Status Error: $e");
    } finally {
      _isProcessing = false; 
    }
  }

  Future<void> _onCancelMatching(CancelMatching event, Emitter<MatchState> emit) async {
    _stopEverything();
    try {
      await _repository.leaveQueue();
    } catch (_) {}
    emit(MatchInitial());
  }

  void _stopEverything() {
    _pollingTimer?.cancel();
    _roomSubscription?.cancel();
    _isProcessing = false; 
  }

  @override
  Future<void> close() {
    _stopEverything();
    return super.close();
  }
}

// import 'dart:async';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../repository/match_repository.dart';
// import 'match_event.dart';
// import 'match_state.dart';

// class MatchBloc extends Bloc<MatchEvent, MatchState> {
//   final MatchRepository _repository;
//   Timer? _pollingTimer;
//   StreamSubscription? _roomSubscription;
  
//   bool _isProcessing = false; 

//   MatchBloc(this._repository) : super(MatchInitial()) {
//     on<StartMatching>(_onStartMatching);
//     on<CheckMatchStatus>(_onCheckMatchStatus);
//     on<CancelMatching>(_onCancelMatching);
//   }

// Future<void> _onStartMatching(StartMatching event, Emitter<MatchState> emit) async {
//     emit(MatchSearching(statusMessage: "Fetching Profile..."));

//     try {
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid == null) {
//         emit(MatchFailed("User not logged in"));
//         return;
//       }

//       // 1. Fetch Profile Data
//       final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
//       if (!userDoc.exists) {
//         emit(MatchFailed("Profile not found. Please complete profile."));
//         return;
//       }

//       final userData = userDoc.data()!;
//       final myGender = userData['gender'] ?? 'male'; 
//       final interestedIn = userData['interestedIn'] ?? 'female';

//       // 2. Join Queue
//       emit(MatchSearching(statusMessage: "Joining Queue..."));
      
//       await _repository.joinQueue(
//         myGender: myGender,
//         interestedIn: interestedIn,
//         myLevel: 1, 
//       );

//       emit(MatchSearching(statusMessage: "Searching...", attemptCount: 0));

//       // 3. Start Polling & Heartbeat Logic (UPDATED)
//       // We increased interval to 5s to reduce writes, but added keepAlive()
//       _pollingTimer?.cancel();
//       _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
//         if (!isClosed && !_isProcessing) {
//            // A. Send Heartbeat (Tell DB "I am still here")
//            _repository.keepAlive();

//            // B. Trigger the match check logic
//            add(CheckMatchStatus(myGender, interestedIn));
//         }
//       });

//       // 4. Start Listening Logic (Kept EXACTLY as before)
//       _roomSubscription?.cancel();
//       _roomSubscription = FirebaseFirestore.instance
//           .collectionGroup('sessions') // This uses your new Index
//           .where('participants', arrayContains: uid)
//           .where('status', isEqualTo: 'active')
//           .snapshots() 
//           .listen((snapshot) {
//             if (snapshot.docs.isNotEmpty && !isClosed && !_isProcessing) {
//                final sessionPath = snapshot.docs.first.reference.path;
//                _stopEverything();
//                emit(MatchFound(sessionPath)); 
//             }
//           });

//     } catch (e) {
//       emit(MatchFailed("Error joining queue: $e"));
//     }
//   }
  
//   Future<void> _onCheckMatchStatus(CheckMatchStatus event, Emitter<MatchState> emit) async {
//     if (_isProcessing) return; 
//     _isProcessing = true; 

//     try {
//       final sessionPath = await _repository.attemptMatch(
//         myGender: event.myGender,
//         interestedIn: event.interestedIn,
//       );

//       if (sessionPath != null) {
//         _stopEverything();
//         emit(MatchFound(sessionPath));
//       } else {
//         final myUid = FirebaseAuth.instance.currentUser?.uid;
        
//         final activeSessionQuery = await FirebaseFirestore.instance
//             .collectionGroup('sessions') 
//             .where('participants', arrayContains: myUid)
//             .where('status', isEqualTo: 'active')
//             .limit(1)
//             .get();
            
//         if (activeSessionQuery.docs.isNotEmpty) {
//           _stopEverything();
//           emit(MatchFound(activeSessionQuery.docs.first.reference.path));
//         } else {
//            if (state is MatchSearching) {
//              final currentCount = (state as MatchSearching).attemptCount;
//              emit(MatchSearching(
//                statusMessage: "Searching... (Tick: ${currentCount + 1})", 
//                attemptCount: currentCount + 1
//              ));
//            }
//         }
//       }
//     } catch (e) {
//       _stopEverything();
//       emit(MatchFailed("CRITICAL ERROR: $e")); 
//     } finally {
//       _isProcessing = false; 
//     }
//   }

//   Future<void> _onCancelMatching(CancelMatching event, Emitter<MatchState> emit) async {
//     _stopEverything();
//     try {
//       await _repository.leaveQueue();
//     } catch (_) {}
//     emit(MatchInitial());
//   }

//   void _stopEverything() {
//     _pollingTimer?.cancel();
//     _roomSubscription?.cancel();
//     _isProcessing = false; 
//   }

//   @override
//   Future<void> close() {
//     _stopEverything();
//     return super.close();
//   }
// }