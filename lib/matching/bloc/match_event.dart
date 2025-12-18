abstract class MatchEvent {}

// CHANGE 1: Remove all arguments. 
// The BLoC now fetches profile data internally, so the UI just says "Start".
class StartMatching extends MatchEvent {}

// Internal event triggered by the timer
// CHANGE 2: Keep arguments here! 
// The BLoC passes the data it fetched to this event so the timer knows what to look for.
class CheckMatchStatus extends MatchEvent {
  final String myGender;
  final String interestedIn;
  CheckMatchStatus(this.myGender, this.interestedIn);
}

class CancelMatching extends MatchEvent {}