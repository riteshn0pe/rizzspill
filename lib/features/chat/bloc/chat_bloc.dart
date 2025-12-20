import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messageSubscription;

  // --- NEW: AI LOCAL STATE STORAGE ---
  // This list now lives in the Bloc, protecting it from UI redraws.
  // In Step 2, this list will be automatically saved to disk.
  final List<Map<String, dynamic>> _aiMessages = [];
  
  // Default Stats
  double _vibe = 0.3;
  double _trust = 0.1;
  double _tension = 0.05;
  int _turn = 1;

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

  // --- HUMAN LOGIC ---

  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
    emit(ChatLoading());
    
    _messageSubscription?.cancel();
    _messageSubscription = _repository.getMessages(event.roomId).listen(
      (messages) => add(UpdateMessages(messages)),
      onError: (error) => print("Stream Error: $error"), 
    );
  }

  void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
    // When stream updates, we emit the new state.
    // In Step 2 (HydratedBloc), this state is auto-saved to disk for offline reading.
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
    try {
      await _repository.endChat(event.roomId);
      emit(ChatEnded()); 
    } catch (e) {
      emit(ChatError("Failed to end chat: $e"));
    }
  }

  // --- NEW: AI LOGIC (Step 1 Implementation) ---

  void _onInitAiChat(InitAiChat event, Emitter<ChatState> emit) {
    // Only reset defaults if we have no history (prevents wiping on reconnect)
    if (_aiMessages.isEmpty) {
      _vibe = 0.3; _trust = 0.1; _tension = 0.05; _turn = 1;
    }
    
    emit(AiChatLoaded(
      messages: List.from(_aiMessages),
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
    ));
  }

  void _onAddAiMessage(AddAiMessage event, Emitter<ChatState> emit) {
    // Insert new message at the top (0)
    _aiMessages.insert(0, event.message);
    
    // Emit new state with a COPY of the list to ensure UI rebuilds
    emit(AiChatLoaded(
      messages: List.from(_aiMessages), 
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
    ));
  }

  void _onUpdateAiStats(UpdateAiStats event, Emitter<ChatState> emit) {
    if (event.vibe != null) _vibe = event.vibe!;
    if (event.trust != null) _trust = event.trust!;
    if (event.tension != null) _tension = event.tension!;
    if (event.turn != null) _turn = event.turn!;

    emit(AiChatLoaded(
      messages: List.from(_aiMessages),
      vibe: _vibe, trust: _trust, tension: _tension, turn: _turn
    ));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}

// import 'dart:async';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import '../repository/chat_repository.dart';
// import '../models/chat_message.dart';
// import 'chat_event.dart';
// import 'chat_state.dart';

// class ChatBloc extends Bloc<ChatEvent, ChatState> {
//   final ChatRepository _repository;
//   StreamSubscription? _messageSubscription;

//   ChatBloc(this._repository) : super(ChatInitial()) {
//     on<LoadMessages>(_onLoadMessages);
//     on<UpdateMessages>(_onUpdateMessages);
//     on<SendMessage>(_onSendMessage);
//     on<EndChat>(_onEndChat);
//   }

//   void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoading());
    
//     _messageSubscription?.cancel();
//     _messageSubscription = _repository.getMessages(event.roomId).listen(
//       (messages) => add(UpdateMessages(messages)),
//       onError: (error) => print("Stream Error: $error"), // Handle stream errors
//     );
//   }

//   void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
//     emit(ChatLoaded(event.messages as List<ChatMessage>));
//   }

//   Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.sendMessage(event.roomId, event.text);
//     } catch (e) {
//       // We don't emit Error state here to avoid breaking the Stream UI.
//       // In a real app, use a "Side Effect" (like a Toast/Snackbar).
//       print("Send failed: $e"); 
//     }
//   }

//   Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
//     try {
//       await _repository.endChat(event.roomId);
//       emit(ChatEnded()); // Triggers navigation
//     } catch (e) {
//       emit(ChatError("Failed to end chat: $e"));
//     }
//   }

//   @override
//   Future<void> close() {
//     _messageSubscription?.cancel();
//     return super.close();
//   }
// }