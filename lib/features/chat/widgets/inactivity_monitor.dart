import 'dart:async';
import 'package:flutter/material.dart';

class InactivityMonitor extends StatefulWidget {
  final DateTime lastActivityTime;
  final VoidCallback onTimeout;

  const InactivityMonitor({
    super.key,
    required this.lastActivityTime,
    required this.onTimeout,
  });

  @override
  State<InactivityMonitor> createState() => _InactivityMonitorState();
}

class _InactivityMonitorState extends State<InactivityMonitor> {
  Timer? _timer;
  int _secondsRemaining = 45;
  bool _isWarning = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  // This is the brain of the logic: it runs every second to check the time
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // 1. Calculate how long it has been since the last message in the BLoC state
      final difference = DateTime.now().difference(widget.lastActivityTime);
      final secondsSilent = difference.inSeconds;
      
      // 2. Calculate remaining time out of your 20-second limit
      final timeLeft = 45 - secondsSilent;

      setState(() {
        _secondsRemaining = timeLeft;
        
        // 3. Trigger the Warning: only show the red UI if 10 seconds or less remain
        _isWarning = timeLeft <= 10;
      });

      // 4. Trigger the Room Exit: if time hits zero, tell the ChatScreen to end the session
      if (timeLeft <= 0) {
        timer.cancel();
        widget.onTimeout(); 
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: stop the timer when the user leaves the chat
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show the UI during the final 10-second countdown
    if (!_isWarning || _secondsRemaining < 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.red.withOpacity(0.2), // Cyberpunk red tint
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
          const SizedBox(width: 10),
          Text(
            "Make chat active...\nOtherwise TERMINATING IN $_secondsRemaining",
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'Courier', // Matches your terminal style
            ),
          ),
        ],
      ),
    );
  }
}