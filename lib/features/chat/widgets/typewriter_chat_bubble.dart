import 'package:flutter/material.dart';
import 'package:virtual_dating/features/chat/widgets/typing_sound_controller.dart';


class TypewriterChatBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final bool isAlreadyTyped; 
  final VoidCallback onFinished; 
  final bool isSystemAction;
  
  // NEW: We need the exact time this message was created to sync animation
  final DateTime startTime; 

  const TypewriterChatBubble({
    required Key key, 
    required this.text,
    required this.isMe,
    required this.isAlreadyTyped,
    required this.onFinished,
    required this.startTime, // Add this required parameter
    this.isSystemAction = false,
  }) : super(key: key);

  @override
  State<TypewriterChatBubble> createState() => _TypewriterChatBubbleState();
}

class _TypewriterChatBubbleState extends State<TypewriterChatBubble> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    
    TypingSoundController().init();

    // 1. Calculate how long the typing SHOULD take
    final totalMilliseconds = 60 * widget.text.length;
    final duration = Duration(milliseconds: totalMilliseconds);
    
    _controller = AnimationController(vsync: this, duration: duration);
    
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // 2. THE GLITCH FIX: Calculate progress based on Real Time
    if (widget.isMe || widget.isAlreadyTyped) {
      _controller.value = 1.0;
    } else {
      // How much time has passed since the message was added?
      final elapsed = DateTime.now().difference(widget.startTime).inMilliseconds;
      
      // Calculate percentage (0.0 to 1.0)
      final double progress = (elapsed / totalMilliseconds).clamp(0.0, 1.0);
      
      // Resume exactly from that percentage (e.g., jump to 50% immediately)
      _controller.value = progress;
      
      if (progress < 1.0) {
        _controller.forward();
      } else {
        // If enough time passed that it should be done, mark it done immediately
        widget.onFinished();
      }
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        if (!widget.isMe && !widget.isAlreadyTyped) {
           TypingSoundController().startTyping();
        }
      } else if (status == AnimationStatus.completed) {
        if (!widget.isMe && !widget.isAlreadyTyped) {
           TypingSoundController().stopTyping();
        }
        widget.onFinished(); 
      }
    });
  }

  @override
  void didUpdateWidget(TypewriterChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the widget updates but it's the same message, DO NOT reset.
    if (widget.text != oldWidget.text) {
      _controller.duration = Duration(milliseconds: 60 * widget.text.length);
      if (widget.isAlreadyTyped || widget.isMe) {
        _controller.value = 1.0;
        TypingSoundController().stopTyping();
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    if (_controller.isAnimating && !widget.isMe && !widget.isAlreadyTyped) {
      TypingSoundController().stopTyping();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.isSystemAction) {
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: _buildAnimatedText(),
      );
    }
    
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.pinkAccent.withOpacity(0.2) : Colors.grey[900],
          border: Border.all(
            color: widget.isMe ? Colors.pinkAccent : Colors.grey[700]!,
            width: 1
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildAnimatedText(),
      ),
    );
  }

  Widget _buildAnimatedText() {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final visibleChars = _characterCount.value.clamp(0, widget.text.length);
        return Text(
          widget.text.substring(0, visibleChars), 
          style: _textStyle()
        );
      },
    );
  }

  TextStyle _textStyle() {
    if (widget.isSystemAction) {
      return TextStyle(
        color: Colors.pinkAccent.withOpacity(0.8),
        fontFamily: 'Courier',
        fontSize: 12,
        fontStyle: FontStyle.italic,
        letterSpacing: 1.2,
      );
    }
    return TextStyle(
      color: widget.isMe ? Colors.white : Colors.greenAccent,
      fontFamily: 'Courier',
      fontSize: 14,
      height: 1.4,
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:virtual_dating/features/chat/widgets/typing_sound_controller.dart';


// class TypewriterChatBubble extends StatefulWidget {
//   final String text;
//   final bool isMe;
//   final bool isAlreadyTyped; 
//   final VoidCallback onFinished; 
//   final bool isSystemAction; 

//   const TypewriterChatBubble({
//     required Key key, // Mandatory key for list stability
//     required this.text,
//     required this.isMe,
//     required this.isAlreadyTyped,
//     required this.onFinished,
//     this.isSystemAction = false,
//   }) : super(key: key);

//   @override
//   State<TypewriterChatBubble> createState() => _TypewriterChatBubbleState();
// }

// class _TypewriterChatBubbleState extends State<TypewriterChatBubble> 
//     with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
//   late AnimationController _controller;
//   late Animation<int> _characterCount;

//   @override
//   bool get wantKeepAlive => true; // Prevents disposal during scrolling

//   @override
//   void initState() {
//     super.initState();
    
//     // 2. INIT THE SHARED CONTROLLER (Safe to call multiple times)
//     TypingSoundController().init();

//     // 60ms/char for natural speed
//     final duration = Duration(milliseconds: 60 * widget.text.length);
//     _controller = AnimationController(vsync: this, duration: duration);
    
//     _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.linear),
//     );

//     // 3. LOGIC: Delegate Start/Stop to the Global Controller
//     _controller.addStatusListener((status) {
//       if (status == AnimationStatus.forward) {
//         // Only trigger sound for the AI (Partner)
//         if (!widget.isMe && !widget.isAlreadyTyped) {
//            TypingSoundController().startTyping();
//         }
//       } else if (status == AnimationStatus.completed) {
//         // Stop sound only if we started it
//         if (!widget.isMe && !widget.isAlreadyTyped) {
//            TypingSoundController().stopTyping();
//         }
//         widget.onFinished(); // Lock the data
//       }
//     });

//     // CRITICAL SYNC LOGIC
//     if (widget.isMe || widget.isAlreadyTyped) {
//       _controller.value = 1.0; 
//     } else {
//       _controller.forward();
//     }
//   }

//   @override
//   void didUpdateWidget(TypewriterChatBubble oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.text != oldWidget.text) {
//       _controller.duration = Duration(milliseconds: 60 * widget.text.length);
//       if (widget.isAlreadyTyped || widget.isMe) {
//         _controller.value = 1.0;
//         // Ensure sound stops if we force-finish via update
//         TypingSoundController().stopTyping();
//       } else {
//         _controller.forward(from: 0.0);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     // 4. SAFETY STOP: If destroyed while animating (e.g., navigating away)
//     if (_controller.isAnimating && !widget.isMe && !widget.isAlreadyTyped) {
//       TypingSoundController().stopTyping();
//     }
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context); // Required for KeepAlive
    
//     // If it is a system action, we use a different container style (centered, no box)
//     if (widget.isSystemAction) {
//       return Container(
//         alignment: Alignment.center,
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         child: _buildAnimatedText(),
//       );
//     }
    
//     return Align(
//       alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: widget.isMe ? Colors.pinkAccent.withOpacity(0.2) : Colors.grey[900],
//           border: Border.all(
//             color: widget.isMe ? Colors.pinkAccent : Colors.grey[700]!,
//             width: 1
//           ),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: _buildAnimatedText(),
//       ),
//     );
//   }

//   Widget _buildAnimatedText() {
//     return AnimatedBuilder(
//       animation: _characterCount,
//       builder: (context, child) {
//         final visibleChars = _characterCount.value.clamp(0, widget.text.length);
//         return Text(
//           widget.text.substring(0, visibleChars), 
//           style: _textStyle()
//         );
//       },
//     );
//   }

//   TextStyle _textStyle() {
//     if (widget.isSystemAction) {
//       return TextStyle(
//         color: Colors.pinkAccent.withOpacity(0.8),
//         fontFamily: 'Courier',
//         fontSize: 12,
//         fontStyle: FontStyle.italic,
//         letterSpacing: 1.2, // Spacing for cinematic effect
//       );
//     }
//     return TextStyle(
//       color: widget.isMe ? Colors.white : Colors.greenAccent,
//       fontFamily: 'Courier',
//       fontSize: 14,
//       height: 1.4,
//     );
//   }
// }

