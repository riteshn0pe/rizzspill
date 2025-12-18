import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const ChatBubble({
    super.key, 
    required this.text, 
    required this.isMe
  });

  @override
  Widget build(BuildContext context) {
    // LOGIC: Split "Hello // smiles" -> ["Hello ", " smiles"]
    final parts = text.split('//');
    final mainText = parts[0].trim();
    final actionText = parts.length > 1 ? parts[1].trim() : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          // Modern Gradient for "Me", Dark Grey for "Partner"
          gradient: isMe 
              ? const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFC2185B)]) 
              : null,
          color: isMe ? null : Colors.grey[850],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The Main Text
            Text(
              mainText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            
            // 2. The Action Text (If present)
            if (actionText != null) 
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  "* $actionText *",
                  style: TextStyle(
                    color: isMe ? Colors.white.withOpacity(0.7) : Colors.pinkAccent[100],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}