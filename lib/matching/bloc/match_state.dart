abstract class MatchState {}

class MatchInitial extends MatchState {}

class MatchSearching extends MatchState {
  final String statusMessage;
  // Used to show ripple/pulse animation logic in UI
  final int attemptCount; 

  MatchSearching({this.statusMessage = "Joining Queue...", this.attemptCount = 0});
}

class MatchFound extends MatchState {
  final String roomId;
  MatchFound(this.roomId);
}

class MatchFailed extends MatchState {
  final String error;
  MatchFailed(this.error);
}