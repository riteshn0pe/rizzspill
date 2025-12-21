import 'dart:async';

class ActionEvent {
  final String? text;
  final String? action;
  final double? vibe;
  final double? trust;
  final double? tension;

  ActionEvent({
    this.text, 
    this.action, 
    this.vibe, 
    this.trust, 
    this.tension
  });
}

class ActionQueueManager {
  // 1. Existing Action Stream (For Text/UI)
  final _controller = StreamController<ActionEvent>.broadcast();
  Stream<ActionEvent> get actionStream => _controller.stream;
  
  // 2. Visual Effect Stream (For Screen Shake/Glow)
  final _visualFxController = StreamController<String>.broadcast();
  Stream<String> get visualEffectStream => _visualFxController.stream;
  
  final List<Timer> _activeTimers = [];
// --- UPDATED PROCESS LOGIC WITH TYPING LATENCY ---
  void processAiResponse(Map<String, dynamic> data) {
    final String message = data['message'] ?? "...";
    final Map<String, dynamic> params = data['parameters'] ?? {};

    // 1. CALCULATE INTELLIGENT LATENCY
    // Short msg (hi) = 1.5s delay. Long msg (paragraph) = 4s delay.
    // This makes the AI feel like it is "thinking" and "typing".
    int typingDelay = _calculateTypingDelay(message);

    // 2. SCHEDULE THE TEXT ARRIVAL
    Timer(Duration(seconds: typingDelay), () {
      if (_controller.isClosed) return;

      // Emit Text & Stats
      _controller.add(ActionEvent(
        text: message,
        vibe: (params['vibe'] as num?)?.toDouble(),
        trust: (params['trust'] as num?)?.toDouble(),
        tension: (params['tension'] as num?)?.toDouble(),
      ));

      // 3. SCHEDULE ACTIONS (Relative to the text arrival)
      _scheduleActions(data['actions'] ?? []);
    });
  }

  // Helper to determine how long the AI "thinks"
  int _calculateTypingDelay(String text) {
    if (text.length < 10) return 1;  // Instant for "No." or "Hi"
    if (text.length < 50) return 2;  // Fast for short sentences
    if (text.length < 150) return 3; // Medium
    return 5;                        // Long pause for paragraphs
  }

  // Helper to schedule the actions list (Moved out for clarity)
  void _scheduleActions(List<dynamic> actionList) {
    int cumulativeDelay = 0; // Starts immediately after text arrives

    for (var actionMap in actionList) {
      final String code = actionMap['code'] ?? "";
      
      // Keep your existing minimum delay logic
      int rawDelay = actionMap['delay'] ?? 0;
      if (rawDelay < 5 && cumulativeDelay > 0) rawDelay = 10;
      cumulativeDelay += rawDelay;

      final timer = Timer(Duration(seconds: cumulativeDelay), () {
        if (!_controller.isClosed) {
          _controller.add(ActionEvent(action: code));
          _detectAndTriggerVisuals(code);
        }
      });
      _activeTimers.add(timer);
    }
  }

  // --- UPDATED VISUALS WITH COLORS & WINNING ---
  void _detectAndTriggerVisuals(String actionCode) {
    final lowerCode = actionCode.toLowerCase();

    // 1. LOVE (Pink Hearts)
    if (lowerCode.contains("kiss") || 
        lowerCode.contains("blush") || 
        lowerCode.contains("heart") ||
        lowerCode.contains("love") ||
        lowerCode.contains("bite_lip")) {
      _visualFxController.add("romance_hearts"); // NEW KEY
    } 
    // 2. ANGER (Red Flash + Text)
    else if (lowerCode.contains("angry") || 
             lowerCode.contains("shout") || 
             lowerCode.contains("hate") ||
             lowerCode.contains("slap")) {
      _visualFxController.add("anger_pulse"); // NEW KEY
    } 
    // 3. WINNING (Green Glow - for Debate)
    else if (lowerCode.contains("agree") || 
             lowerCode.contains("good_point") || 
             lowerCode.contains("you_win") || 
             lowerCode.contains("nod")) {
      _visualFxController.add("win_glow"); // NEW KEY
    }
    // 4. EXISTING EFFECTS
    else if (lowerCode.contains("shake") || lowerCode.contains("glitch")) {
      _visualFxController.add("shake");
    }
    else if (lowerCode.contains("stare") || lowerCode.contains("silence")) {
      _visualFxController.add("focus_vignette");
    }
  }
  // /// Processes the JSON response from AiService
  // void processAiResponse(Map<String, dynamic> data) {
  //   // A. Emit Immediate Text & Stats
  //   final String message = data['message'] ?? "...";
  //   final Map<String, dynamic> params = data['parameters'] ?? {};
    
  //   _controller.add(ActionEvent(
  //     text: message,
  //     vibe: (params['vibe'] as num?)?.toDouble(),
  //     trust: (params['trust'] as num?)?.toDouble(),
  //     tension: (params['tension'] as num?)?.toDouble(),
  //   ));

