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

  // --- VOCABULARY LISTS (Scalable & Efficient) ---

  static const _angerWords = [
  'angry', 'pissed', 'mad', 'furious', 'rage', 'hate', 'hateful', 'fuck you', 'asshole',
  'bitch', 'cunt', 'dickhead', 'idiot', 'stupid', 'dumbass', 'moron', 'fuck off', 'shut up',
  'shut the fuck up', 'piss off', 'fuck this', 'fuck that', 'shit', 'bullshit', 'damn',
  'dammit', 'bastard', 'prick', 'wanker', 'cocksucker', 'motherfucker', 'son of a bitch',
  'fuckin', 'fucking', 'fucked up', 'screw you', 'go to hell', 'die', 'kill you',
  'punch', 'slap', 'hit', 'smack', 'pound', 'smash', 'break', 'throw', 'slam', 'stomp',
  'yell', 'scream', 'shout', 'roar', 'ragequit', 'fuckin hate', 'pissed off', 'loser',
  'trash', 'garbage', 'pathetic', 'weak', 'coward', 'bitchass', 'fuckboy', 'fuckgirl'
];

static const _naughtyWords = [
  'fuck', 'fucking', 'fucked', 'dick', 'cock', 'penis', 'pussy', 'cunt', 'clit',
  'ass', 'booty', 'butthole', 'tits', 'boobs', 'breasts', 'nipples', 'cum', 'sperm',
  'jizz', 'blowjob', 'bj', 'handjob', 'hj', '69', 'anal', 'sex', 'sexy', 'horny',
  'horny af', 'wet', 'soaked', 'dripping', 'hard', 'erection', 'boner', 'throbbing',
  'squirt', 'orgasm', 'climax', 'moan', 'scream', 'gasp', 'bite', 'spank', 'slap',
  'whip', 'tie', 'choke', 'pull hair', 'daddy', 'mommy', 'baby', 'babe', 'princess',
  'slut', 'whore', 'dirty', 'naughty', 'kinky', 'threesome', 'fingering', 'lick',
  'suck', 'ride', 'fuck me', 'fuck you', 'pound', 'deep', 'fast', 'slow', 'harder',
  'more', 'yes', 'oh god', 'right there', 'cum inside', 'fill me', 'creampie',
  'nude', 'naked', 'strip', 'tease', 'touch', 'rub', 'stroke', 'fap', 'masturbate',
  'porn', 'hentai', 'thicc', 'juicy', 'perky', 'big dick', 'big tits', 'ass up',
  'doggy', 'missionary', 'cowgirl', 'reverse cowgirl', 'doggystyle', 'cream', 'wetness',
  'panties', 'thong', 'lingerie', 'nudes', 'dick pic', 'pussy pic', 'send nudes',
  'papi', 'mami', 'choke me', 'deeper', 'harder daddy', 'fuck me harder', 'cum for me',
  'cum on me', 'swallow', 'taste', 'lick me', 'eat me out', 'finger me', 'fuck my ass',
  'anal sex', 'butt plug', 'vibrator', 'dildo', 'sex toy', 'bdsm', 'bondage', 'dom',
  'sub', 'master', 'mistress', 'slave', 'collar', 'leash', 'cuck', 'hotwife', 'milf',
  'dilf', 'throat', 'deepthroat', 'gag', 'spit', 'spit roast', 'face fuck', 'face sitting',
  'rimming', 'tongue fuck', 'pussy licking', 'ass licking', 'cumshot', 'facial', 'bukkake'
];

