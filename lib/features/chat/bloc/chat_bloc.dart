import 'dart:async';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../repository/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messageSubscription;

  // --- 1. LOCAL STATE ---
  List<Map<String, dynamic>> _aiMessages = [];
  
  // DYNAMIC STATS MAP (Replaces old _vibe, _trust, _tension)
  Map<String, dynamic> _stats = {}; 

  int _turn = 1;
  bool _isSynced = false;
  
  // Metadata for Session
  String _currentRoomId = "";
  String _partnerName = "";
  String _userGender = "";
  String _userAge = "";
  String _roomType = "";

  ChatBloc(this._repository) : super(ChatInitial()) {
    // Human Chat Handlers
    on<LoadMessages>(_onLoadMessages);
    on<UpdateMessages>(_onUpdateMessages);
    on<SendMessage>(_onSendMessage);
    on<EndChat>(_onEndChat);
    
    // AI Chat Handlers
    on<StartAiSession>(_onStartAiSession);
    on<AddAiMessage>(_onAddAiMessage);
    on<UpdateAiStats>(_onUpdateAiStats);
  }

  // --- 2. FROM JSON ---
  @override
  ChatState? fromJson(Map<String, dynamic> json) {
    try {
      final state = ChatState.fromJson(json);
      if (state is AiChatLoaded) {
        _aiMessages = List.from(state.messages);
        
        // RESTORE MAP directly from state
        _stats = Map<String, dynamic>.from(state.stats);
        
        _turn = state.turn;
        _isSynced = state.isSynced;
        _currentRoomId = state.roomId;
        _partnerName = state.partnerName;
        _userGender = state.userGender;
        _userAge = state.userAge;
        _roomType = state.roomType;
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(ChatState state) => state.toJson();

  // --- LOGIC ---

  void _onStartAiSession(StartAiSession event, Emitter<ChatState> emit) {
    // 1. CHECK FOR NEW SESSION
    if (_currentRoomId != event.roomId) {
      
      // --- RESCUE LOGIC: Sync old data before wiping ---
      if (!_isSynced && _aiMessages.isNotEmpty) {
        final oldDataSnapshot = {
          'roomId': _currentRoomId,
          'partnerName': _partnerName,
          'userGender': _userGender,
          'userAge': _userAge,
          'roomType': _roomType,
          'messages': List<Map<String, dynamic>>.from(_aiMessages), 
          // Save the map snapshot
          'stats': Map<String, dynamic>.from(_stats), 
          'turn': _turn,
        };
        _performRescueSync(oldDataSnapshot);
      }

      // RESET FOR NEW SESSION
      _aiMessages = [];
      _turn = 1; 
      _isSynced = false;
      
      _currentRoomId = event.roomId;
      _partnerName = event.partnerName;
      _userGender = event.userGender;
      _userAge = event.userAge;
      _roomType = event.roomType;

      // Initialize dynamic stats for the new room
      _initializeDefaultStats(event.roomType);
    } 
    else {
      // Resume Existing Session
      if (!_isSynced && _aiMessages.isNotEmpty) {
        _attemptBackgroundSync(); 
      }
    }

    _emitLoaded(emit);
  }

Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
    if (state is AiChatLoaded) {
      // FIX: Convert dynamic map to strict double map for Repository
      final strictStats = _stats.map((key, value) => MapEntry(key, (value as num).toDouble()));

      final success = await _repository.archiveAiSession(
        roomId: event.roomId,
        partnerName: _partnerName,
        userGender: _userGender,
        userAge: _userAge,
        roomType: _roomType,
        messages: _aiMessages,
        stats: strictStats, // <--- PASSED SAFELY
        turnCount: _turn,
      );
      
      if (success) {
        clear();
        emit(ChatEnded());
      } else {
        _isSynced = false;
        _emitLoaded(emit);
        emit(ChatEnded()); 
      }
    } else {
      // ... Human logic (unchanged) ...
      try { await _repository.endChat(event.roomId); clear(); emit(ChatEnded()); } 
      catch (e) { emit(ChatError("Failed to end chat: $e")); }
    }
  }

  void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
    _aiMessages.insert(0, event.message);
    _isSynced = false;
    _emitLoaded(emit);
  }

  void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
    // Merge new stats into existing stats map
    _stats.addAll(event.newStats);
    
    if (event.turn != null) _turn = event.turn!;
    _emitLoaded(emit);
  }

  void _emitLoaded(Emitter<ChatState> emit) {
    emit(AiChatLoaded(
      messages: List.from(_aiMessages),
      stats: Map<String, dynamic>.from(_stats), // Pass copy of the map
      turn: _turn,
      isSynced: _isSynced,
      roomId: _currentRoomId,
      partnerName: _partnerName,
      userGender: _userGender,
      userAge: _userAge,
      roomType: _roomType,
    ));
  }

  // --- HELPERS ---

  // Set Defaults based on Room Type (This is the only NEW helper method)
  void _initializeDefaultStats(String type) {
    switch (type.toLowerCase()) {
      case 'debate':
        _stats = {'your_edge': 0.5, 'their_edge': 0.5};
        break;
      case 'confession':
        _stats = {'vulnerability': 0.1, 'connection': 0.1, 'reciprocity': 0.0};
        break;
      case 'random':
        _stats = {'chaos': 0.1, 'laugh': 0.0, 'weirdness': 0.1};
        break;
      case 'dating':
      default:
        _stats = {'chemistry': 0.3, 'trust': 0.1, 'tension': 0.1};
        break;
    }
  }

  // Helper for background retry (Standard Resume)
