abstract class ChatEvent {}

// --- HUMAN CHAT EVENTS ---
class LoadMessages extends ChatEvent {
  final String roomId;
  LoadMessages(this.roomId);
}

class SendMessage extends ChatEvent {
  final String roomId;
  final String text;
  SendMessage(this.roomId, this.text);
}

class EndChat extends ChatEvent {
  final String roomId;
  EndChat(this.roomId);
}

// Internal event for Stream updates from Firestore
class UpdateMessages extends ChatEvent {
  final List<dynamic> messages; 
  UpdateMessages(this.messages);
}

// --- NEW: AI CHAT EVENTS (Step 1) ---

/// Initializes the local AI session state
class InitAiChat extends ChatEvent {}

/// Adds a message (User or AI) to the local Bloc memory
class AddAiMessage extends ChatEvent {
  final Map<String, dynamic> message;
  AddAiMessage(this.message);
}

/// Updates the game stats (Vibe/Trust/Tension)
class UpdateAiStats extends ChatEvent {
  final double? vibe;
  final double? trust;
  final double? tension;
  final int? turn;
  
  UpdateAiStats({this.vibe, this.trust, this.tension, this.turn});
}

// abstract class ChatEvent {}

// class LoadMessages extends ChatEvent {
//   final String roomId;
//   LoadMessages(this.roomId);
// }

// class SendMessage extends ChatEvent {
//   final String roomId;
//   final String text;
//   SendMessage(this.roomId, this.text);
// }

// class EndChat extends ChatEvent {
//   final String roomId;
//   EndChat(this.roomId);
// }

// // Internal event for Stream updates
// class UpdateMessages extends ChatEvent {
//   final List<dynamic> messages; // Using dynamic to avoid circular imports easily
//   UpdateMessages(this.messages);
// }