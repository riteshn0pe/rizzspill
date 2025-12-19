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
  final _controller = StreamController<ActionEvent>.broadcast();
  Stream<ActionEvent> get actionStream => _controller.stream;
  
  final List<Timer> _activeTimers = [];

  /// Processes the JSON response from AiService
  void processAiResponse(Map<String, dynamic> data) {
    // 1. Extract Spoken Text and Parameters
    final String message = data['message'] ?? "...";
    final Map<String, dynamic> params = data['parameters'] ?? {};
    
    // 2. Emit the immediate text and the updated game stats
    _controller.add(ActionEvent(
      text: message,
      vibe: (params['vibe'] as num?)?.toDouble(),
      trust: (params['trust'] as num?)?.toDouble(),
      tension: (params['tension'] as num?)?.toDouble(),
    ));

    // 3. Parse and schedule the 5-step action sequence
    final List<dynamic> actionList = data['actions'] ?? [];
    int cumulativeDelay = 0;

    for (var actionMap in actionList) {
      final String code = actionMap['code'] ?? "";
      final int delay = actionMap['delay'] ?? 0;
      
      // We add delays cumulatively if the AI sends them as intervals 
      // (1s, then 10s later, then 10s later...)
      cumulativeDelay += delay;

      final timer = Timer(Duration(seconds: cumulativeDelay), () {
        if (!_controller.isClosed) {
          _controller.add(ActionEvent(action: code));
        }
      });
      _activeTimers.add(timer);
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
  }
}