Future<void> _attemptBackgroundSync() async {
    final String syncId = _currentRoomId.isNotEmpty ? _currentRoomId : "restored_${DateTime.now().millisecondsSinceEpoch}";
    
    // FIX: Convert to strict doubles
    final strictStats = _stats.map((key, value) => MapEntry(key, (value as num).toDouble()));

    final success = await _repository.archiveAiSession(
      roomId: syncId, 
      partnerName: _partnerName, 
      userGender: _userGender,   
      userAge: _userAge,         
      roomType: _roomType,       
      messages: _aiMessages,     
      stats: strictStats, // <--- PASSED SAFELY
      turnCount: _turn,
    );

    if (success) _isSynced = true;
  }

  Future<void> _performRescueSync(Map<String, dynamic> snapshot) async {
    // FIX: Convert snapshot stats to strict doubles
    final rawStats = snapshot['stats'] as Map<String, dynamic>;
    final strictStats = rawStats.map((key, value) => MapEntry(key, (value as num).toDouble()));

    final success = await _repository.archiveAiSession(
      roomId: snapshot['roomId'],
      partnerName: snapshot['partnerName'],
      userGender: snapshot['userGender'],
      userAge: snapshot['userAge'],
      roomType: snapshot['roomType'],
      messages: snapshot['messages'],
      stats: strictStats, // <--- PASSED SAFELY
      turnCount: snapshot['turn'],
    );
    
    if (success) print("[BLOC] ✅ Rescue Sync Success");
  }


  // --- HUMAN CHAT LOAD LOGIC (Existing - Preserved) ---
  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
    if (state is! ChatLoaded) emit(ChatLoading());
    _messageSubscription?.cancel();
    _messageSubscription = _repository.getMessages(event.roomId).listen(
      (messages) => add(UpdateMessages(messages)),
      onError: (error) => print("Stream Error: $error"),
    );
  }

  void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages as List<ChatMessage>));
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    try { 
      await _repository.sendMessage(event.roomId, event.text); 
    } catch (e) { 
      print("Send failed: $e"); 
    }
  }
}

// import 'dart:async';
// import 'package:hydrated_bloc/hydrated_bloc.dart';
// import '../repository/chat_repository.dart';
// import '../models/chat_message.dart';
// import 'chat_event.dart';
// import 'chat_state.dart';
// class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
//   final ChatRepository _repository;
//   StreamSubscription? _messageSubscription;

//   // --- 1. LOCAL STATE (MODIFIED) ---
//   List<Map<String, dynamic>> _aiMessages = [];
  
//   // REPLACED: _vibe, _trust, _tension with a single Map
//   Map<String, dynamic> _stats = {}; 

//   int _turn = 1;
//   bool _isSynced = false;
  
//   // Metadata for Session
//   String _currentRoomId = "";
//   String _partnerName = "";
//   String _userGender = "";
//   String _userAge = "";
//   String _roomType = "";

