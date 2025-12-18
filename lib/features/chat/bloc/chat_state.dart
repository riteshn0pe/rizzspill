import '../models/chat_message.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  ChatLoaded(this.messages);
}

class ChatError extends ChatState {
  final String error;
  ChatError(this.error);
}

class ChatEnded extends ChatState {} // Navigation Trigger