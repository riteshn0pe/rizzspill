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
  
  
  DateTime? _searchStartTime;

  MatchBloc(this._repository) : super(MatchInitial()) {
    on<StartMatching>(_onStartMatching);
    on<CheckMatchStatus>(_onCheckMatchStatus);
    on<CancelMatching>(_onCancelMatching);
  }

  Future<void> _onStartMatching(StartMatching event, Emitter<MatchState> emit) async {
    emit(MatchSearching(statusMessage: "Fetching Profile..."));
    
    // 1. Mark the Start Time
    _searchStartTime = DateTime.now(); 

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
               
               // We trigger the match found state. 
               // This changes the state from 'MatchSearching' to 'MatchFound',
               // which automatically breaks the while loop below.
               if (!isClosed) {
                 emit(MatchFound(
                   sessionPath, 
                   isAi: false, 
                   partnerName: "Stranger"
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
        // This handles app minimization/pausing correctly.
        final int elapsedSeconds = DateTime.now().difference(_searchStartTime!).inSeconds;

        // A. Update UI Status (Updates strictly based on real time)
        if (state is MatchSearching) {
           final currentAttempts = (state as MatchSearching).attemptCount;
           emit(MatchSearching(
             statusMessage: "Searching... (${elapsedSeconds}s)", 
             attemptCount: currentAttempts
           ));
        }

        // B. PRE-WARM AI (Target: 7s)
        // Using a range ensures we catch it even if the app lagged past exactly 7s.
        if (elapsedSeconds >= 7 && elapsedSeconds < 13) {
          AiClusterManager().init(); 
        }

        // C. GHOST PROTOCOL (AI Fallback at 13s)
        if (elapsedSeconds >= 13 && !_isProcessing) {
          _triggerAiFallback(
            emit, 
            userData, 
            event.roomType
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
      roomType: roomType, 
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
           // We do not update attempt count here anymore as the main loop handles UI updates
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