//   ChatBloc(this._repository) : super(ChatInitial()) {
//     on<LoadMessages>(_onLoadMessages);
//     on<UpdateMessages>(_onUpdateMessages);
//     on<SendMessage>(_onSendMessage);
//     on<EndChat>(_onEndChat);
    
//     // AI Handlers
//     on<StartAiSession>(_onStartAiSession);
//     on<AddAiMessage>(_onAddAiMessage);
//     on<UpdateAiStats>(_onUpdateAiStats);
//   }

//   // --- 2. FROM JSON (MODIFIED) ---
//   @override
//   ChatState? fromJson(Map<String, dynamic> json) {
//     try {
//       final state = ChatState.fromJson(json);
//       if (state is AiChatLoaded) {
//         _aiMessages = List.from(state.messages);
        
//         // RESTORE MAP directly from state
//         _stats = Map<String, dynamic>.from(state.stats);
        
//         _turn = state.turn;
//         _isSynced = state.isSynced;
//         _currentRoomId = state.roomId;
//         _partnerName = state.partnerName;
//         _userGender = state.userGender;
//         _userAge = state.userAge;
//         _roomType = state.roomType;
//       }
//       return state;
//     } catch (_) {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic>? toJson(ChatState state) => state.toJson();

//   // --- LOGIC ---

// void _onStartAiSession(StartAiSession event, Emitter<ChatState> emit) {
//     // 1. CHECK FOR NEW SESSION
//     if (_currentRoomId != event.roomId) {
      
//       // --- RESCUE LOGIC: Sync old data before wiping ---
//       if (!_isSynced && _aiMessages.isNotEmpty) {
//         final oldDataSnapshot = {
//           'roomId': _currentRoomId,
//           'partnerName': _partnerName,
//           'userGender': _userGender,
//           'userAge': _userAge,
//           'roomType': _roomType,
//           'messages': List<Map<String, dynamic>>.from(_aiMessages), 
//           // UPDATED: Save the map
//           'stats': Map<String, dynamic>.from(_stats), 
//           'turn': _turn,
//         };
//         _performRescueSync(oldDataSnapshot);
//       }

//       // RESET FOR NEW SESSION
//       _aiMessages = [];
//       _turn = 1; 
//       _isSynced = false;
      
//       _currentRoomId = event.roomId;
//       _partnerName = event.partnerName;
//       _userGender = event.userGender;
//       _userAge = event.userAge;
//       _roomType = event.roomType;

//       // UPDATED: Initialize dynamic stats
//       _initializeDefaultStats(event.roomType);
//     } 
//     else {
//       // Resume Existing Session
//       if (!_isSynced && _aiMessages.isNotEmpty) {
//         _attemptBackgroundSync(); 
//       }
//     }

//     _emitLoaded(emit);
//   }

//   Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
//     if (state is AiChatLoaded) {
//       final success = await _repository.archiveAiSession(
//         roomId: event.roomId,
//         partnerName: _partnerName,
//         userGender: _userGender,
//         userAge: _userAge,
//         roomType: _roomType,
//         messages: _aiMessages,
//         stats: {'vibe': _vibe, 'trust': _trust, 'tension': _tension},
//         turnCount: _turn,
//       );
      
//       if (success) {
//         clear(); // Clear storage on success
//         emit(ChatEnded());
//       } else {
//         _isSynced = false;
//         // Update state to save unsynced flag to disk
//         _emitLoaded(emit); 
//         emit(ChatEnded()); 
//       }
//     } else {
//       // Human Chat Logic
//       try {
//         await _repository.endChat(event.roomId);
//         clear();
//         emit(ChatEnded()); 
//       } catch (e) {
//         emit(ChatError("Failed to end chat: $e"));
//       }
//     }
//   }

//   // --- NEW HELPER: Set Defaults based on Room Type ---
//   void _initializeDefaultStats(String type) {
//     switch (type.toLowerCase()) {
//       case 'debate':
//         _stats = {'your_edge': 0.5, 'their_edge': 0.5};
//         break;
//       case 'confession':
//         _stats = {'vulnerability': 0.1, 'connection': 0.1, 'reciprocity': 0.0};
//         break;
//       case 'random':
//         _stats = {'chaos': 0.1, 'laugh': 0.0, 'weirdness': 0.1};
//         break;
//       case 'dating':
//       default:
//         _stats = {'chemistry': 0.3, 'trust': 0.1, 'tension': 0.1};
//         break;
//     }
//   }

