import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:virtual_dating/services/ai/action_queue_manager.dart';
import 'package:virtual_dating/services/ai/ai_service.dart';

// Your Bloc & AI Service Imports
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../repository/chat_repository.dart';

// Widgets
import '../widgets/chat_bubble.dart';
import '../widgets/game_stats_bar.dart';
import '../widgets/inactivity_monitor.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String partnerName;
  final bool isAi;
  final String roomType; // Passed from Homepage (e.g., dating, debate)
  final String aiGender; // The gender the AI should act as

  const ChatScreen({
    super.key,
    required this.roomId,
    this.partnerName = "Stranger",
    this.isAi = false,
    this.roomType = "dating",
    this.aiGender = "female",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(ChatRepository())..add(LoadMessages(widget.roomId)),
      child: _ChatView(
        roomId: widget.roomId,
        partnerName: widget.partnerName,
        isAi: widget.isAi,
        roomType: widget.roomType,
        aiGender: widget.aiGender,
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  final String roomId;
  final String partnerName;
  final bool isAi;
  final String roomType;
  final String aiGender;

  const _ChatView({
    required this.roomId,
    required this.partnerName,
    required this.isAi,
    required this.roomType,
    required this.aiGender,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // AI CLUSTER SERVICES
  final AiService _aiService = AiService();
  final ActionQueueManager _actionDirector = ActionQueueManager();
  final List<Map<String, dynamic>> _aiMessages = [];

  // AUDIO ENGINE
  final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _audioInitialized = false;

  // HIGH-EFFICIENCY GAME STATS (Targeted Rebuilds)
  final ValueNotifier<double> _vibe = ValueNotifier(0.3);
  final ValueNotifier<double> _trust = ValueNotifier(0.1);
  final ValueNotifier<double> _tension = ValueNotifier(0.05);
  final ValueNotifier<int> _turn = ValueNotifier(1);

  // VISUALS & ANIMATIONS
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _initAudio();

    _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this
    );

    if (widget.isAi) {
      _actionDirector.actionStream.listen((event) {
        // 1. Dialogue Handling
        if (event.text != null) {
          _addMessageToLocalList(event.text!, isMe: false);
        }

        // 2. Optimized Parameter Updates (No whole-screen setState)
        if (event.vibe != null) _vibe.value = event.vibe!;
        if (event.trust != null) _trust.value = event.trust!;
        if (event.tension != null) _tension.value = event.tension!;

        // 3. Visual Actions
        if (event.action != null) {
          _handleVisualAction(event.action!);
        }
      });
    }
  }

  Future<void> _initAudio() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.2);
      await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
      if (mounted) {
        _isMusicPlaying.value = true;
        _audioInitialized = true;
      }
    } catch (e) {
      debugPrint("Audio Wait: Interaction required.");
    }
  }

  void _resumeAudioOnGesture() {
    if (!_audioInitialized || _bgmPlayer.state != PlayerState.playing) {
      _bgmPlayer.resume();
      _isMusicPlaying.value = true;
      _audioInitialized = true;
    }
  }

  void _handleVisualAction(String actionCode) {
    debugPrint("Triggering Action: $actionCode");
    if (actionCode.contains("angry") || actionCode.contains("creepy")) {
      _shakeController.forward(from: 0);
    }
    if (actionCode.contains("leave") || actionCode.contains("stand_up")) {
      _showAiExitDialog();
    }
    // Add more visual triggers here (kiss, cry, etc.)
  }

  void _addMessageToLocalList(String text, {required bool isMe}) {
    if (!mounted) return;
    setState(() {
      _aiMessages.insert(0, {
        "text": text,
        "isMe": isMe,
        "timestamp": DateTime.now(),
      });
    });
  }

  void _processTurn(String message) {
    _resumeAudioOnGesture();
    _turn.value++;
    // Fallback logic for human-to-human if needed
    if (!widget.isAi) {
      if (message.length > 15) _trust.value = (_trust.value + 0.03).clamp(0.0, 1.0);
      if (message.contains("//")) _vibe.value = (_vibe.value + 0.05).clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _vibe.dispose();
    _trust.dispose();
    _tension.dispose();
    _turn.dispose();
    _bgmPlayer.dispose();
    _isMusicPlaying.dispose();
    _textController.dispose();
    _actionDirector.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resumeAudioOnGesture,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final double offset = (0.5 - _shakeController.value).abs() * 20;
          return Transform.translate(
            offset: Offset(_shakeController.isAnimating ? offset : 0, 0),
            child: child,
          );
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context),
          body: Column(
            children: [
              // 1. STATS HUD (Optimized Targeted Rebuild)
              ValueListenableBuilder(
                valueListenable: _vibe,
                builder: (context, v, _) => GameStatsBar(
                    vibe: v,
                    trust: _trust.value,
                    tension: _tension.value,
                    turnCount: _turn.value
                ),
              ),

              // 2. CHAT AREA
              Expanded(child: _buildChatArea()),

              // 3. INPUT
              _buildInputArea(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (widget.isAi) {
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        itemCount: _aiMessages.length,
        itemBuilder: (context, index) {
          final msg = _aiMessages[index];
          return ChatBubble(text: msg['text'], isMe: msg['isMe']);
        },
      );
    }

    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatEnded) Navigator.pop(context);
      },
      builder: (context, state) {
        if (state is ChatLoaded) {
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
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: InactivityMonitor(
                  lastActivityTime: state.messages.isNotEmpty ? state.messages.first.timestamp : DateTime.now(),
                  onTimeout: () => context.read<ChatBloc>().add(EndChat(widget.roomId)),
                ),
              ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[800]!))
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier'),
              decoration: InputDecoration(
                hintText: "[SAY] > ...",
                hintStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.3)),
                filled: true, fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.pinkAccent),
            onPressed: () async {
              final text = _textController.text.trim();
              if (text.isEmpty) return;

              _textController.clear();
              _processTurn(text);

              if (widget.isAi) {
                _addMessageToLocalList(text, isMe: true);
                _actionDirector.interrupt();
                
                try {
                  final aiResponse = await _aiService.sendMessage(
                    message: text,
                    aiTargetGender: widget.aiGender,
                    userGender: "male", // Derived from user profile
                    roomType: widget.roomType,
                    userAge: "22", 
                  );
                  _actionDirector.processAiResponse(aiResponse);
                } catch (e) {
                  debugPrint("AI Failure: $e");
                }
              } else {
                context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
              }
            },
          )
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.grey[900],
      title: Text(
          widget.partnerName.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2)
      ),
      centerTitle: true,
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _isMusicPlaying,
          builder: (context, isPlaying, child) => IconButton(
            icon: Icon(isPlaying ? Icons.volume_up : Icons.volume_off, color: Colors.pinkAccent),
            onPressed: () {
              _isMusicPlaying.value = !isPlaying;
              isPlaying ? _bgmPlayer.pause() : _bgmPlayer.resume();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
          onPressed: () => _showEndChatDialog(context),
        )
      ],
    );
  }

  // --- DIALOGS (Kept for consistency) ---
  void _showAiExitDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text("CONNECTION SEVERED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text("The session was terminated by the partner. Response window closed.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () {
                  //fix for consistent dialogue thing issue
                  Navigator.of(c).pop(); // Closes Dialog
              Navigator.of(context).pop();
                },
                child: const Text("RETURN TO CITY", style: TextStyle(color: Colors.pinkAccent))
            )
          ],
        )
    );
  }

  void _showEndChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text("ABORT MISSION?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("The current connection will be terminated permanently.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("STAY", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (widget.isAi) {
                Navigator.pop(context);
              } else {
                context.read<ChatBloc>().add(EndChat(widget.roomId));
              }
            },
            child: const Text("TERMINATE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


// import 'dart:async';
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
// import '../widgets/inactivity_monitor.dart'; // Ensure this widget exists based on previous implementation

// class ChatScreen extends StatefulWidget {
//   final String roomId;
//   final String partnerName;

//   const ChatScreen({
//     super.key, 
//     required this.roomId, 
//     this.partnerName = "Stranger"
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => ChatBloc(ChatRepository())..add(LoadMessages(widget.roomId)),
//       child: _ChatView(roomId: widget.roomId, partnerName: widget.partnerName),
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
  
//   // AUDIO ENGINE
//   final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
//   final AudioPlayer _bgmPlayer = AudioPlayer();
//   bool _audioInitialized = false; 

//   // GAME STATE
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
//     try {
//       await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
//       await _bgmPlayer.setVolume(0.2);
      
//       // Attempt to play asset
//       await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
      
//       if (mounted) {
//         _isMusicPlaying.value = true;
//         _audioInitialized = true;
//       }
//     } catch (e) {
//       debugPrint("Audio Error (Common on Web before click): $e");
//     }
//   }

//   // Wakes up audio engine on Web after user interacts
//   void _resumeAudioOnGesture() {
//     if (!_audioInitialized || _bgmPlayer.state != PlayerState.playing) {
//       _bgmPlayer.resume();
//       _isMusicPlaying.value = true;
//       _audioInitialized = true;
//     }
//   }

//   @override
//   void dispose() {
//     _bgmPlayer.dispose(); 
//     _isMusicPlaying.dispose();
//     _textController.dispose();
//     super.dispose();
//   }

//   void _processTurn(String message) {
//     _resumeAudioOnGesture(); // Ensure music plays after user types
//     setState(() {
//       _turn++;
      
//       if (message.length > 10) _trust += 0.05;
//       if (message.toLowerCase().contains("love") || message.toLowerCase().contains("kiss")) _tension += 0.1;
//       if (message.contains("//")) _vibe += 0.05;

//       _trust = _trust.clamp(0.0, 1.0);
//       _tension = _tension.clamp(0.0, 1.0);
//       _vibe = _vibe.clamp(0.0, 1.0);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _resumeAudioOnGesture, // Global tap to wake up Web audio
//       child: Scaffold(
//         backgroundColor: Colors.black,
        
//         appBar: AppBar(
//           backgroundColor: Colors.grey[900],
//           elevation: 0,
//           title: Text(
//             widget.partnerName.toUpperCase(), 
//             style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.bold)
//           ),
//           centerTitle: true,
//           actions: [
//             ValueListenableBuilder<bool>(
//               valueListenable: _isMusicPlaying,
//               builder: (context, isPlaying, child) {
//                 return IconButton(
//                   icon: Icon(
//                     isPlaying ? Icons.volume_up : Icons.volume_off, 
//                     color: isPlaying ? Colors.pinkAccent : Colors.grey
//                   ),
//                   onPressed: () {
//                     _isMusicPlaying.value = !isPlaying;
//                     isPlaying ? _bgmPlayer.pause() : _bgmPlayer.resume();
//                   },
//                 );
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
//               onPressed: () => _showEndChatDialog(context),
//             )
//           ],
//         ),

//         body: Column(
//           children: [
//             // 1. STATS HUD
//             GameStatsBar(vibe: _vibe, trust: _trust, tension: _tension, turnCount: _turn),

//             // 2. CHAT STREAM & INACTIVITY MONITOR
//             Expanded(
//               child: BlocConsumer<ChatBloc, ChatState>(
//                 listener: (context, state) {
//                   if (state is ChatEnded) Navigator.pop(context);
//                 },
//                 builder: (context, state) {
//                   if (state is ChatLoaded) {
//                     final lastMsgTime = state.messages.isNotEmpty 
//                         ? state.messages.first.timestamp 
//                         : DateTime.now();

//                     return Stack(
//                       children: [
//                         ListView.builder(
//                           reverse: true,
//                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//                           itemCount: state.messages.length,
//                           itemBuilder: (context, index) {
//                             final msg = state.messages[index];
//                             return ChatBubble(text: msg.text, isMe: msg.senderId == myUid);
//                           },
//                         ),
//                         // THE RED COUNTDOWN OVERLAY
//                         Positioned(
//                           bottom: 0, left: 0, right: 0,
//                           child: InactivityMonitor(
//                             lastActivityTime: lastMsgTime,
//                             onTimeout: () {
//                               context.read<ChatBloc>().add(EndChat(widget.roomId));
//                             },
//                           ),
//                         ),
//                       ],
//                     );
//                   }
//                   return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
//                 },
//               ),
//             ),

//             // 3. INPUT AREA
//             _buildInputArea(context),
//           ],
//         ),
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
//               style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontWeight: FontWeight.bold), 
//               cursorColor: Colors.pinkAccent,
//               decoration: InputDecoration(
//                 hintText: "[SAY] > Type something...",
//                 hintStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.5), fontFamily: 'Courier'),
//                 filled: true, fillColor: Colors.black,
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.greenAccent)),
//                 focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Container(
//             decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)),
//             child: IconButton(
//               icon: const Icon(Icons.send, color: Colors.white),
//               onPressed: () {
//                 final text = _textController.text.trim();
//                 if (text.isNotEmpty) {
//                   context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
//                   _textController.clear();
//                   _processTurn(text); 
//                 }
//               },
//             ),
//           )
//         ],
//       ),
//     );
//   }

  // void _showEndChatDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (c) => AlertDialog(
  //       backgroundColor: Colors.grey[900],
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //       title: const Text("ABORT MISSION?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
  //       content: const Text("Connection will be severed. Chat data will be archived.", style: TextStyle(color: Colors.white70)),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(c);
  //             context.read<ChatBloc>().add(EndChat(widget.roomId));
  //           },
  //           child: const Text("CONFIRM", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
  //         ),
  //       ],
  //     ),
  //   );
  // }
// }


