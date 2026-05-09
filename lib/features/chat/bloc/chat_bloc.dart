import 'dart:async';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repository/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends HydratedBloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _roomSubscription;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
    on<RoomStatusChanged>(_onRoomStatusChanged);
    
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
        _messageSubscription?.cancel();
        _roomSubscription?.cancel();
        emit(ChatEnded());
      } else {
        _isSynced = false;
        _emitLoaded(emit);
        emit(ChatEnded()); 
      }
    } else {
      // ... Human logic (unchanged) ...
      try { await _repository.endChat(event.roomId); clear(); _messageSubscription?.cancel(); _roomSubscription?.cancel(); emit(ChatEnded()); } 
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

    _roomSubscription?.cancel();
    _roomSubscription = _repository.watchRoom(event.roomId).listen(
      (room) => add(RoomStatusChanged(status: room['status'] as String?, endedBy: room['endedBy'] as String?)),
      onError: (error) => print("Room Stream Error: $error"),
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

  void _onRoomStatusChanged(RoomStatusChanged event, Emitter<ChatState> emit) {
    if (event.status == 'ended' && event.endedBy != _myUid) {
      _messageSubscription?.cancel();
      _roomSubscription?.cancel();
      emit(ChatPartnerLeft(endedBy: event.endedBy));
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _roomSubscription?.cancel();
    return super.close();
  }
}