//   // Helper for background retry (Standard Resume)
//   Future<void> _attemptBackgroundSync() async {
//     final String syncId = _currentRoomId.isNotEmpty 
//         ? _currentRoomId 
//         : "restored_${DateTime.now().millisecondsSinceEpoch}";

//     final success = await _repository.archiveAiSession(
//       roomId: syncId, 
//       partnerName: _partnerName, 
//       userGender: _userGender,   
//       userAge: _userAge,         
//       roomType: _roomType,       
//       messages: _aiMessages,     
//       stats: {'vibe': _vibe, 'trust': _trust, 'tension': _tension},
//       turnCount: _turn,
//     );

//     if (success) _isSynced = true;
//   }

//   // NEW: Handles syncing of data that has already been wiped from state variables
//   Future<void> _performRescueSync(Map<String, dynamic> snapshot) async {
//     final success = await _repository.archiveAiSession(
//       roomId: snapshot['roomId'],
//       partnerName: snapshot['partnerName'],
//       userGender: snapshot['userGender'],
//       userAge: snapshot['userAge'],
//       roomType: snapshot['roomType'],
//       messages: snapshot['messages'],
//       stats: {
//         'vibe': snapshot['vibe'], 
//         'trust': snapshot['trust'], 
//         'tension': snapshot['tension']
//       },
//       turnCount: snapshot['turn'],
//     );
    
//     if (success) {
//       print("[BLOC] ✅ Rescue Sync Success for ${snapshot['roomId']}");
//     }
//   }

//   void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
//     _aiMessages.insert(0, event.message);
//     _isSynced = false;
//     _emitLoaded(emit);
//   }

// void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
//     // UPDATED: Merge new stats into existing stats map
//     // This allows partial updates (e.g. only updating "tension" while keeping "trust")
//     _stats.addAll(event.newStats);
    
//     if (event.turn != null) _turn = event.turn!;
//     _emitLoaded(emit);
//   }

// void _emitLoaded(Emitter<ChatState> emit) {
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       // UPDATED: Pass copy of the map
//       stats: Map<String, dynamic>.from(_stats), 
//       turn: _turn,
//       isSynced: _isSynced,
//       roomId: _currentRoomId,
//       partnerName: _partnerName,
//       userGender: _userGender,
//       userAge: _userAge,
//       roomType: _roomType,
//     ));
//   }

//   // Helper for background retry
//   Future<void> _attemptBackgroundSync() async {
//     final String syncId = _currentRoomId.isNotEmpty 
//         ? _currentRoomId 
//         : "restored_${DateTime.now().millisecondsSinceEpoch}";

//     final success = await _repository.archiveAiSession(
//       roomId: syncId, 
//       partnerName: _partnerName, 
//       userGender: _userGender,   
//       userAge: _userAge,         
//       roomType: _roomType,       
//       messages: _aiMessages,     
//       // UPDATED: Pass the map
//       stats: _stats, 
//       turnCount: _turn,
//     );

//     if (success) _isSynced = true;
//   }

//   // Rescue Sync
//   Future<void> _performRescueSync(Map<String, dynamic> snapshot) async {
//     final success = await _repository.archiveAiSession(
//       roomId: snapshot['roomId'],
//       partnerName: snapshot['partnerName'],
//       userGender: snapshot['userGender'],
//       userAge: snapshot['userAge'],
//       roomType: snapshot['roomType'],
//       messages: snapshot['messages'],
//       // UPDATED: Pass the map
//       stats: snapshot['stats'],
//       turnCount: snapshot['turn'],
//     );
    
//     if (success) {
//       print("[BLOC] ✅ Rescue Sync Success for ${snapshot['roomId']}");
//     }
//   }

