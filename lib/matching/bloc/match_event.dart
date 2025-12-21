abstract class MatchEvent {}

// CHANGE 1: Remove all arguments. 
// The BLoC now fetches profile data internally, so the UI just says "Start".
class StartMatching extends MatchEvent {
  // CRITICAL FIX: No default value. Must be provided explicitly.
  final String roomType; 

  StartMatching({required this.roomType});

  @override
  List<Object> get props => [roomType];
}
// class StartMatching extends MatchEvent {
//   final String roomType; // Add this field

//   // Constructor with a default value to prevent null issues
//   StartMatching(String s, {this.roomType = 'dating'});
// }

// Internal event triggered by the timer
// CHANGE 2: Keep arguments here! 
// The BLoC passes the data it fetched to this event so the timer knows what to look for.
class CheckMatchStatus extends MatchEvent {
  
  final String roomType;
  final String myGender;
  final String interestedIn;
  CheckMatchStatus(  this.myGender, this.interestedIn , {this.roomType = 'dating'} );
}

class CancelMatching extends MatchEvent {}