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
  final bool isAi;
  final String partnerName;
  final String roomType;
  final String aiGender;
  final String userGender;
  final String userAge;

  MatchFound(this.roomId, {
    this.isAi = false,
    this.partnerName = "Stranger",
    this.roomType = "dating",
    this.aiGender = "female",
    this.userGender = "male",
    this.userAge = "22",
  });

  @override
  List<Object?> get props => [roomId, isAi, partnerName, roomType, aiGender, userGender, userAge];
}
// class MatchFound extends MatchState {
//   final String roomId;
//   MatchFound(this.roomId);
// }

class MatchFailed extends MatchState {
  final String error;
  MatchFailed(this.error);
}