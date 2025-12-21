import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:virtual_dating/features/chat/widgets/isual_fx_overlay.dart';
import 'package:virtual_dating/features/chat/widgets/typewriter_chat_bubble.dart';
import 'package:virtual_dating/services/ai/action_queue_manager.dart';
import 'package:virtual_dating/services/ai/ai_service.dart';

// Bloc & Service Imports
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../repository/chat_repository.dart';

// Widgets
import '../widgets/chat_bubble.dart'; // Keep if used for legacy, otherwise TypewriterChatBubble is used
import '../widgets/game_stats_bar.dart';
import '../widgets/inactivity_monitor.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String partnerName;
  final bool isAi;
  final String roomType; 
  final String aiGender; 

  final String userGender;
  final String userAge;

  const ChatScreen({
    super.key,
    required this.roomId,
    this.partnerName = "Stranger",
    this.isAi = false,
    this.roomType = "dating",
    this.aiGender = "female", this.userGender = "male", 
    this.userAge = "22",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    // We create the Bloc here. Because the AI state is inside the Bloc class,
    // we need to make sure this Bloc survives if we want to solve resize issues fully.
    // However, for Step 1 (Moving Logic), this connects the UI to the Bloc correctly.
    // In Step 2 (HydratedBloc), this same code will automatically load saved history.
    // Inside build()
return BlocProvider(
    create: (context) {
      final bloc = ChatBloc(ChatRepository());
      if (widget.isAi) {
        // UPDATED: StartAiSession handles the Room ID check and resets if needed
        bloc.add(StartAiSession(
          roomId: widget.roomId,
          partnerName: widget.partnerName,
          userGender: widget.userGender,
          userAge: widget.userAge,
          roomType: widget.roomType,
        ));
      } else {
        bloc.add(LoadMessages(widget.roomId));
      }
      return bloc;
    },
  
      child: _ChatView(
        roomId: widget.roomId,
        partnerName: widget.partnerName,
        isAi: widget.isAi,
        roomType: widget.roomType,
        aiGender: widget.aiGender, userGender: widget.userGender, userAge: widget.userAge,
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
  final String userGender;
  final String userAge;

  const _ChatView({
    required this.roomId,
    required this.partnerName,
    required this.isAi,
    required this.roomType,
    required this.aiGender,
    required this.userGender, // ADD THIS
    required this.userAge,
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
  
  // --- STATE MOVED TO BLOC ---
  // The _aiMessages list and stats are now managed by ChatBloc.
  // We only keep UI-specific transient state here.
  
  // TYPING INDICATOR (Only for "waiting" state)
  final ValueNotifier<bool> _isAiTyping = ValueNotifier(false);

  // AUDIO ENGINE
  final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _audioInitialized = false; 

  final AudioPlayer _sfxPlayer = AudioPlayer(); 

  void _playSentSound() {
    _sfxPlayer.play(AssetSource('sounds/send_msg_sound.mp3'), volume: 0.3);
  }

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _initAudio();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500), 
      vsync: this
    );

    // Visual FX Listener
    _actionDirector.visualEffectStream.listen((effect) {
      if (effect == 'shake') {
        _shakeController.forward(from: 0);
      }
    });

    // AI Logic Listener
    if (widget.isAi) {
      _actionDirector.actionStream.listen((event) {
        if (!mounted) return;

        // 1. Handle Text Arrival
        if (event.text != null) {
          _isAiTyping.value = false; 
          _dispatchMessageToBloc(event.text!, isMe: false);
        }

        // 2. Handle Stats (Dispatch to Bloc)
        if (event.vibe != null || event.trust != null || event.tension != null) {
           context.read<ChatBloc>().add(UpdateAiStats(
             vibe: event.vibe,
             trust: event.trust,
             tension: event.tension,
           ));
        }

        // 3. Handle Visual Actions
        if (event.action != null) {
          _handleVisualAction(event.action!);
        }
      });
    }
  }

  // --- AUDIO LOGIC ---
  Future<void> _initAudio() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.1);
      await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
      if (mounted) {
        _isMusicPlaying.value = true;
        _audioInitialized = true;
      }
    } catch (e) {
      debugPrint("Audio Wait: Browser interaction required.");
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
    String cleanAction = actionCode.replaceAll("//", "").replaceAll("_", " ");
    
    // 1. Send Action Message to Bloc (Unchanged)
    final actionMap = {
      "id": "act_${DateTime.now().millisecondsSinceEpoch}_${actionCode.length}", 
      "text": "* $cleanAction *",
      "isMe": false,
      "timestamp": DateTime.now(),
      "isAction": true,
      "isTyped": false, 
    };
    context.read<ChatBloc>().add(AddAiMessage(actionMap));

    // 2. Trigger Local Animations (UPDATED for new logic)
    // We only trigger physical SHAKE here. Colors are handled by VisualFxOverlay.
    if (actionCode.toLowerCase().contains("shake") || 
        actionCode.toLowerCase().contains("angry") || 
        actionCode.toLowerCase().contains("slam")) {
      _shakeController.forward(from: 0);
    }
    
    if (actionCode.toLowerCase().contains("leave") || 
        actionCode.toLowerCase().contains("stand_up")) {
      _showAiExitDialog();
    }
  }
  // // REPLACED: Instead of setState local list, we dispatch to Bloc
  // void _handleVisualAction(String actionCode) {
  //   String cleanAction = actionCode.replaceAll("//", "").replaceAll("_", " ");
    
  //   // 1. Send Action Message to Bloc
  //   final actionMap = {
  //     "id": "act_${DateTime.now().millisecondsSinceEpoch}_${actionCode.length}", 
  //     "text": "* $cleanAction *",
  //     "isMe": false,
  //     "timestamp": DateTime.now(),
  //     "isAction": true,
  //     "isTyped": false, 
  //   };
  //   context.read<ChatBloc>().add(AddAiMessage(actionMap));

  //   // 2. Trigger Local Animations
  //   if (actionCode.contains("angry") || actionCode.contains("creepy")) {
  //     _shakeController.forward(from: 0);
  //   }
  //   if (actionCode.contains("leave") || actionCode.contains("stand_up")) {
  //     _showAiExitDialog();
  //   }
  // }
  
  // REPLACED: Instead of setState local list, we dispatch to Bloc
  void _dispatchMessageToBloc(String text, {required bool isMe}) {
    final msgMap = {
      "id": "msg_${DateTime.now().microsecondsSinceEpoch}", 
      "text": text,
      "isMe": isMe,
      "timestamp": DateTime.now(),
      "isAction": false,
      "isTyped": isMe, 
    };
    context.read<ChatBloc>().add(AddAiMessage(msgMap));
  }

  void _processTurn(String message) {
    _resumeAudioOnGesture();
    
    if (widget.isAi) {
      // Increment turn in Bloc
      // You can get current turn from state if needed, but incrementing is tricky without reading.
      // For now, we rely on the ActionQueueManager for stats, or send a simplified update.
      // Step 2 will make this automatic.
    }
  }

  @override
  void dispose() {
    _bgmPlayer.dispose(); 
    _isMusicPlaying.dispose();
    _textController.dispose();
    _actionDirector.dispose();
    _shakeController.dispose();
    _isAiTyping.dispose();
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
              // 1. STATS HUD (Now Connected to Bloc State)
              if (widget.isAi)
                BlocBuilder<ChatBloc, ChatState>(
                  buildWhen: (previous, current) => current is AiChatLoaded,
                  builder: (context, state) {
                    if (state is AiChatLoaded) {
                      return GameStatsBar(
                        vibe: state.vibe, 
                        trust: state.trust, 
                        tension: state.tension, 
                        turnCount: state.turn
                      );
                    }
                    return const SizedBox.shrink(); 
                  },
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
    // 1. AI CHAT LOGIC
    if (widget.isAi) {
      return Stack(
        children: [
          // A. The Chat List - Connected to Bloc
          BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (previous, current) => current is AiChatLoaded,
            builder: (context, state) {
              if (state is! AiChatLoaded) {
                return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
              }

              final messages = state.messages;

              return ListView.builder(
                reverse: true,
                addAutomaticKeepAlives: true,
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 50),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final String uniqueId = msg['id'] ?? msg['timestamp'].toString();
                  final DateTime msgTime = msg['timestamp'] is DateTime 
                      ? msg['timestamp'] 
                      : DateTime.now();

                  // Action Renderer
                  if (msg['isAction'] == true) {
                    return TypewriterChatBubble(
                      key: ValueKey("act_$uniqueId"),
                      text: msg['text'].toString().toUpperCase(),
                      isMe: false,
                      isAlreadyTyped: msg['isTyped'] ?? false,
                      onFinished: () => msg['isTyped'] = true, // This updates the COPY in the list
                      startTime: msgTime,
                      isSystemAction: true,
                    );
                  }

                  // Normal Message Renderer
                  return TypewriterChatBubble(
                    key: ValueKey("msg_$uniqueId"),
                    text: msg['text'],
                    isMe: msg['isMe'],
                    isAlreadyTyped: msg['isTyped'] ?? false,
                    onFinished: () => msg['isTyped'] = true,
                    startTime: msgTime,
                    isSystemAction: false,
                  );
                },
              );
            }
          ),

          // Visual Effects Layer
          VisualFxOverlay(effectStream: _actionDirector.visualEffectStream),

          // B. Typing Indicator
          Positioned(
            bottom: 30, 
            left: 20,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isAiTyping,
              builder: (context, isTyping, child) {
                if (!isTyping) return const SizedBox.shrink();
                return const Text(
                  "// Neon is typing...",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Courier', fontSize: 11),
                );
              },
            ),
          ),

          // C. Inactivity Monitor (Using Bloc Data)
          BlocBuilder<ChatBloc, ChatState>(
             builder: (context, state) {
               DateTime lastTime = DateTime.now();
               if (state is AiChatLoaded && state.messages.isNotEmpty) {
                 lastTime = state.messages.first['timestamp'] as DateTime;
               }
               
               return Positioned(
                bottom: 0, left: 0, right: 0,
                child: InactivityMonitor(
                  lastActivityTime: lastTime,
                  onTimeout: () => _showAiExitDialog(),
                ),
              );
             }
          ),
        ],
      );
    }

    
    // 2. HUMAN CHAT LOGIC
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatEnded) {
          Navigator.pop(context);
          return;
        }
        
        // --- VISUAL FX TRIGGER FOR RECEIVER ---
        // This ensures that when the partner sends a romantic/angry message, 
        // YOUR screen reacts to it.
        if (state is ChatLoaded && state.messages.isNotEmpty) {
          final latestMsg = state.messages.first;
          
          // Only analyze if the message is NOT from me (Partner sent it)
          // (My own messages are handled instantly in _handleSend for zero latency)
          if (latestMsg.senderId != myUid) {
            _actionDirector.analyzeTextForVisuals(latestMsg.text);
          }
        }
      },
      builder: (context, state) {
        if (state is ChatLoaded) {
          return Stack(
            children: [
              ListView.builder(
                reverse: true,
                addAutomaticKeepAlives: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];
                  final isMe = msg.senderId == myUid;

                  return TypewriterChatBubble(
                    key: ValueKey(msg.id), // Ensure your ChatMessage model has a unique 'id'
                    text: msg.text,
                    isMe: isMe,
                    // If it's me, it's already typed. If it's partner, check the flag.
                    isAlreadyTyped: isMe ? true : (msg.isTyped ?? false),
                    onFinished: () => msg.isTyped = true,
                    startTime: msg.timestamp, 
                    isSystemAction: false,
                  );
                },
              ),
              
              // --- VISUAL FX OVERLAY ---
              // This is CRITICAL. Without this here, the triggers above will fire
              // but nothing will show up on screen.
              VisualFxOverlay(effectStream: _actionDirector.visualEffectStream),
              
              // Inactivity Monitor for Humans
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: InactivityMonitor(
                  lastActivityTime: state.messages.isNotEmpty 
                      ? state.messages.first.timestamp 
                      : DateTime.now(),
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
              textInputAction: TextInputAction.send,
              onSubmitted: (value) => _handleSend(value),
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
            onPressed: () => _handleSend(_textController.text),
          )
        ],
      ),
    );
  }
