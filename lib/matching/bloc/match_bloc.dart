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
  Timer? _pollingTimer; // Kept for cleanup consistency, though unused in new loop
  StreamSubscription? _roomSubscription;
  
  bool _isProcessing = false; 
  
  // THE FIX: Replaced int counter with DateTime for accurate tracking
  DateTime? _searchStartTime;

  String _currentRoomType = "dating";

  MatchBloc(this._repository) : super(MatchInitial()) {
    on<StartMatching>(_onStartMatching);
    on<CheckMatchStatus>(_onCheckMatchStatus);
    on<CancelMatching>(_onCancelMatching);
  }

  Future<void> _onStartMatching(StartMatching event, Emitter<MatchState> emit) async {
    emit(MatchSearching(statusMessage: "Fetching Profile..."));
    
    _searchStartTime = DateTime.now(); 
    _currentRoomType = event.roomType; 
    print("MATCH BLOC: Starting Search for $_currentRoomType"); // Debug Log

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        emit(MatchFailed("User not logged in"));
        return;
      }

      // Fetch Profile Data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        emit(MatchFailed("Profile not found. Please complete profile."));
        return;
      }

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

      // 3. Setup Real-time Listener (Kept consistent)
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
               
               if (!isClosed) {
                 emit(MatchFound(
                   sessionPath, 
                   isAi: false, 
                   partnerName: "Stranger",
                   roomType: _currentRoomType // <--- FIX 2: Pass saved room type
                 )); 
               }
            }
          });

      // 4. THE FIX: Time-Synced Awaited Loop
      _pollingTimer?.cancel();
      
      while (!isClosed && state is MatchSearching) {
        await Future.delayed(const Duration(seconds: 1));
        
        // Safety check
        if (isClosed || state is! MatchSearching) break;

        // CALCULATE REAL ELAPSED TIME
        final int elapsedSeconds = DateTime.now().difference(_searchStartTime!).inSeconds;

        // A. Update UI Status
        if (state is MatchSearching) {
           final currentAttempts = (state as MatchSearching).attemptCount;
           emit(MatchSearching(
             statusMessage: "Searching... (${elapsedSeconds}s)", 
             attemptCount: currentAttempts
           ));
        }

        // B. PRE-WARM AI (Target: 7s)
        if (elapsedSeconds >= 7 && elapsedSeconds < 13) {
          AiClusterManager().init(); 
        }

        // C. GHOST PROTOCOL (AI Fallback at 13s)
        if (elapsedSeconds >= 13 && !_isProcessing) {
          _triggerAiFallback(
            emit, 
            userData, 
            _currentRoomType // <--- FIX 3: Use saved variable
          );
          return; // Exit loop
        }

        // D. REAL HUMAN SEARCH (Every 5 seconds)
        if (elapsedSeconds > 0 && elapsedSeconds % 5 == 0 && !_isProcessing) {
           _repository.keepAlive();
           
           await _onCheckMatchStatus(
             CheckMatchStatus(myGender, interestedIn), 
             emit
           );
        }
      }

    } catch (e) {
      if (!emit.isDone) {
        emit(MatchFailed("Error joining queue: $e"));
      }
    }
  }