//   // ... Human Load Logic ...
//   void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
//     if (state is! ChatLoaded) emit(ChatLoading());
//     _messageSubscription?.cancel();
//     _messageSubscription = _repository.getMessages(event.roomId).listen(
//       (messages) => add(UpdateMessages(messages)),
//       onError: (error) => print("Stream Error: $error"),
//     );
//   }
//   void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoaded(event.messages as List<ChatMessage>));
//   }
//   Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
//     try { await _repository.sendMessage(event.roomId, event.text); } catch (e) { print("Send failed: $e"); }
//   }
// }

// import 'dart:async';
// import 'package:hydrated_bloc/hydrated_bloc.dart';
// import '../repository/chat_repository.dart';
// import '../models/chat_message.dart';
// import 'chat_event.dart';
// import 'chat_state.dart';

// class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
//   final ChatRepository _repository;
//   StreamSubscription? _messageSubscription;

//   // Local State
//   List<Map<String, dynamic>> _aiMessages = [];
//   double _vibe = 0.3;
//   double _trust = 0.1;
//   double _tension = 0.05;
//   int _turn = 1;
//   bool _isSynced = false;
  
//   // Metadata for Session
//   String _currentRoomId = "";
//   String _partnerName = "";
//   String _userGender = "";
//   String _userAge = "";
//   String _roomType = "";

//   ChatBloc(this._repository) : super(ChatInitial()) {
//     on<LoadMessages>(_onLoadMessages);
//     on<UpdateMessages>(_onUpdateMessages);
//     on<SendMessage>(_onSendMessage);
//     on<EndChat>(_onEndChat);
    
//     // RENAMED HANDLER
//     on<StartAiSession>(_onStartAiSession);
//     on<AddAiMessage>(_onAddAiMessage);
//     on<UpdateAiStats>(_onUpdateAiStats);
//   }

//   @override
//   ChatState? fromJson(Map<String, dynamic> json) {
//     try {
//       final state = ChatState.fromJson(json);
//       if (state is AiChatLoaded) {
//         _aiMessages = List.from(state.messages);
//         _vibe = state.vibe;
//         _trust = state.trust;
//         _tension = state.tension;
//         _turn = state.turn;
//         _isSynced = state.isSynced;
        
//         // Restore Metadata
//         _currentRoomId = state.roomId;
//         _partnerName = state.partnerName;
//         _userGender = state.userGender;
//         _userAge = state.userAge;
//         _roomType = state.roomType;
//       }
//       return state;
//     } catch (_) {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic>? toJson(ChatState state) => state.toJson();

//   // --- LOGIC ---

//   void _onStartAiSession(StartAiSession event, Emitter<ChatState> emit) {
//     // 1. SESSION CHECK (The Fix)
//     // If the room ID requested is DIFFERENT from the saved one, we must RESET.
//     if (_currentRoomId != event.roomId) {
//       // New Session -> Clear old data
//       _aiMessages = [];
//       _vibe = 0.3; _trust = 0.1; _tension = 0.05; _turn = 1; _isSynced = false;
      
//       // Update Metadata
//       _currentRoomId = event.roomId;
//       _partnerName = event.partnerName;
//       _userGender = event.userGender;
//       _userAge = event.userAge;
//       _roomType = event.roomType;
//     } 
//     else {
//       // Same Session -> Resume (Future WhatsApp feature)
//       // Check if we need to background sync previous failure
//       if (!_isSynced && _aiMessages.isNotEmpty) {
//         _attemptBackgroundSync();
//       }
//     }

//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//       isSynced: _isSynced,
//       // Pass metadata to state
//       roomId: _currentRoomId,
//       partnerName: _partnerName,
//       userGender: _userGender,
//       userAge: _userAge,
//       roomType: _roomType,
//     ));
//   }

//   Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
//     if (state is AiChatLoaded) {
//       final success = await _repository.archiveAiSession(
//         roomId: event.roomId,
//         // PASS METADATA TO REPOSITORY
//         partnerName: _partnerName,
//         userGender: _userGender,
//         userAge: _userAge,
//         roomType: _roomType,
//         messages: _aiMessages,
//         stats: {'vibe': _vibe, 'trust': _trust, 'tension': _tension},
//         turnCount: _turn,
//       );
      
