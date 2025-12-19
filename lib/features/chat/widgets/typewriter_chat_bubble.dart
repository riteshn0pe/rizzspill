import 'package:flutter/material.dart';

class TypewriterChatBubble extends StatefulWidget {
  final String text;
  final bool isMe;
  final bool isAlreadyTyped; // Master lock from parent data
  final VoidCallback onFinished; // Callback to lock the data
  final bool isSystemAction; // New property for styling actions

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

  @override
  bool get wantKeepAlive => true; // Prevents disposal during scrolling

  @override
  void initState() {
    super.initState();
    
    // 60ms/char for natural speed
    final duration = Duration(milliseconds: 60 * widget.text.length);
    _controller = AnimationController(vsync: this, duration: duration);
    
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished(); // Persistent lock in parent data
      }
    });

    // CRITICAL SYNC LOGIC
    // If it's your message OR the data says it's already typed, 
    // we set the controller to 1.0 immediately.
    if (widget.isMe || widget.isAlreadyTyped) {
      _controller.value = 1.0; 
    } else {
      _controller.forward();
    }
  }

  // Handle case where the list item is reused for a different message
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    
    // If it is a system action, we use a different container style (centered, no box)
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
        letterSpacing: 1.2, // Spacing for cinematic effect
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

// class TypewriterChatBubble extends StatefulWidget {
//   final String text;
//   final bool isMe;

//   const TypewriterChatBubble({super.key, required this.text, required this.isMe});

//   @override
//   State<TypewriterChatBubble> createState() => _TypewriterChatBubbleState();
// }

// class _TypewriterChatBubbleState extends State<TypewriterChatBubble> 
//     with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin { // 1. Add Mixin
  
//   late AnimationController _controller;
//   late Animation<int> _characterCount;

//   @override
//   void initState() {
//     super.initState();
//     // 2. Natural Typing Speed: 50ms per character
//     final duration = Duration(milliseconds: 50 * widget.text.length);
    
//     _controller = AnimationController(vsync: this, duration: duration);
//     _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.linear),
//     );

//     _controller.forward();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   // 3. Prevent Re-builds/Re-typing
//   @override
//   bool get wantKeepAlive => true;

//   @override
//   Widget build(BuildContext context) {
//     super.build(context); // Required by Mixin
    
//     return Align(
//       alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//         padding: const EdgeInsets.all(12),
//         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
//         decoration: BoxDecoration(
//           color: widget.isMe ? Colors.pinkAccent.withOpacity(0.2) : Colors.grey[900],
//           border: Border.all(
//             color: widget.isMe ? Colors.pinkAccent : Colors.grey[700]!,
//             width: 1
//           ),
//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(12),
//             topRight: const Radius.circular(12),
//             bottomLeft: widget.isMe ? const Radius.circular(12) : Radius.zero,
//             bottomRight: widget.isMe ? Radius.zero : const Radius.circular(12),
//           ),
//         ),
//         child: AnimatedBuilder(
//           animation: _characterCount,
//           builder: (context, child) {
//             String visibleString = widget.text.substring(0, _characterCount.value);
//             return Text(
//               visibleString,
//               style: TextStyle(
//                 color: widget.isMe ? Colors.white : Colors.greenAccent,
//                 fontFamily: 'Courier',
//                 fontSize: 14,
//                 height: 1.4,
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';

// class TypewriterChatBubble extends StatefulWidget {
//   final String text;
//   final bool isMe;

//   const TypewriterChatBubble({super.key, required this.text, required this.isMe});

//   @override
//   State<TypewriterChatBubble> createState() => _TypewriterChatBubbleState();
// }

// class _TypewriterChatBubbleState extends State<TypewriterChatBubble> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<int> _characterCount;

//   @override
//   void initState() {
//     super.initState();
//     // CHANGED: Increased from 30ms to 60ms for a more natural "reading" pace.
//     final duration = Duration(milliseconds: 100 * widget.text.length);
    
//     _controller = AnimationController(vsync: this, duration: duration);
//     _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.linear),
//     );

//     _controller.forward();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//         padding: const EdgeInsets.all(12),
//         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
//         decoration: BoxDecoration(
//           color: widget.isMe ? Colors.pinkAccent.withOpacity(0.2) : Colors.grey[900],
//           border: Border.all(
//             color: widget.isMe ? Colors.pinkAccent : Colors.grey[700]!,
//             width: 1
//           ),
//           borderRadius: BorderRadius.only(
//             topLeft: const Radius.circular(12),
//             topRight: const Radius.circular(12),
//             bottomLeft: widget.isMe ? const Radius.circular(12) : Radius.zero,
//             bottomRight: widget.isMe ? Radius.zero : const Radius.circular(12),
//           ),
//         ),
//         child: AnimatedBuilder(
//           animation: _characterCount,
//           builder: (context, child) {
//             String visibleString = widget.text.substring(0, _characterCount.value);
//             return Text(
//               visibleString,
//               style: TextStyle(
//                 color: widget.isMe ? Colors.white : Colors.greenAccent,
//                 fontFamily: 'Courier',
//                 fontSize: 14,
//                 height: 1.4,
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