static const _winWords = [
  'win', 'won', 'victory', 'victorious', 'winner', 'champion', 'nailed it', 'slay',
  'killed it', 'crushed it', 'dominated', 'owned', 'got it', 'perfect', 'yes', 'yesss',
  'hell yeah', 'fuck yeah', 'boom', 'gotcha', 'touche', 'checkmate', 'bravo', 'epic',
  'legend', 'god tier', 'top tier', 'best', 'awesome', 'amazing', 'genius', 'smart',
  'clever', 'point', 'good point', 'you are right', 'agreed', 'correct', 'spot on',
  'exactly', 'mic drop', 'pog', 'poggers', 'ez', 'easy', 'clapped', 'destroyed',
  'wrecked', 'smoked', 'rolled', 'carried', 'carry', 'carry me', 'gg', 'good game',
  'wp', 'well played', 'ez clap', 'lets go', 'lfg', 'win streak', 'streak'
];

static const _sadWords = [
  'sad', 'depressed', 'cry', 'crying', 'tears', 'heartbroken', 'broken', 'hurt',
  'pain', 'lonely', 'alone', 'empty', 'lost', 'miss you', 'miss her', 'miss him',
  'miss them', 'broken heart', '💔', 'depressing', 'down', 'low', 'suicidal', 'kill myself',
  'end it', 'hopeless', 'useless', 'worthless', 'failure', 'failed', 'lose', 'lost',
  'defeated', 'bad day', 'shit day', 'awful', 'terrible', 'miserable', 'depressing',
  'heartache', 'heart hurt', 'feel bad', 'feel down', 'feel empty', 'feel nothing',
  'tired of life', 'give up', 'done', 'over it', 'goodbye', 'bye forever'
];

static const _loveWords = [
  'love', 'love you', 'i love you', 'ily', 'i love u', 'miss you', 'miss u', 'baby',
  'babe', 'darling', 'honey', 'sweetheart', 'cutie', 'beautiful', 'gorgeous', 'handsome',
  'adorable', 'cute', 'heart', '❤️', 'heart eyes', 'lovely', 'perfect', 'my love',
  'my everything', 'forever', 'always', 'together', 'us', 'cuddle', 'hug', 'kiss',
  'kisses', 'muah', 'mwah', 'smooch', 'smooches', 'hold me', 'hold you', 'want you',
  'need you', 'crave you', 'obsessed', 'addicted to you', 'my world', 'my heart',
  'soulmate', 'wife', 'husband', 'girlfriend', 'boyfriend', 'gf', 'bf', 'partner',
  'lover', 'date', 'romance', 'romantic', 'sweet', 'sweetie', 'pumpkin', 'angel',
  'princess', 'prince', 'king', 'queen', 'baby girl', 'baby boy', 'my baby'
];

