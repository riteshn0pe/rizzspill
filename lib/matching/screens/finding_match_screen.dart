import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_dating/features/chat/screens/chat_screen.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_event.dart';
import '../bloc/match_state.dart';

class FindingMatchScreen extends StatefulWidget {
  const FindingMatchScreen({super.key});

  @override
  State<FindingMatchScreen> createState() => _FindingMatchScreenState();
}

class _FindingMatchScreenState extends State<FindingMatchScreen> {

  @override
  void initState() {
    super.initState();
    
    // SMART RESUME LOGIC:
    // We check the Global Bloc's state before starting a new search.
    // If we are already searching (e.g. returning from minimize), we do NOT fire StartMatching again.
    final state = context.read<MatchBloc>().state;
    
    if (state is! MatchSearching && state is! MatchFound) {
      context.read<MatchBloc>().add(StartMatching("dating")); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<MatchBloc, MatchState>(
        listener: (context, state) {
          if (state is MatchFound) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("MATCH FOUND!")),
            );
            
            // NAVIGATION FIX: Pass all headers to the ChatScreen
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
              return ChatScreen(
                roomId: state.roomId,
                isAi: state.isAi,
                partnerName: state.partnerName,
                roomType: state.roomType,
                aiGender: state.aiGender ?? 'female',
                
                // PASSING HEADERS (Step 4)
                // Accessing these from MatchState ensures ChatBloc can archive properly
                userGender: state.userGender ?? "male", 
                userAge: state.userAge ?? "22",         
              );
            }));
          }
        },
        builder: (context, state) {
          // 1. SHOW ERROR ON SCREEN
          if (state is MatchFailed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    const Text(
                      "Matching Error",
                      style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        context.read<MatchBloc>().add(StartMatching("dating"));
                      },
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
            );
          }

          // 2. SHOW SEARCHING
          if (state is MatchSearching) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 100, width: 100,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    state.statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                    onPressed: () {
                      context.read<MatchBloc>().add(CancelMatching());
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: const Text("Cancel Search"),
                  )
                ],
              ),
            );
          }

          // 3. INITIAL / LOADING
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        },
      ),
    );
  }
}


