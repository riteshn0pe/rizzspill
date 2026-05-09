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

class UpdateMessages extends ChatEvent {
  final List<dynamic> messages; 
  UpdateMessages(this.messages);
}

class RoomStatusChanged extends ChatEvent {
  final String? status;
  final String? endedBy;
  RoomStatusChanged({this.status, this.endedBy});
}

// --- AI CHAT EVENTS ---

/// UPDATED: Starts a session with specific metadata.
/// If roomId matches the saved one, it resumes. If new, it resets.
class StartAiSession extends ChatEvent {
  final String roomId;
  final String partnerName;
  final String userGender;
  final String userAge;
  final String roomType; // dating, debate, etc.
  
  StartAiSession({
    required this.roomId,
    required this.partnerName,
    required this.userGender,
    required this.userAge,
    required this.roomType,
  });
}

class AddAiMessage extends ChatEvent {
  final Map<String, dynamic> message;
  AddAiMessage(this.message);
}

class UpdateAiStats extends ChatEvent {
  final double? vibe;
  final double? trust;
  final double? tension;
  final int? turn;
  
  UpdateAiStats({this.vibe, this.trust, this.tension, this.turn});
}