  //   // B. Parse and Schedule Actions
  //   final List<dynamic> actionList = data['actions'] ?? [];
  //   int cumulativeDelay = 0;

  //   for (var actionMap in actionList) {
  //     final String code = actionMap['code'] ?? "";
      
  //     // --- THE TIMING FIX STARTS HERE ---
  //     // We grab the delay the AI suggested
  //     int rawDelay = actionMap['delay'] ?? 0;

  //     // FIX: If AI suggests a fast delay (< 5s), force it to 10s.
  //     // Exception: The very first action (when cumulativeDelay is 0) can be fast (1s).
  //     if (rawDelay < 5 && cumulativeDelay > 0) {
  //        rawDelay = 10; 
  //     }
  //     // --- TIMING FIX ENDS ---

  //     // Accumulate delays so actions happen in sequence
  //     cumulativeDelay += rawDelay;

  //     final timer = Timer(Duration(seconds: cumulativeDelay), () {
  //       if (!_controller.isClosed) {
  //         // 1. Send action to Chat UI (Typewriter effect)
  //         _controller.add(ActionEvent(action: code));
          
  //         // 2. Send trigger to Visual FX Layer (Glow/Shake)
  //         _detectAndTriggerVisuals(code);
  //       }
  //     });
  //     _activeTimers.add(timer);
  //   }
  // }

  // /// Analyzes the action string to trigger specific visual effects
  // void _detectAndTriggerVisuals(String actionCode) {
  //   final lowerCode = actionCode.toLowerCase();

  //   // ROMANCE / FLIRTY -> Pink Glow
  //   if (lowerCode.contains("leaning") || 
  //       lowerCode.contains("close") || 
  //       lowerCode.contains("blush") ||
  //       lowerCode.contains("bite") ||
  //       lowerCode.contains("touch")) {
  //     _visualFxController.add("romance_pulse");
  //   } 
  //   // ANGER / SHOCK -> Screen Shake
  //   else if (lowerCode.contains("angry") || 
  //            lowerCode.contains("slam") || 
  //            lowerCode.contains("shout") ||
  //            lowerCode.contains("stand_up") ||
  //            lowerCode.contains("glitch") || 
  //            lowerCode.contains("leave")) {
  //     _visualFxController.add("shake");
  //   } 
  //   // INTIMACY / FOCUS -> Vignette Darkening
  //   else if (lowerCode.contains("serious") || 
  //            lowerCode.contains("whisper") ||
  //            lowerCode.contains("stare") ||
  //            lowerCode.contains("eye_contact")) {
  //     _visualFxController.add("focus_vignette");
  //   }
  // }

  void interrupt() {
    for (var timer in _activeTimers) {
      if (timer.isActive) timer.cancel();
    }
    _activeTimers.clear();
  }

  void dispose() {
    interrupt();
    _controller.close();
    _visualFxController.close(); 
  }
}

// import 'dart:async';

// class ActionEvent {
//   final String? text;
//   final String? action;
//   final double? vibe;
//   final double? trust;
//   final double? tension;

//   ActionEvent({
//     this.text, 
//     this.action, 
//     this.vibe, 
//     this.trust, 
//     this.tension
//   });
// }

// class ActionQueueManager {
//   final _controller = StreamController<ActionEvent>.broadcast();
//   Stream<ActionEvent> get actionStream => _controller.stream;
  
//   final List<Timer> _activeTimers = [];

//   /// Processes the JSON response from AiService
//   void processAiResponse(Map<String, dynamic> data) {
//     // 1. Extract Spoken Text and Parameters
//     final String message = data['message'] ?? "...";
//     final Map<String, dynamic> params = data['parameters'] ?? {};
    
//     // 2. Emit the immediate text and the updated game stats
//     _controller.add(ActionEvent(
//       text: message,
//       vibe: (params['vibe'] as num?)?.toDouble(),
//       trust: (params['trust'] as num?)?.toDouble(),
//       tension: (params['tension'] as num?)?.toDouble(),
//     ));

//     // 3. Parse and schedule the 5-step action sequence
//     final List<dynamic> actionList = data['actions'] ?? [];
//     int cumulativeDelay = 0;

//     for (var actionMap in actionList) {
//       final String code = actionMap['code'] ?? "";
//       final int delay = actionMap['delay'] ?? 0;
      
//       // We add delays cumulatively if the AI sends them as intervals 
//       // (1s, then 10s later, then 10s later...)
//       cumulativeDelay += delay;

//       final timer = Timer(Duration(seconds: cumulativeDelay), () {
//         if (!_controller.isClosed) {
//           _controller.add(ActionEvent(action: code));
//         }
//       });
//       _activeTimers.add(timer);
//     }
//   }

//   void interrupt() {
//     for (var timer in _activeTimers) {
//       if (timer.isActive) timer.cancel();
//     }
//     _activeTimers.clear();
//   }

//   void dispose() {
//     interrupt();
//     _controller.close();
//   }
// }