static const _laughWords = [
  'lol', 'lmao', 'lmfao', 'haha', 'hehe', '😂', '🤣', 'funny', 'hilarious', 'rofl',
  'laughing', 'dying', 'dead', 'lololol', 'loll', 'hahaha', 'hehehe', '😂😂', '🤣🤣',
  'laugh', 'giggle', 'chuckle', 'joke', 'joking', 'trolling', 'troll', 'lmao wtf',
  'wtf lol', 'so funny', 'crack up', 'comedy', 'meme', 'memes', 'lit', 'fire', '🔥'
];
  // static const _romanceWords = [
  //   'kiss', 'blush', 'heart', 'love', 'bite', 'hug', 'wink', 'softly', 
  //   'i am ready', 'awww', 'sweet', 'smiling', 'baby', 'darling' , 'beautiful' , 'fucking amazing'
  // ];
  // static const _angerWords = [
  //   'angry', 'shout', 'hate', 'slap', 'slam', 'yell', 'aggressive', 
  //   'stomp', 'fuck', 'dick', 'penis', 'pussy', 'slutt', 'idiot', 'shut up'
  // ];
  // static const _naughtyWords = [
  //   'wet', 'shout', 'hate', 'slap', 'slam', 'yell', 'aggressive', 
  //   'stomp', 'fuck', 'dick', 'penis', 'pussy', 'slutt', 'idiot', 'shut up'
  // ];
  // static const _winWords = [
  //   'agree', 'point', 'win', 'correct', 'nod', 'smart', 'victory', 
  //   'touche', 'you are right', 'good point' , 'won'
  // ];

  /// Processes the JSON response from AiService
  void processAiResponse(Map<String, dynamic> data) {
    final String message = data['message'] ?? "...";
    final Map<String, dynamic> params = data['parameters'] ?? {};

    // 1. CALCULATE INTELLIGENT LATENCY
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

      // NEW: Analyze the MESSAGE text immediately for visual triggers
      // (So if AI says "I love you" without an action code, it still glows pink)
      analyzeTextForVisuals(message);

      // 3. SCHEDULE ACTIONS (Relative to the text arrival)
      _scheduleActions(data['actions'] ?? []);
    });
  }

  // Helper to determine how long the AI "thinks"
  int _calculateTypingDelay(String text) {
    if (text.length < 10) return 1;  
    if (text.length < 50) return 2;  
    if (text.length < 150) return 3; 
    return 5;                        
  }

  // Helper to schedule the actions list
  void _scheduleActions(List<dynamic> actionList) {
    int cumulativeDelay = 0; 

    for (var actionMap in actionList) {
      final String code = actionMap['code'] ?? "";
      
      int rawDelay = actionMap['delay'] ?? 0;
      if (rawDelay < 5 && cumulativeDelay > 0) rawDelay = 10;
      cumulativeDelay += rawDelay;

      final timer = Timer(Duration(seconds: cumulativeDelay), () {
        if (!_controller.isClosed) {
          _controller.add(ActionEvent(action: code));
          // Analyze the ACTION CODE for visual triggers
          analyzeTextForVisuals(code);
        }
      });
      _activeTimers.add(timer);
    }
  }

  /// PUBLIC API: Call this from ChatScreen when the USER sends a message
  /// This ensures "Both of Us" trigger effects.
  void analyzeTextForVisuals(String input) {
    if (_visualFxController.isClosed) return;
    
    final lowerInput = input.toLowerCase();

    // 1. LOVE (Pink Hearts)
    if (_loveWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("romance_pulse");
    }
    // 2. ANGER (
    else if (_angerWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("anger_pulse");
    }
    // 3. Naughty 
    else if (_naughtyWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("naughty_pulse");
    }
    // 4. laugh 
    else if (_laughWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("laugh_pulse");
    }
    // 5. sad 
    else if (_sadWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("sad_pulse");
    }
    // 6. WINNING 
    else if (_winWords.any((word) => lowerInput.contains(word))) {
      _visualFxController.add("win_pulse");
    }
    // 4. EXISTING PHYSICAL ACTIONS (Specific to action codes)
    else if (lowerInput.contains("shake") || lowerInput.contains("glitch") || lowerInput.contains("creepy")) {
      _visualFxController.add("shake");
    }
    else if (lowerInput.contains("stare") || lowerInput.contains("silence") || lowerInput.contains("lean")) {
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
//   // 1. Existing Action Stream (For Text/UI)
//   final _controller = StreamController<ActionEvent>.broadcast();
//   Stream<ActionEvent> get actionStream => _controller.stream;
  
//   // 2. Visual Effect Stream (For Screen Shake/Glow)
//   final _visualFxController = StreamController<String>.broadcast();
//   Stream<String> get visualEffectStream => _visualFxController.stream;
  
//   final List<Timer> _activeTimers = [];
// // --- UPDATED PROCESS LOGIC WITH TYPING LATENCY ---
//   void processAiResponse(Map<String, dynamic> data) {
//     final String message = data['message'] ?? "...";
//     final Map<String, dynamic> params = data['parameters'] ?? {};

//     // 1. CALCULATE INTELLIGENT LATENCY
//     // Short msg (hi) = 1.5s delay. Long msg (paragraph) = 4s delay.
//     // This makes the AI feel like it is "thinking" and "typing".
//     int typingDelay = _calculateTypingDelay(message);

//     // 2. SCHEDULE THE TEXT ARRIVAL
//     Timer(Duration(seconds: typingDelay), () {
//       if (_controller.isClosed) return;

//       // Emit Text & Stats
//       _controller.add(ActionEvent(
//         text: message,
//         vibe: (params['vibe'] as num?)?.toDouble(),
//         trust: (params['trust'] as num?)?.toDouble(),
//         tension: (params['tension'] as num?)?.toDouble(),
//       ));

//       // 3. SCHEDULE ACTIONS (Relative to the text arrival)
//       _scheduleActions(data['actions'] ?? []);
//     });
//   }

//   // Helper to determine how long the AI "thinks"
//   int _calculateTypingDelay(String text) {
//     if (text.length < 10) return 1;  // Instant for "No." or "Hi"
//     if (text.length < 50) return 2;  // Fast for short sentences
//     if (text.length < 150) return 3; // Medium
//     return 5;                        // Long pause for paragraphs
//   }

//   // Helper to schedule the actions list (Moved out for clarity)
//   void _scheduleActions(List<dynamic> actionList) {
//     int cumulativeDelay = 0; // Starts immediately after text arrives

//     for (var actionMap in actionList) {
//       final String code = actionMap['code'] ?? "";
      
//       // Keep your existing minimum delay logic
//       int rawDelay = actionMap['delay'] ?? 0;
//       if (rawDelay < 5 && cumulativeDelay > 0) rawDelay = 10;
//       cumulativeDelay += rawDelay;

//       final timer = Timer(Duration(seconds: cumulativeDelay), () {
//         if (!_controller.isClosed) {
//           _controller.add(ActionEvent(action: code));
//           _detectAndTriggerVisuals(code);
//         }
//       });
//       _activeTimers.add(timer);
//     }
//   }

//   // --- UPDATED VISUALS WITH COLORS & WINNING ---
//   void _detectAndTriggerVisuals(String actionCode) {
//     final lowerCode = actionCode.toLowerCase();

//     final romanceWords = ['kiss', 'blush', 'heart', 'love', 'bite', 'hug', 'wink', 'softly' , 'i am ready' ,'awww' , 'sweet' ,'smiling' , ];
//   final angerWords = ['angry', 'shout', 'hate', 'slap', 'slam', 'yell', 'aggressive', 'stomp' , 'fuck' , 'dick'  , 'penis' , 'pussy' , 'slutt'  ];
//   final winWords = ['agree', 'point', 'win', 'correct', 'nod', 'smart', 'victory'];

//     // 1. LOVE (Pink Hearts)
//     if (lowerCode.contains("kiss") || 
//         lowerCode.contains("blush") || 
//         lowerCode.contains("heart") ||
//         lowerCode.contains("love") ||
//         lowerCode.contains("bite_lip")) {
//       _visualFxController.add("romance_hearts"); // NEW KEY
//     } 
//     // 2. ANGER (Red Flash + Text)
//     else if (lowerCode.contains("angry") || 
//              lowerCode.contains("shout") || 
//              lowerCode.contains("hate") ||
//              lowerCode.contains("slap")) {
//       _visualFxController.add("anger_pulse"); // NEW KEY
//     } 
//     // 3. WINNING (Green Glow - for Debate)
//     else if (lowerCode.contains("agree") || 
//              lowerCode.contains("good_point") || 
//              lowerCode.contains("you_win") || 
//              lowerCode.contains("nod")) {
//       _visualFxController.add("win_glow"); // NEW KEY
//     }
//     // 4. EXISTING EFFECTS
//     else if (lowerCode.contains("shake") || lowerCode.contains("glitch")) {
//       _visualFxController.add("shake");
//     }
//     else if (lowerCode.contains("stare") || lowerCode.contains("silence")) {
//       _visualFxController.add("focus_vignette");
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
//     _visualFxController.close(); 
//   }
// }

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