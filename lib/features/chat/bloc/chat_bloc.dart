import 'dart:async';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../repository/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messageSubscription;

  // Local State Storage
  List<Map<String, dynamic>> _aiMessages = [];
  double _vibe = 0.3;
  double _trust = 0.1;
  double _tension = 0.05;
  int _turn = 1;
  
  // NEW: Internal tracker for sync status (Step 3)
  bool _isSynced = false; 

  ChatBloc(this._repository) : super(ChatInitial()) {
    // Human Handlers
    on<LoadMessages>(_onLoadMessages);
    on<UpdateMessages>(_onUpdateMessages);
    on<SendMessage>(_onSendMessage);
    on<EndChat>(_onEndChat);
    
    // AI Handlers
    on<InitAiChat>(_onInitAiChat);
    on<AddAiMessage>(_onAddAiMessage);
    on<UpdateAiStats>(_onUpdateAiStats);
  }

  // --- PERSISTENCE METHODS ---
  
  @override
  ChatState? fromJson(Map<String, dynamic> json) {
    try {
      final state = ChatState.fromJson(json);
      
      // Restore local variables from disk so memory matches state
      if (state is AiChatLoaded) {
        _aiMessages = List.from(state.messages);
        _vibe = state.vibe;
        _trust = state.trust;
        _tension = state.tension;
        _turn = state.turn;
        _isSynced = state.isSynced; // Restore sync status
      }
      return state;
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(ChatState state) {
    return state.toJson();
  }

  // --- HUMAN LOGIC ---

  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
    // Show loading only if we don't have cached data
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

  Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
    // 1. AI CHAT LOGIC: Archive to Cloud
    if (state is AiChatLoaded) {
      final success = await _repository.archiveAiSession(
        roomId: event.roomId,
        partnerName: "Neon", // Could be dynamic based on your logic
        messages: _aiMessages,
        stats: {'vibe': _vibe, 'trust': _trust, 'tension': _tension},
        turnCount: _turn,
      );
      
      if (success) {
        // SUCCESS: Clear local storage as it is safely in Cloud
        clear(); 
        emit(ChatEnded());
      } else {
        // FAILURE (Offline): Keep local storage, mark unsynced
        _isSynced = false;
        
        // Update state to save the 'isSynced: false' flag to disk
        emit(AiChatLoaded(
          messages: List.from(_aiMessages), 
          vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
          isSynced: false
        ));
        
        // End the session UI-wise so user isn't stuck
        emit(ChatEnded()); 
      }
    } 
    // 2. HUMAN CHAT LOGIC: Standard End
    else {
      try {
        await _repository.endChat(event.roomId);
        clear(); // Clear local cache for human chat
        emit(ChatEnded()); 
      } catch (e) {
        emit(ChatError("Failed to end chat: $e"));
      }
    }
  }

  // --- AI LOGIC ---

  void _onInitAiChat(InitAiChat event, Emitter<ChatState> emit) {
    // 1. BACKGROUND SYNC CHECK (Step 3)
    // If we loaded an old session that wasn't synced, retry now quietly.
    if (state is AiChatLoaded) {
      final currentState = state as AiChatLoaded;
      if (!currentState.isSynced && currentState.messages.isNotEmpty) {
        _attemptBackgroundSync(currentState);
      }
      return; // Already loaded from disk
    }

    // 2. FRESH START
    if (_aiMessages.isEmpty) {
      _vibe = 0.3; _trust = 0.1; _tension = 0.05; _turn = 1; _isSynced = false;
    }
    
    emit(AiChatLoaded(
      messages: List.from(_aiMessages),
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
      isSynced: _isSynced
    ));
  }

  // Helper: Tries to upload without blocking UI
  Future<void> _attemptBackgroundSync(AiChatLoaded currentState) async {
    // We use a generated ID or the stored ID if you tracked it.
    // This is a "Best Effort" retry.
    final success = await _repository.archiveAiSession(
      roomId: "restored_session_${DateTime.now().millisecondsSinceEpoch}", 
      partnerName: "Neon",
      messages: currentState.messages,
      stats: {'vibe': currentState.vibe, 'trust': currentState.trust, 'tension': currentState.tension},
      turnCount: currentState.turn,
    );

    if (success) {
      _isSynced = true;
      // We don't emit here to avoid UI flicker, but next update will save true.
    }
  }

  void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
    _aiMessages.insert(0, event.message);
    _isSynced = false; // New content means we are dirty/unsynced
    
    emit(AiChatLoaded(
      messages: List.from(_aiMessages), 
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
      isSynced: false
    ));
  }

  void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
    if (event.vibe != null) _vibe = event.vibe!;
    if (event.trust != null) _trust = event.trust!;
    if (event.tension != null) _tension = event.tension!;
    if (event.turn != null) _turn = event.turn!;

    // Stats change also marks us as unsynced
    emit(AiChatLoaded(
      messages: List.from(_aiMessages),
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn,
      isSynced: false 
    ));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}

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