//       if (success) {
//         clear(); // Clear storage on success
//         emit(ChatEnded());
//       } else {
//         _isSynced = false;
//         // Save failure state to disk
//         emit(AiChatLoaded(
//           messages: List.from(_aiMessages), 
//           vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//           isSynced: false,
//           roomId: _currentRoomId, partnerName: _partnerName,
//           userGender: _userGender, userAge: _userAge, roomType: _roomType,
//         ));
//         emit(ChatEnded()); 
//       }
//     } else {
//       // Human Chat Logic
//       try {
//         await _repository.endChat(event.roomId);
//         clear();
//         emit(ChatEnded()); 
//       } catch (e) {
//         emit(ChatError("Failed to end chat: $e"));
//       }
//     }
//   }

// // Helper for quiet background retry
// // Helper for quiet background retry
//   // FIXED: No arguments needed. Uses class variables directly.
//   Future<void> _attemptBackgroundSync() async {
//     // 1. Use the REAL Room ID from the loaded class variable
//     final String syncId = _currentRoomId.isNotEmpty 
//         ? _currentRoomId 
//         : "restored_session_${DateTime.now().millisecondsSinceEpoch}";

//     final success = await _repository.archiveAiSession(
//       roomId: syncId, 
//       partnerName: _partnerName, // Use class var
//       userGender: _userGender,   // Use class var
//       userAge: _userAge,         // Use class var
//       roomType: _roomType,       // Use class var
//       messages: _aiMessages,     // Use class var
//       stats: {
//         'vibe': _vibe, 
//         'trust': _trust, 
//         'tension': _tension
//       },
//       turnCount: _turn,
//     );

//     if (success) {
//       _isSynced = true;
//     }
//   }

//   void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
//     _aiMessages.insert(0, event.message);
//     _isSynced = false;
//     _emitLoaded(emit);
//   }

//   void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
//     if (event.vibe != null) _vibe = event.vibe!;
//     if (event.trust != null) _trust = event.trust!;
//     if (event.tension != null) _tension = event.tension!;
//     if (event.turn != null) _turn = event.turn!;
//     _emitLoaded(emit);
//   }

//   void _emitLoaded(Emitter<ChatState> emit) {
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//       isSynced: _isSynced,
//       roomId: _currentRoomId,
//       partnerName: _partnerName,
//       userGender: _userGender,
//       userAge: _userAge,
//       roomType: _roomType,
//     ));
//   }

//   // ... Human Load Logic remains unchanged ...
//   void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
//     if (state is! ChatLoaded) emit(ChatLoading());
//     _messageSubscription?.cancel();
//     _messageSubscription = _repository.getMessages(event.roomId).listen(
//       (messages) => add(UpdateMessages(messages)),
//       onError: (error) => print("Stream Error: $error"),
//     );
//   }
//   void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoaded(event.messages as List<ChatMessage>));
//   }
//   Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.sendMessage(event.roomId, event.text);
//     } catch (e) { print("Send failed: $e"); }
//   }
// }


// import 'dart:async';
// import 'package:hydrated_bloc/hydrated_bloc.dart';
// import '../repository/chat_repository.dart';
// import '../models/chat_message.dart';
// import 'chat_event.dart';
// import 'chat_state.dart';

// class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
//   final ChatRepository _repository;
//   StreamSubscription? _messageSubscription;

//   // Local State Storage
//   List<Map<String, dynamic>> _aiMessages = [];
//   double _vibe = 0.3;
//   double _trust = 0.1;
//   double _tension = 0.05;
//   int _turn = 1;
  
//   // NEW: Internal tracker for sync status (Step 3)
//   bool _isSynced = false; 

//   ChatBloc(this._repository) : super(ChatInitial()) {
//     // Human Handlers
//     on<LoadMessages>(_onLoadMessages);
//     on<UpdateMessages>(_onUpdateMessages);
//     on<SendMessage>(_onSendMessage);
//     on<EndChat>(_onEndChat);
    
//     // AI Handlers
//     on<InitAiChat>(_onInitAiChat);
//     on<AddAiMessage>(_onAddAiMessage);
//     on<UpdateAiStats>(_onUpdateAiStats);
//   }

//   // --- PERSISTENCE METHODS ---
  
//   @override
//   ChatState? fromJson(Map<String, dynamic> json) {
//     try {
//       final state = ChatState.fromJson(json);
      
