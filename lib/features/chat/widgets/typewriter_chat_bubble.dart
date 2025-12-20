import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class TypewriterChatBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final bool isAlreadyTyped; 
  final VoidCallback onFinished; 
  final bool isSystemAction; 

  const TypewriterChatBubble({
    required Key key, // Mandatory key for list stability
    required this.text,
    required this.isMe,
    required this.isAlreadyTyped,
    required this.onFinished,
    this.isSystemAction = false,
  }) : super(key: key);

  @override
  State<TypewriterChatBubble> createState() => _TypewriterChatBubbleState();
}

class _TypewriterChatBubbleState extends State<TypewriterChatBubble> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  late AnimationController _controller;
  late Animation<int> _characterCount;

  // 1. CLASS-LEVEL AUDIO PLAYER (Accessible by all methods)
  final AudioPlayer _typeSoundPlayer = AudioPlayer();

  @override
  bool get wantKeepAlive => true; // Prevents the bubble from resetting when scrolling

  @override
  void initState() {
    super.initState();
    
    // 60ms/char for natural speed
    final duration = Duration(milliseconds: 60 * widget.text.length);
    _controller = AnimationController(vsync: this, duration: duration);
    
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // 2. STATUS LISTENER: Triggers the master lock in parent data
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished(); 
      }
    });

    // 3. SOUND LISTENER: Plays the click on every character change
    _characterCount.addListener(() {
      // Play sound only for the AI partner while the text is actively typing
      if (!widget.isMe && !widget.isAlreadyTyped && _controller.isAnimating) {
        _playClick();
      }
    });

    // 4. CRITICAL SYNC LOGIC
    // If it's your message OR already typed, show immediately. Otherwise, animate.
    if (widget.isMe || widget.isAlreadyTyped) {
      _controller.value = 1.0; 
    } else {
      _controller.forward();
    }
  }

  // Optimized sound trigger using a low volume mechanical click
  Future<void> _playClick() async {
    try {
      // Ensure the sound file path matches your assets folder
      await _typeSoundPlayer.play(
        AssetSource('sounds/keyboard_typing_sound.mp3'), 
        volume: 0.1
      );
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    }
  }

  @override
  void didUpdateWidget(TypewriterChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _controller.duration = Duration(milliseconds: 60 * widget.text.length);
      if (widget.isAlreadyTyped || widget.isMe) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    // 5. CLEANUP: Prevent memory leaks and background audio play
    _typeSoundPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
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
// import 'package:audioplayers/audioplayers.dart';

// class TypewriterChatBubble extends StatefulWidget {
//   final String text;
//   final bool isMe;
//   final bool isAlreadyTyped; // Master lock from parent data
//   final VoidCallback onFinished; // Callback to lock the data
//   final bool isSystemAction; // New property for styling actions

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

//   final AudioPlayer _typeSoundPlayer = AudioPlayer();

//   @override
//   bool get wantKeepAlive => true; // Prevents disposal during scrolling

//   @override
//   void initState() {
//     super.initState();
    
//     // 60ms/char for natural speed
//     final duration = Duration(milliseconds: 60 * widget.text.length);
//     _controller = AnimationController(vsync: this, duration: duration);
    
//     _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.linear),
//     );

//     _controller.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         widget.onFinished(); // Persistent lock in parent data
//       }
//     }
    
    
//     );

    


//     // Add a listener to play sound on character change
//   _characterCount.addListener(() {
//     // Only play sound if it's NOT the user's message and NOT already typed
//     if (!widget.isMe && !widget.isAlreadyTyped) {
//       _playClick();
//     }
//   });

//     // CRITICAL SYNC LOGIC
//     // If it's your message OR the data says it's already typed, 
//     // we set the controller to 1.0 immediately.
//     if (widget.isMe || widget.isAlreadyTyped) {
//       _controller.value = 1.0; 
//     } else {
//       _controller.forward();
//     }
//   }


  



//   Future<void> _playClick() async {
//   // Use a low volume so it's not annoying
//   await _typeSoundPlayer.play(AssetSource('sounds/keyboard_typing_sound.mp3'), volume: 0.1);
// }

//   // Handle case where the list item is reused for a different message
//   @override
//   void didUpdateWidget(TypewriterChatBubble oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.text != oldWidget.text) {
//       _controller.duration = Duration(milliseconds: 60 * widget.text.length);
//       if (widget.isAlreadyTyped || widget.isMe) {
//         _controller.value = 1.0;
//       } else {
//         _controller.forward(from: 0.0);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _typeSoundPlayer.dispose();// CRITICAL: Prevent memory leaks
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
