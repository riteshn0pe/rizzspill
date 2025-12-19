import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:virtual_dating/features/chat/screens/chat_screen.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_event.dart';
import '../bloc/match_state.dart';
import '../repository/match_repository.dart';

class FindingMatchScreen extends StatelessWidget {
  const FindingMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MatchBloc(MatchRepository())..add(StartMatching()),
      child: const _MatchLifecycleHandler(),
    );
  }
}

class _MatchLifecycleHandler extends StatefulWidget {
  const _MatchLifecycleHandler();

  @override
  State<_MatchLifecycleHandler> createState() => _MatchLifecycleHandlerState();
}

class _MatchLifecycleHandlerState extends State<_MatchLifecycleHandler> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      context.read<MatchBloc>().add(CancelMatching());
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
              SnackBar(content: Text("MATCH FOUND! ")),
            );
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context){
              return ChatScreen(roomId: state.roomId , isAi: state.isAi, 
            partnerName: state.partnerName,
            roomType: state.roomType, 
            aiGender: state.aiGender,);
            }));
          }
          // CRITICAL FIX: I removed the "Navigator.pop" here. 
          // Now it won't crash to a white screen on error.
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
                      // THIS IS THE KEY: It will print "Index Missing" here
                      state.error, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        context.read<MatchBloc>().add(StartMatching());
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
                      // Only pop if safe
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: const Text("Cancel Search"),
                  )
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        },
      ),
    );
  }
}