//       // Restore local variables from disk so memory matches state
//       if (state is AiChatLoaded) {
//         _aiMessages = List.from(state.messages);
//         _vibe = state.vibe;
//         _trust = state.trust;
//         _tension = state.tension;
//         _turn = state.turn;
//         _isSynced = state.isSynced; // Restore sync status
//       }
//       return state;
//     } catch (_) {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic>? toJson(ChatState state) {
//     return state.toJson();
//   }

//   // --- HUMAN LOGIC ---

//   void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
//     // Show loading only if we don't have cached data
//     if (state is! ChatLoaded) emit(ChatLoading());
    
//     _messageSubscription?.cancel();
//     _messageSubscription = _repository.getMessages(event.roomId).listen(
//       (messages) => add(UpdateMessages(messages)),
//       onError: (error) => print("Stream Error: $error"),
//     );
//   }

//   void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoaded(event.messages as List<ChatMessage>));
//   }

//   Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.sendMessage(event.roomId, event.text);
//     } catch (e) {
//       print("Send failed: $e"); 
//     }
//   }

//   Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
//     // 1. AI CHAT LOGIC: Archive to Cloud
//     if (state is AiChatLoaded) {
//       final success = await _repository.archiveAiSession(
//         roomId: event.roomId,
//         partnerName: "Neon", // Could be dynamic based on your logic
//         messages: _aiMessages,
//         stats: {'vibe': _vibe, 'trust': _trust, 'tension': _tension},
//         turnCount: _turn,
//       );
      
//       if (success) {
//         // SUCCESS: Clear local storage as it is safely in Cloud
//         clear(); 
//         emit(ChatEnded());
//       } else {
//         // FAILURE (Offline): Keep local storage, mark unsynced
//         _isSynced = false;
        
//         // Update state to save the 'isSynced: false' flag to disk
//         emit(AiChatLoaded(
//           messages: List.from(_aiMessages), 
//           vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//           isSynced: false
//         ));
        
//         // End the session UI-wise so user isn't stuck
//         emit(ChatEnded()); 
//       }
//     } 
//     // 2. HUMAN CHAT LOGIC: Standard End
//     else {
//       try {
//         await _repository.endChat(event.roomId);
//         clear(); // Clear local cache for human chat
//         emit(ChatEnded()); 
//       } catch (e) {
//         emit(ChatError("Failed to end chat: $e"));
//       }
//     }
//   }

//   // --- AI LOGIC ---

//   void _onInitAiChat(InitAiChat event, Emitter<ChatState> emit) {
//     // 1. BACKGROUND SYNC CHECK (Step 3)
//     // If we loaded an old session that wasn't synced, retry now quietly.
//     if (state is AiChatLoaded) {
//       final currentState = state as AiChatLoaded;
//       if (!currentState.isSynced && currentState.messages.isNotEmpty) {
//         _attemptBackgroundSync(currentState);
//       }
//       return; // Already loaded from disk
//     }

//     // 2. FRESH START
//     if (_aiMessages.isEmpty) {
//       _vibe = 0.3; _trust = 0.1; _tension = 0.05; _turn = 1; _isSynced = false;
//     }
    
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//       isSynced: _isSynced
//     ));
//   }

//   // Helper: Tries to upload without blocking UI
//   Future<void> _attemptBackgroundSync(AiChatLoaded currentState) async {
//     // We use a generated ID or the stored ID if you tracked it.
//     // This is a "Best Effort" retry.
//     final success = await _repository.archiveAiSession(
//       roomId: "restored_session_${DateTime.now().millisecondsSinceEpoch}", 
//       partnerName: "Neon",
//       messages: currentState.messages,
//       stats: {'vibe': currentState.vibe, 'trust': currentState.trust, 'tension': currentState.tension},
//       turnCount: currentState.turn,
//     );

//     if (success) {
//       _isSynced = true;
//       // We don't emit here to avoid UI flicker, but next update will save true.
//     }
//   }

//   void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
//     _aiMessages.insert(0, event.message);
//     _isSynced = false; // New content means we are dirty/unsynced
    
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages), 
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//       isSynced: false
//     ));
//   }

