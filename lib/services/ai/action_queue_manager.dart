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

  /// Processes the JSON response from AiService
  void processAiResponse(Map<String, dynamic> data) {
    // A. Emit Immediate Text & Stats
    final String message = data['message'] ?? "...";
    final Map<String, dynamic> params = data['parameters'] ?? {};
    
    _controller.add(ActionEvent(
      text: message,
      vibe: (params['vibe'] as num?)?.toDouble(),
      trust: (params['trust'] as num?)?.toDouble(),
      tension: (params['tension'] as num?)?.toDouble(),
    ));

    // B. Parse and Schedule Actions
    final List<dynamic> actionList = data['actions'] ?? [];
    int cumulativeDelay = 0;

    for (var actionMap in actionList) {
      final String code = actionMap['code'] ?? "";
      
      // --- THE TIMING FIX STARTS HERE ---
      // We grab the delay the AI suggested
      int rawDelay = actionMap['delay'] ?? 0;

      // FIX: If AI suggests a fast delay (< 5s), force it to 10s.
      // Exception: The very first action (when cumulativeDelay is 0) can be fast (1s).
      if (rawDelay < 5 && cumulativeDelay > 0) {
         rawDelay = 10; 
      }
      // --- TIMING FIX ENDS ---

      // Accumulate delays so actions happen in sequence
      cumulativeDelay += rawDelay;

      final timer = Timer(Duration(seconds: cumulativeDelay), () {
        if (!_controller.isClosed) {
          // 1. Send action to Chat UI (Typewriter effect)
          _controller.add(ActionEvent(action: code));
          
          // 2. Send trigger to Visual FX Layer (Glow/Shake)
          _detectAndTriggerVisuals(code);
        }
      });
      _activeTimers.add(timer);
    }
  }

  /// Analyzes the action string to trigger specific visual effects
  void _detectAndTriggerVisuals(String actionCode) {
    final lowerCode = actionCode.toLowerCase();

    // ROMANCE / FLIRTY -> Pink Glow
    if (lowerCode.contains("leaning") || 
        lowerCode.contains("close") || 
        lowerCode.contains("blush") ||
        lowerCode.contains("bite") ||
        lowerCode.contains("touch")) {
      _visualFxController.add("romance_pulse");
    } 
    // ANGER / SHOCK -> Screen Shake
    else if (lowerCode.contains("angry") || 
             lowerCode.contains("slam") || 
             lowerCode.contains("shout") ||
             lowerCode.contains("stand_up") ||
             lowerCode.contains("glitch") || 
             lowerCode.contains("leave")) {
      _visualFxController.add("shake");
    } 
    // INTIMACY / FOCUS -> Vignette Darkening
    else if (lowerCode.contains("serious") || 
             lowerCode.contains("whisper") ||
             lowerCode.contains("stare") ||
             lowerCode.contains("eye_contact")) {
      _visualFxController.add("focus_vignette");
    }
  }

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