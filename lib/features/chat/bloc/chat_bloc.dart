import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messageSubscription;

  ChatBloc(this._repository) : super(ChatInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<UpdateMessages>(_onUpdateMessages);
    on<SendMessage>(_onSendMessage);
    on<EndChat>(_onEndChat);
  }

  void _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) {
    emit(ChatLoading());
    
    _messageSubscription?.cancel();
    _messageSubscription = _repository.getMessages(event.roomId).listen(
      (messages) => add(UpdateMessages(messages)),
      onError: (error) => print("Stream Error: $error"), // Handle stream errors
    );
  }

  void _onUpdateMessages(UpdateMessages event, Emitter<ChatState> emit) {
    emit(ChatLoaded(event.messages as List<ChatMessage>));
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    try {
      await _repository.sendMessage(event.roomId, event.text);
    } catch (e) {
      // We don't emit Error state here to avoid breaking the Stream UI.
      // In a real app, use a "Side Effect" (like a Toast/Snackbar).
      print("Send failed: $e"); 
    }
  }

  Future<void> _onEndChat(EndChat event, Emitter<ChatState> emit) async {
    try {
      await _repository.endChat(event.roomId);
      emit(ChatEnded()); // Triggers navigation
    } catch (e) {
      emit(ChatError("Failed to end chat: $e"));
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}