//   void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
//     if (event.vibe != null) _vibe = event.vibe!;
//     if (event.trust != null) _trust = event.trust!;
//     if (event.tension != null) _tension = event.tension!;
//     if (event.turn != null) _turn = event.turn!;

//     // Stats change also marks us as unsynced
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
//       isSynced: false 
//     ));
//   }

//   @override
//   Future<void> close() {
//     _messageSubscription?.cancel();
//     return super.close();
//   }
// }

// import 'dart:async';
// import 'package:hydrated_bloc/hydrated_bloc.dart'; // CHANGED IMPORT
// import '../repository/chat_repository.dart';
// import '../models/chat_message.dart';
// import 'chat_event.dart';
// import 'chat_state.dart';

// // CHANGED: Extends HydratedBloc instead of Bloc
// class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
//   final ChatRepository _repository;
//   StreamSubscription? _messageSubscription;

//   // Local State Storage
//   List<Map<String, dynamic>> _aiMessages = [];
//   double _vibe = 0.3;
//   double _trust = 0.1;
//   double _tension = 0.05;
//   int _turn = 1;

//   ChatBloc(this._repository) : super(ChatInitial()) {
//     on<LoadMessages>(_onLoadMessages);
//     on<UpdateMessages>(_onUpdateMessages);
//     on<SendMessage>(_onSendMessage);
//     on<EndChat>(_onEndChat);
    
//     on<InitAiChat>(_onInitAiChat);
//     on<AddAiMessage>(_onAddAiMessage);
//     on<UpdateAiStats>(_onUpdateAiStats);
//   }

//   // --- PERSISTENCE METHODS (The Magic) ---
  
//   @override
//   ChatState? fromJson(Map<String, dynamic> json) {
//     try {
//       final state = ChatState.fromJson(json);
      
//       // If we loaded an AI session, we must also restore the local variables
//       // so new messages append correctly instead of resetting.
//       if (state is AiChatLoaded) {
//         _aiMessages = List.from(state.messages);
//         _vibe = state.vibe;
//         _trust = state.trust;
//         _tension = state.tension;
//         _turn = state.turn;
//       }
//       return state;
//     } catch (_) {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic>? toJson(ChatState state) {
//     return state.toJson();
//   }

//   // --- REST OF YOUR LOGIC (Identical to Step 1) ---

//   void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
//     // We emit Loading only if we don't have cached data
//     if (state is! ChatLoaded) emit(ChatLoading());
    
//     _messageSubscription?.cancel();
//     _messageSubscription = _repository.getMessages(event.roomId).listen(
//       (messages) => add(UpdateMessages(messages)),
//       onError: (error) => print("Stream Error: $error"),
//     );
//   }

//   void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoaded(event.messages as List<ChatMessage>));
//   }

//   Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.sendMessage(event.roomId, event.text);
//     } catch (e) {
//       print("Send failed: $e"); 
//     }
//   }

//   Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.endChat(event.roomId);
//       // Clear local storage when chat ends intentionally
//       clear(); 
//       emit(ChatEnded()); 
//     } catch (e) {
//       emit(ChatError("Failed to end chat: $e"));
//     }
//   }

//   void _onInitAiChat(InitAiChat event, Emitter<ChatState> emit) {
//     // HydratedBloc handles auto-loading. 
//     // We only reset if state is NOT AiChatLoaded (fresh start)
//     if (state is AiChatLoaded) {
//       // Data already restored by fromJson! Just keep it.
//       return; 
//     }

//     if (_aiMessages.isEmpty) {
//       _vibe = 0.3; _trust = 0.1; _tension = 0.05; _turn = 1;
//     }
    
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
//     ));
//   }

//   void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
//     _aiMessages.insert(0, event.message);
//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages), 
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
//     ));
//   }

//   void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
//     if (event.vibe != null) _vibe = event.vibe!;
//     if (event.trust != null) _trust = event.trust!;
//     if (event.tension != null) _tension = event.tension!;
//     if (event.turn != null) _turn = event.turn!;

//     emit(AiChatLoaded(
//       messages: List.from(_aiMessages),
//       vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
//     ));
//   }

//   @override
//   Future<void> close() {
//     _messageSubscription?.cancel();
//     return super.close();
//   }
// }


