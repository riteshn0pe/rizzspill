import '../models/chat_message.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

// --- HUMAN CHAT STATE ---
class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  ChatLoaded(this.messages);
}

// --- NEW: AI CHAT STATE (Step 1) ---
class AiChatLoaded extends ChatState {
  // We store the full list of messages and stats here
  final List<Map<String, dynamic>> messages;
  final double vibe;
  final double trust;
  final double tension;
  final int turn;

  AiChatLoaded({
    required this.messages,
    required this.vibe,
    required this.trust,
    required this.tension,
    required this.turn,
  });
}

class ChatError extends ChatState {
  final String error;
  ChatError(this.error);
}

class ChatEnded extends ChatState {}

// import '../models/chat_message.dart';

// abstract class ChatState {}

// class ChatInitial extends ChatState {}

// class ChatLoading extends ChatState {}

// class ChatLoaded extends ChatState {
//   final List<ChatMessage> messages;
//   ChatLoaded(this.messages);
// }

// class ChatError extends ChatState {
//   final String error;
//   ChatError(this.error);
// }

// class ChatEnded extends ChatState {} // Navigation Trigger