Future<void> _handleSend(String rawText) async {
  final text = rawText.trim();
  if (text.isEmpty) return;

  _textController.clear();
  _playSentSound(); 
  _processTurn(text);

  // 1. TRIGGER VISUALS IMMEDIATELY (Responsiveness)
  // This analyzes the user's input words right now
  _actionDirector.analyzeTextForVisuals(text);

  // 2. Add User Message Locally
  _dispatchMessageToBloc(text, isMe: true);

  if (widget.isAi) {
    _isAiTyping.value = true;
    _actionDirector.interrupt(); 
    
    List<Map<String, dynamic>> currentHistory = [];
    final currentState = context.read<ChatBloc>().state;
    if (currentState is AiChatLoaded) {
      currentHistory = currentState.messages;
    }

    try {
      final aiResponse = await _aiService.sendMessage(
        message: text,
        previousMessages: currentHistory,
        aiTargetGender: widget.aiGender,
        userGender: widget.userGender, 
        roomType: widget.roomType,
        userAge: widget.userAge,
      );
      
      // 3. PROCESS AI RESPONSE (This handles AI text + AI actions)
      _actionDirector.processAiResponse(aiResponse);
      
    } catch (e) {
      _isAiTyping.value = false;
      debugPrint("AI Failure: $e");
    }
  } else {
    context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
  }
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

  void _showAiExitDialog() {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("CONNECTION SEVERED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("The session was terminated by the partner. Response window closed.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); 
              if (mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
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
// import 'package:virtual_dating/features/chat/widgets/isual_fx_overlay.dart';
// import 'package:virtual_dating/features/chat/widgets/typewriter_chat_bubble.dart';
// import 'package:virtual_dating/services/ai/action_queue_manager.dart';
// import 'package:virtual_dating/services/ai/ai_service.dart';

// // Your Bloc & AI Service Imports
// import '../bloc/chat_bloc.dart';
// import '../bloc/chat_event.dart';
// import '../bloc/chat_state.dart';
// import '../repository/chat_repository.dart';

// // Widgets
// import '../widgets/chat_bubble.dart';
// import '../widgets/game_stats_bar.dart';
// import '../widgets/inactivity_monitor.dart';

// class ChatScreen extends StatefulWidget {
//   final String roomId;
//   final String partnerName;
//   final bool isAi;
//   final String roomType; // Passed from Homepage (e.g., dating, debate)
//   final String aiGender; // The gender the AI should act as

//   const ChatScreen({
//     super.key,
//     required this.roomId,
//     this.partnerName = "Stranger",
//     this.isAi = false,
//     this.roomType = "dating",
//     this.aiGender = "female",
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => ChatBloc(ChatRepository())..add(LoadMessages(widget.roomId)),
//       child: _ChatView(
//         roomId: widget.roomId,
//         partnerName: widget.partnerName,
//         isAi: widget.isAi,
//         roomType: widget.roomType,
//         aiGender: widget.aiGender,
//       ),
//     );
//   }
// }

// class _ChatView extends StatefulWidget {
//   final String roomId;
//   final String partnerName;
//   final bool isAi;
//   final String roomType;
//   final String aiGender;

//   const _ChatView({
//     required this.roomId,
//     required this.partnerName,
//     required this.isAi,
//     required this.roomType,
//     required this.aiGender,
//   });

//   @override
//   State<_ChatView> createState() => _ChatViewState();
// }

// // Ensure you import the new widget:
// // import '../widgets/typewriter_chat_bubble.dart';

// class _ChatViewState extends State<_ChatView> with SingleTickerProviderStateMixin {
//   final TextEditingController _textController = TextEditingController();
//   final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
//   // AI CLUSTER SERVICES
//   final AiService _aiService = AiService();
//   final ActionQueueManager _actionDirector = ActionQueueManager();
  
//   // STATE MANAGEMENT
//   // Stores messages AND actions. 
//   // Structure: { "text": String, "isMe": bool, "timestamp": DateTime, "isAction": bool }
//   final List<Map<String, dynamic>> _aiMessages = []; 
  
//   // TYPING INDICATOR (Only for "waiting" state)
//   final ValueNotifier<bool> _isAiTyping = ValueNotifier(false);

//   // AUDIO ENGINE
//   final ValueNotifier<bool> _isMusicPlaying = ValueNotifier(false);
//   final AudioPlayer _bgmPlayer = AudioPlayer();
//   bool _audioInitialized = false; 

//   final AudioPlayer _sfxPlayer = AudioPlayer(); // For general SFX

// void _playSentSound() {
//   _sfxPlayer.play(AssetSource('sounds/send_msg_sound.mp3'), volume: 0.3);
// }

//   // GAME STATS
//   final ValueNotifier<double> _vibe = ValueNotifier(0.3);
//   final ValueNotifier<double> _trust = ValueNotifier(0.1);
//   final ValueNotifier<double> _tension = ValueNotifier(0.05);
//   final ValueNotifier<int> _turn = ValueNotifier(1);

//   late AnimationController _shakeController;

//   @override
//   void initState() {
//     super.initState();
//     _initAudio();
    
//     _shakeController = AnimationController(
//       duration: const Duration(milliseconds: 500), 
//       vsync: this
//     );

//     // This connects the AI's "shake" command to your existing shake animation
//     _actionDirector.visualEffectStream.listen((effect) {
//       if (effect == 'shake') {
//         _shakeController.forward(from: 0);
//       }
//     });

//     if (widget.isAi) {
//       _actionDirector.actionStream.listen((event) {
//         // 1. Handle Text Arrival
//         if (event.text != null) {
//           _isAiTyping.value = false; // Stop typing indicator
//           _addMessageToLocalList(event.text!, isMe: false);
//         }

//         // 2. Handle Stats
//         if (event.vibe != null) _vibe.value = event.vibe!;
//         if (event.trust != null) _trust.value = event.trust!;
//         if (event.tension != null) _tension.value = event.tension!;

//         // 3. Handle Visual Actions
//         if (event.action != null) {
//           _handleVisualAction(event.action!);


          
//         }

        

        
//       });


      
//     }
//   }

//   // --- AUDIO LOGIC ---
//   Future<void> _initAudio() async {
//     try {
//       await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
//       await _bgmPlayer.setVolume(0.1);
//       await _bgmPlayer.play(AssetSource('sounds/bg1.mp3'));
//       if (mounted) {
//         _isMusicPlaying.value = true;
//         _audioInitialized = true;
//       }
//     } catch (e) {
//       debugPrint("Audio Wait: Browser interaction required.");
//     }
//   }

//   void _resumeAudioOnGesture() {
//     if (!_audioInitialized || _bgmPlayer.state != PlayerState.playing) {
//       _bgmPlayer.resume();
//       _isMusicPlaying.value = true;
//       _audioInitialized = true;
//     }
//   }

// void _handleVisualAction(String actionCode) {
//     String cleanAction = actionCode.replaceAll("//", "").replaceAll("_", " ");
    
//     if (mounted) {
//       setState(() {
//         _aiMessages.insert(0, {
//           // ADDED ID: Ensures this action doesn't reset other messages
//           "id": "act_${DateTime.now().millisecondsSinceEpoch}_${actionCode.length}", 
//           "text": "* $cleanAction *",
//           "isMe": false,
//           "timestamp": DateTime.now(),
//           "isAction": true,
//         });
//       });
//     }

//     if (actionCode.contains("angry") || actionCode.contains("creepy")) {
//       _shakeController.forward(from: 0);
//     }
//     if (actionCode.contains("leave") || actionCode.contains("stand_up")) {
//       _showAiExitDialog();
//     }
//   }
  
// void _addMessageToLocalList(String text, {required bool isMe}) {
//     if (!mounted) return;
//     setState(() {
//       _aiMessages.insert(0, {
//         "id": "msg_${DateTime.now().microsecondsSinceEpoch}", // Unique stable ID
//         "text": text,
//         "isMe": isMe,
//         "timestamp": DateTime.now(),
//         "isAction": false,
//         "isTyped": isMe, // Your messages appear instantly; Partner's will animate
//       });
//     });
//   }
//   // void _addMessageToLocalList(String text, {required bool isMe}) {
//   //   if (!mounted) return;
//   //   setState(() {
//   //     _aiMessages.insert(0, {
//   //       "text": text,
//   //       "isMe": isMe,
//   //       "timestamp": DateTime.now(),
//   //       "isAction": false,
//   //     });
//   //   });
//   // }

//   void _processTurn(String message) {
//     _resumeAudioOnGesture();
//     _turn.value++;
//     // Manual stats logic for human chats
//     if (!widget.isAi) {
//       if (message.length > 15) _trust.value = (_trust.value + 0.03).clamp(0.0, 1.0);
//       if (message.contains("//")) _vibe.value = (_vibe.value + 0.05).clamp(0.0, 1.0);
//     }
//   }

//   @override
//   void dispose() {
//     _bgmPlayer.dispose(); 
//     _isMusicPlaying.dispose();
//     _textController.dispose();
//     _actionDirector.dispose();
//     _shakeController.dispose();
//     _isAiTyping.dispose();
//     _vibe.dispose(); _trust.dispose(); _tension.dispose(); _turn.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _resumeAudioOnGesture,
//       child: AnimatedBuilder(
//         animation: _shakeController,
//         builder: (context, child) {
//           final double offset = (0.5 - _shakeController.value).abs() * 20;
//           return Transform.translate(
//             offset: Offset(_shakeController.isAnimating ? offset : 0, 0),
//             child: child,
//           );
//         },
//         child: Scaffold(
//           backgroundColor: Colors.black,
//           appBar: _buildAppBar(context),
//           body: Column(
//             children: [
//               // 1. STATS HUD
//               ValueListenableBuilder(
//                 valueListenable: _vibe,
//                 builder: (context, v, _) => GameStatsBar(
//                   vibe: v, trust: _trust.value, tension: _tension.value, turnCount: _turn.value
//                 ),
//               ),
              
//               // 2. CHAT AREA (Now contains both messages and actions)
//               Expanded(child: _buildChatArea()),
              
//               // 3. INPUT
//               _buildInputArea(context),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

// Widget _buildChatArea() {
//     // 1. AI CHAT LOGIC
//     if (widget.isAi) {
//       return Stack(
//         children: [
//           // A. The Chat List
//           ListView.builder(
//             reverse: true,
//             addAutomaticKeepAlives: true,
//             padding: const EdgeInsets.fromLTRB(10, 20, 10, 50),
//             itemCount: _aiMessages.length,
//             itemBuilder: (context, index) {

//               // ... inside itemBuilder ...
//               final msg = _aiMessages[index];
//               final String uniqueId = msg['id'] ?? msg['timestamp'].toString();
              
//               // Ensure we have a valid DateTime object
//               final DateTime msgTime = msg['timestamp'] is DateTime 
//                   ? msg['timestamp'] 
//                   : DateTime.now();

//               // Action Renderer
//               if (msg['isAction'] == true) {
//                 return TypewriterChatBubble(
//                   key: ValueKey("act_$uniqueId"),
//                   text: msg['text'].toString().toUpperCase(),
//                   isMe: false,
//                   isAlreadyTyped: msg['isTyped'] ?? false,
//                   onFinished: () => msg['isTyped'] = true,
//                   startTime: msgTime, // <--- PASS IT HERE
//                   isSystemAction: true,
//                 );
//               }

//               // Normal Message Renderer
//               return TypewriterChatBubble(
//                 key: ValueKey("msg_$uniqueId"),
//                 text: msg['text'],
//                 isMe: msg['isMe'],
//                 isAlreadyTyped: msg['isTyped'] ?? false,
//                 onFinished: () => msg['isTyped'] = true,
//                 startTime: msgTime, // <--- PASS IT HERE
//                 isSystemAction: false,
//               );

              
//             },
//           ),

//           // Sits on top of chat, but below UI controls.
//           // It handles the Pink/Red glows and Dark Vignettes.
//           VisualFxOverlay(effectStream: _actionDirector.visualEffectStream),

//           // B. Typing Indicator (Bottom Left)
//           Positioned(
//             bottom: 30, // Raised slightly so it doesn't overlap with Inactivity Monitor
//             left: 20,
//             child: ValueListenableBuilder<bool>(
//               valueListenable: _isAiTyping,
//               builder: (context, isTyping, child) {
//                 if (!isTyping) return const SizedBox.shrink();
//                 return const Text(
//                   "// Neon is typing...",
//                   style: TextStyle(color: Colors.grey, fontFamily: 'Courier', fontSize: 11),
//                 );
//               },
//             ),
//           ),

//           // C. Inactivity Monitor (Bottom Overlay) - FIXED LOCATION
//           Positioned(
//             bottom: 0, 
//             left: 0, 
//             right: 0,
//             child: InactivityMonitor(
//               lastActivityTime: _aiMessages.isNotEmpty 
//                   ? _aiMessages.first['timestamp'] 
//                   : DateTime.now(),
//               onTimeout: () => _showAiExitDialog(),
//             ),
//           ),
//         ],
//       );
//     }

//     // 2. HUMAN CHAT LOGIC
//     return BlocConsumer<ChatBloc, ChatState>(
//       listener: (context, state) {
//         if (state is ChatEnded) Navigator.pop(context);
//       },
//       builder: (context, state) {
//         if (state is ChatLoaded) {
//           return Stack(
//             children: [
//               ListView.builder(
//                 reverse: true,
//                 addAutomaticKeepAlives: true,
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
//                 itemCount: state.messages.length,
//                 itemBuilder: (context, index) {
//                   final msg = state.messages[index];
//                   final isMe = msg.senderId == myUid;

//                   return TypewriterChatBubble(
//                     key: ValueKey(msg.id),
//                     text: msg.text,
//                     isMe: isMe,
//                     isAlreadyTyped: isMe ? true : (msg.isTyped ?? false),
//                     onFinished: () => msg.isTyped = true,
                    
//                     // --- THE FIX: Pass the timestamp here too ---
//                     startTime: msg.timestamp, 
//                     // --------------------------------------------
                    
//                     isSystemAction: false,
//                   );
//                 },
//               ),
              
//               // Inactivity Monitor for Humans
//               Positioned(
//                 bottom: 0, left: 0, right: 0,
//                 child: InactivityMonitor(
//                   lastActivityTime: state.messages.isNotEmpty ? state.messages.first.timestamp : DateTime.now(),
//                   onTimeout: () => context.read<ChatBloc>().add(EndChat(widget.roomId)),
//                 ),
//               ),
//             ],
//           );
//         }
//         return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
//       },
//     ); 
    
//   }





// Widget _buildInputArea(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: Colors.grey[900], 
//         border: Border(top: BorderSide(color: Colors.grey[800]!))
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _textController,
//               style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier'), 
//               // 1. KEYBINDING: Configures the "Enter" key on hardware and virtual keyboards
//               textInputAction: TextInputAction.send,
//               onSubmitted: (value) => _handleSend(value), // Triggers when Enter is pressed
//               decoration: InputDecoration(
//                 hintText: "[SAY] > ...",
//                 hintStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.3)),
//                 filled: true, fillColor: Colors.black,
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           IconButton(
//             icon: const Icon(Icons.send, color: Colors.pinkAccent),
//             onPressed: () => _handleSend(_textController.text),
//           )
//         ],
//       ),
//     );
//   }

//   // 2. CONSOLIDATED SEND HANDLER (Logic with Sound)
//   Future<void> _handleSend(String rawText) async {
//     final text = rawText.trim();
//     if (text.isEmpty) return;

//     // A. Clear and Play Sent Sound
//     _textController.clear();
//     _playSentSound(); // Triggers the existing _playSentSound method
//     _processTurn(text);

//     // B. Add User Message Locally
//     _addMessageToLocalList(text, isMe: true);

//     if (widget.isAi) {
//       _isAiTyping.value = true;
//       _actionDirector.interrupt(); 
      
//       try {
//         final aiResponse = await _aiService.sendMessage(
//           message: text,
//           aiTargetGender: widget.aiGender,
//           userGender: "male", 
//           roomType: widget.roomType,
//         );
//         _actionDirector.processAiResponse(aiResponse);
//       } catch (e) {
//         _isAiTyping.value = false;
//         debugPrint("AI Failure: $e");
//       }
//     } else {
//       context.read<ChatBloc>().add(SendMessage(widget.roomId, text));
//     }
//   }

//   AppBar _buildAppBar(BuildContext context) {
//     return AppBar(
//       backgroundColor: Colors.grey[900],
//       title: Text(
//         widget.partnerName.toUpperCase(), 
//         style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2)
//       ),
//       centerTitle: true,
//       actions: [
//         ValueListenableBuilder<bool>(
//           valueListenable: _isMusicPlaying,
//           builder: (context, isPlaying, child) => IconButton(
//             icon: Icon(isPlaying ? Icons.volume_up : Icons.volume_off, color: Colors.pinkAccent),
//             onPressed: () {
//               _isMusicPlaying.value = !isPlaying;
//               isPlaying ? _bgmPlayer.pause() : _bgmPlayer.resume();
//             },
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
//           onPressed: () => _showEndChatDialog(context),
//         )
//       ],
//     );
//   }

//   void _showAiExitDialog() {
//     showDialog(
//       context: context, 
//       barrierDismissible: false,
//       builder: (dialogContext) => AlertDialog(
//         backgroundColor: Colors.black,
//         title: const Text("CONNECTION SEVERED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
//         content: const Text("The session was terminated by the partner. Response window closed.", style: TextStyle(color: Colors.white70)),
//         actions: [
//           TextButton(
//             onPressed: () {
//               // Standard navigation pop
//               Navigator.of(dialogContext).pop(); 
//               if (mounted && Navigator.canPop(context)) {
//                 Navigator.of(context).pop();
//               }
//             }, 
//             child: const Text("RETURN TO CITY", style: TextStyle(color: Colors.pinkAccent))
//           )
//         ],
//       )
//     );
//   }

//   void _showEndChatDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (c) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         title: const Text("ABORT MISSION?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
//         content: const Text("The current connection will be terminated permanently.", style: TextStyle(color: Colors.white70)),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(c), child: const Text("STAY", style: TextStyle(color: Colors.grey))),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(c);
//               if (widget.isAi) {
//                 Navigator.pop(context);
//               } else {
//                 context.read<ChatBloc>().add(EndChat(widget.roomId));
//               }
//             },
//             child: const Text("TERMINATE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//   }
// }