void _triggerAiFallback(Emitter<MatchState> emit, Map<String, dynamic> userData, String roomType) {
    _stopEverything();
    
    // 1. Identify who the bot should be
    final String botGender = userData['interestedIn'] ?? 'female';
    final String userGender = userData['gender'] ?? 'male';
    final String userAge = userData['age']?.toString() ?? '22';

    // 2. Leave the real queue
    _repository.leaveQueue();

    // Generate local session path
    final String fakePath = "sessions/ai_session_${DateTime.now().millisecondsSinceEpoch}";

    // 3. Pass EVERYTHING to the Found state
    emit(MatchFound(
      fakePath,
      isAi: true, 
      partnerName: "Neon",
      roomType: roomType, // This now comes from _currentRoomType passed in
      aiGender: botGender,
      userGender: userGender,
      userAge: userAge,
    ));
  }

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
        // FIX 4: Pass saved room type here too
        emit(MatchFound(
          sessionPath, 
          isAi: false, 
          roomType: _currentRoomType
        ));
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
          // FIX 5: And here
          emit(MatchFound(
            activeSessionQuery.docs.first.reference.path, 
            isAi: false, 
            roomType: _currentRoomType
          ));
        } else {
           // We do not update attempt count here anymore
        }
      }
    } catch (e) {
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
// import 'package:virtual_dating/services/ai/ai_cluster_manager.dart';
// import '../repository/match_repository.dart';
// import 'match_event.dart';
// import 'match_state.dart';

// class MatchBloc extends Bloc<MatchEvent, MatchState> {
//   final MatchRepository _repository;
//   Timer? _pollingTimer;
//   StreamSubscription? _roomSubscription;
  
//   bool _isProcessing = false; 
//   int _secondsWaiting = 0; // TRACKER FOR AI FALLBACK

//   MatchBloc(this._repository) : super(MatchInitial()) {
//     on<StartMatching>(_onStartMatching);
//     on<CheckMatchStatus>(_onCheckMatchStatus);
//     on<CancelMatching>(_onCancelMatching);
//   }
// Future<void> _onStartMatching(StartMatching event, Emitter<MatchState> emit) async {
//   emit(MatchSearching(statusMessage: "Fetching Profile..."));
//   _secondsWaiting = 0; 

//   try {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) {
//       emit(MatchFailed("User not logged in"));
//       return;
//     }

//     // 1. Fetch Profile Data
//     final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
//     if (!userDoc.exists) {
//       emit(MatchFailed("Profile not found. Please complete profile."));
//       return;
//     }

//     final Map<String, dynamic> userData = userDoc.data()!; 
//     final myGender = userData['gender'] ?? 'male'; 
//     final interestedIn = userData['interestedIn'] ?? 'female';

//     // 2. Join Queue
//     emit(MatchSearching(statusMessage: "Joining Queue..."));
    
//     await _repository.joinQueue(
//       myGender: myGender,
//       interestedIn: interestedIn,
//       myLevel: 1, 
//     );

//     emit(MatchSearching(statusMessage: "Searching...", attemptCount: 0));

//     // 3. Setup Real-time Listener (Kept consistent with your logic)
//     _roomSubscription?.cancel();
//     _roomSubscription = FirebaseFirestore.instance
//         .collectionGroup('sessions') 
//         .where('participants', arrayContains: uid)
//         .where('status', isEqualTo: 'active')
//         .snapshots() 
//         .listen((snapshot) {
//           if (snapshot.docs.isNotEmpty && !isClosed && !_isProcessing) {
//              final sessionPath = snapshot.docs.first.reference.path;
//              _stopEverything();
//              // Since this is a stream listener, we use add() instead of emit() 
//              // to trigger the state change from outside the main handler scope safely
//              if (!isClosed) {
//                // We add a separate event or trigger to avoid direct emit from a listener
//                // but for now, we ensure _stopEverything() is called.
//                // Note: If MatchFound is emitted here, the while loop below will break.
//              }
//           }
//         });

//     // 4. THE FIX: Industry Standard Awaited Polling Loop
//     // We cancel any old timers
//     _pollingTimer?.cancel();
    
//     // We AWAIT this loop so the handler stays alive and the 'emit' remains valid
//     while (!isClosed && state is MatchSearching) {
//       await Future.delayed(const Duration(seconds: 1));
      
//       // Safety check: if state changed via the Stream Listener above, break the loop
//       if (isClosed || state is! MatchSearching) break;

//       _secondsWaiting++;

//       // A. PRE-WARM AI (Lazy Initialization)
//       if (_secondsWaiting == 7) {
//         AiClusterManager().init(); 
//       }

//       // B. GHOST PROTOCOL (AI Fallback at 13s)
//       if (_secondsWaiting >= 13 && !_isProcessing) {
//         _triggerAiFallback(
//           emit, 
//           userData, 
//           event.roomType
//         );
//         return; // Exit the entire handler once fallback is triggered
//       }

//       // C. REAL HUMAN SEARCH (Every 5 seconds)
//       if (_secondsWaiting % 5 == 0 && !_isProcessing) {
//          _repository.keepAlive();
         
//          // Call the check logic directly using the current emit
//          // We await this so the loop pauses while checking
//          await _onCheckMatchStatus(
//            CheckMatchStatus(myGender, interestedIn), 
//            emit
//          );
//       }
//     }

//   } catch (e) {
//     if (!emit.isDone) {
//       emit(MatchFailed("Error joining queue: $e"));
//     }
//   }
// }

// void _triggerAiFallback(Emitter<MatchState> emit, Map<String, dynamic> userData, String roomType) {
//   _stopEverything();
  
//   // 1. Identify who the bot should be based on user's 'interestedIn'
//   final String botGender = userData['interestedIn'] ?? 'female';
//   final String userGender = userData['gender'] ?? 'male';
//   final String userAge = userData['age']?.toString() ?? '22';

//   // 2. Leave the real queue
//   _repository.leaveQueue();

//   // / This prevents the "Invalid document path" crash.
//   final String fakePath = "sessions/ai_session_${DateTime.now().millisecondsSinceEpoch}";

//   // 3. Pass EVERYTHING to the Found state
//   emit(MatchFound(
//     fakePath,
    
//     isAi: true, 
//     partnerName: "Neon",
//     roomType: roomType, // dating, debate, etc.
//     aiGender: botGender,
//     userGender: userGender,
//     userAge: userAge,
//   ));
// }


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
//         emit(MatchFound(sessionPath, isAi: false));
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
//           emit(MatchFound(activeSessionQuery.docs.first.reference.path, isAi: false));
//         } else {
//            if (state is MatchSearching) {
//              final currentCount = (state as MatchSearching).attemptCount;
//              emit(MatchSearching(
//                statusMessage: "Searching... ($_secondsWaiting s)", 
//                attemptCount: currentCount + 1
//              ));
//            }
//         }
//       }
//     } catch (e) {
//       // Don't kill the app on a minor polling failure
//       print("Check Status Error: $e");
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
