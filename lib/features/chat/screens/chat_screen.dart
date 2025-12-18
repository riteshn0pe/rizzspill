import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../repository/chat_repository.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/game_stats_bar.dart';
import '../widgets/inactivity_monitor.dart'; // Ensure this widget exists based on previous implementation

class ChatScreen extends StatelessWidget {
  final String roomId;
  final String partnerName;

  const ChatScreen({
    super.key, 
    required this.roomId, 
    this.partnerName = "Stranger"
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(ChatRepository())..add(LoadMessages(roomId)),
      child: _ChatView(roomId: roomId, partnerName: partnerName),
    );
  }
}

class _ChatView extends StatefulWidget {
  final String roomId;
  final String partnerName;

  const _ChatView({required this.roomId, required this.partnerName});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _textController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  // AUDIO ENGINE
  final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _audioInitialized = false; 

  // GAME STATE
  double _vibe = 0.3;
  double _trust = 0.1;
  double _tension = 0.05;
  int _turn = 1;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.2);
      
      // Attempt to play asset
      await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
      
      if (mounted) {
        _isMusicPlaying.value = true;
        _audioInitialized = true;
      }
    } catch (e) {
      debugPrint("Audio Error (Common on Web before click): $e");
    }
  }

  // Wakes up audio engine on Web after user interacts
  void _resumeAudioOnGesture() {
    if (!_audioInitialized || _bgmPlayer.state != PlayerState.playing) {
      _bgmPlayer.resume();
      _isMusicPlaying.value = true;
      _audioInitialized = true;
    }
  }

  @override
  void dispose() {
    _bgmPlayer.dispose(); 
    _isMusicPlaying.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _processTurn(String message) {
    _resumeAudioOnGesture(); // Ensure music plays after user types
    setState(() {
      _turn++;
      
      if (message.length > 10) _trust += 0.05;
      if (message.toLowerCase().contains("love") || message.toLowerCase().contains("kiss")) _tension += 0.1;
      if (message.contains("//")) _vibe += 0.05;

      _trust = _trust.clamp(0.0, 1.0);
      _tension = _tension.clamp(0.0, 1.0);
      _vibe = _vibe.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resumeAudioOnGesture, // Global tap to wake up Web audio
      child: Scaffold(
        backgroundColor: Colors.black,
        
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          title: Text(
            widget.partnerName.toUpperCase(), 
            style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.bold)
          ),
          centerTitle: true,
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _isMusicPlaying,
              builder: (context, isPlaying, child) {
                return IconButton(
                  icon: Icon(
                    isPlaying ? Icons.volume_up : Icons.volume_off, 
                    color: isPlaying ? Colors.pinkAccent : Colors.grey
                  ),
                  onPressed: () {
                    _isMusicPlaying.value = !isPlaying;
                    isPlaying ? _bgmPlayer.pause() : _bgmPlayer.resume();
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
              onPressed: () => _showEndChatDialog(context),
            )
          ],
        ),

        body: Column(
          children: [
            // 1. STATS HUD
            GameStatsBar(vibe: _vibe, trust: _trust, tension: _tension, turnCount: _turn),

            // 2. CHAT STREAM & INACTIVITY MONITOR
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listener: (context, state) {
                  if (state is ChatEnded) Navigator.pop(context);
                },
                builder: (context, state) {
                  if (state is ChatLoaded) {
                    final lastMsgTime = state.messages.isNotEmpty 
                        ? state.messages.first.timestamp 
                        : DateTime.now();

                    return Stack(
                      children: [
                        ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final msg = state.messages[index];
                            return ChatBubble(text: msg.text, isMe: msg.senderId == myUid);
                          },
                        ),
                        // THE RED COUNTDOWN OVERLAY
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: InactivityMonitor(
                            lastActivityTime: lastMsgTime,
                            onTimeout: () {
                              context.read<ChatBloc>().add(EndChat(widget.roomId));
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                },
              ),
            ),

            // 3. INPUT AREA
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontWeight: FontWeight.bold), 
              cursorColor: Colors.pinkAccent,
              decoration: InputDecoration(
                hintText: "[SAY] > Type something...",
                hintStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.5), fontFamily: 'Courier'),
                filled: true, fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.greenAccent)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
                  _textController.clear();
                  _processTurn(text); 
                }
              },
            ),
          )
        ],
      ),
    );
  }

  void _showEndChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("ABORT MISSION?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Connection will be severed. Chat data will be archived.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              context.read<ChatBloc>().add(EndChat(widget.roomId));
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:audioplayers/audioplayers.dart';
// import '../bloc/chat_bloc.dart';
// import '../bloc/chat_event.dart';
// import '../bloc/chat_state.dart';
// import '../repository/chat_repository.dart';
// import '../widgets/chat_bubble.dart';
// import '../widgets/game_stats_bar.dart';

// class ChatScreen extends StatelessWidget {
//   final String roomId;
//   final String partnerName;

//   const ChatScreen({
//     super.key, 
//     required this.roomId, 
//     this.partnerName = "Stranger"
//   });

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => ChatBloc(ChatRepository())..add(LoadMessages(roomId)),
//       child: _ChatView(roomId: roomId, partnerName: partnerName),
//     );
//   }
// }

// class _ChatView extends StatefulWidget {
//   final String roomId;
//   final String partnerName;

//   const _ChatView({required this.roomId, required this.partnerName});

//   @override
//   State<_ChatView> createState() => _ChatViewState();
// }

// class _ChatViewState extends State<_ChatView> {
//   final TextEditingController _textController = TextEditingController();
//   final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
//   // OPTIMIZATION: Use ValueNotifier for music to avoid rebuilding the whole screen
//   final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
//   final AudioPlayer _bgmPlayer = AudioPlayer();

//   // GAME STATE (Currently Dummy -> Will Connect to AI Backend Later)
//   double _vibe = 0.3;
//   double _trust = 0.1;
//   double _tension = 0.05;
//   int _turn = 1;

//   @override
//   void initState() {
//     super.initState();
//     _initAudio();
//   }

//   Future<void> _initAudio() async {
//     // LOGIC: Plays background music to set the mood
//     try {
//       await _bgmPlayer.setReleaseMode(ReleaseMode.loop); // Loop forever
//       await _bgmPlayer.setVolume(0.2); // Low ambient volume
      
//       // UNCOMMENT BELOW LINE TO ENABLE MUSIC (Add file to assets/sounds/bgm.mp3 first)
//       await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
      
//       if (mounted) {
//         _isMusicPlaying.value = true;
//       }
//     } catch (e) {
//       debugPrint("Audio Error: $e");
//     }
//   }

//   @override
//   void dispose() {
//     _bgmPlayer.dispose(); 
//     _isMusicPlaying.dispose(); // Cleanup memory
//     super.dispose();
//   }

//   // --- THE GAME LOGIC ENGINE (Simulation) ---
//   void _processTurn(String message) {
//     // LOGIC: This runs when you send a message.
//     // In the future, this will read the 'stat_changes' from the AI response.
    
//     setState(() {
//       _turn++;
      
//       // Temporary Logic for Demo:
//       // Long messages increase Trust. Flirty words increase Tension.
//       if (message.length > 10) _trust += 0.05;
//       if (message.toLowerCase().contains("love") || message.toLowerCase().contains("kiss")) _tension += 0.1;
//       if (message.contains("//")) _vibe += 0.05; // Roleplay actions boost vibe

//       // Clamp values between 0.0 and 1.0 to prevent errors
//       _trust = _trust.clamp(0.0, 1.0);
//       _tension = _tension.clamp(0.0, 1.0);
//       _vibe = _vibe.clamp(0.0, 1.0);

//       // FUTURE LOGIC:
//       // if (_tension > 0.8) _bgmPlayer.play(AssetSource('sounds/intense.mp3'));
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black, // Pure black for OLED/Cyberpunk feel
      
//       // CUSTOM APP BAR
//       appBar: AppBar(
//         backgroundColor: Colors.grey[900],
//         elevation: 0,
//         title: Text(
//           widget.partnerName.toUpperCase(), 
//           style: const TextStyle(
//             color: Colors.white, 
//             letterSpacing: 2, 
//             fontSize: 14, 
//             fontWeight: FontWeight.bold
//           )
//         ),
//         centerTitle: true,
//         actions: [
//           // OPTIMIZED MUSIC TOGGLE BUTTON
//           ValueListenableBuilder<bool>(
//             valueListenable: _isMusicPlaying,
//             builder: (context, isPlaying, child) {
//               return IconButton(
//                 icon: Icon(
//                   isPlaying ? Icons.volume_up : Icons.volume_off, 
//                   color: isPlaying ? Colors.pinkAccent : Colors.grey
//                 ),
//                 onPressed: () {
//                   _isMusicPlaying.value = !isPlaying;
//                   isPlaying ? _bgmPlayer.pause() : _bgmPlayer.resume();
//                 },
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
//             tooltip: "Abort Mission",
//             onPressed: () => _showEndChatDialog(context),
//           )
//         ],
//       ),

//       body: Column(
//         children: [
//           // 1. THE GAME HUD (Health Bars)
//           GameStatsBar(
//             vibe: _vibe, 
//             trust: _trust, 
//             tension: _tension,
//             turnCount: _turn,
//           ),

//           // 2. CHAT STREAM (The Conversation)
//           Expanded(
//             child: BlocConsumer<ChatBloc, ChatState>(
//               listener: (context, state) {
//                 if (state is ChatEnded) {
//                   // Soft delete successful, exit screen
//                   if (Navigator.canPop(context)) Navigator.pop(context);
//                 }
//                 if (state is ChatError) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text(state.error), backgroundColor: Colors.red)
//                   );
//                 }
//               },
//               builder: (context, state) {
//                 if (state is ChatLoaded) {
//                   return ListView.builder(
//                     reverse: true, // Chat standard (bottom to top)
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//                     itemCount: state.messages.length,
//                     itemBuilder: (context, index) {
//                       final msg = state.messages[index];
//                       return ChatBubble(
//                         text: msg.text,
//                         isMe: msg.senderId == myUid,
//                       );
//                     },
//                   );
//                 }
//                 return const Center(
//                   child: CircularProgressIndicator(color: Colors.pinkAccent)
//                 );
//               },
//             ),
//           ),

//           // 3. INPUT AREA (Terminal Style)
//           _buildInputArea(context),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputArea(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _textController,
//               // Retro Terminal Style
//               style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontWeight: FontWeight.bold), 
//               cursorColor: Colors.pinkAccent,
//               decoration: InputDecoration(
//                 hintText: "[SAY] > Type something...",
//                 hintStyle: TextStyle(
//                   color: Colors.greenAccent.withOpacity(0.5), 
//                   fontFamily: 'Courier'
//                 ),
//                 filled: true,
//                 fillColor: Colors.black,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(4), 
//                   borderSide: const BorderSide(color: Colors.greenAccent),
//                 ),
//                 focusedBorder: const OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.pinkAccent),
//                 ),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.pinkAccent, 
//               borderRadius: BorderRadius.circular(4)
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.send, color: Colors.white),
//               onPressed: () {
//                 final text = _textController.text.trim();
//                 if (text.isNotEmpty) {
//                   // 1. Send to Firebase
//                   context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
//                   _textController.clear();
                  
//                   // 2. Trigger Game Logic (Update Stats)
//                   _processTurn(text); 
//                 }
//               },
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   void _showEndChatDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (c) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         title: const Text(
//           "ABORT MISSION?", 
//           style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)
//         ),
//         content: const Text(
//           "Connection will be severed. Chat data will be archived.\nAre you sure?", 
//           style: TextStyle(color: Colors.white70)
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(c), 
//             child: const Text("CANCEL", style: TextStyle(color: Colors.grey))
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(c);
//               // Trigger the BLoC event for Soft Delete
//               context.read<ChatBloc>().add(EndChat(widget.roomId));
//             },
//             child: const Text("CONFIRM", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//   }
// }
