abstract class ChatEvent {}

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

// Internal event for Stream updates
class UpdateMessages extends ChatEvent {
  final List<dynamic> messages; // Using dynamic to avoid circular imports easily
  UpdateMessages(this.messages);
}