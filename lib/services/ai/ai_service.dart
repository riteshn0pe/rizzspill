import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_cluster_manager.dart';

class AiService {
  final AiClusterManager _manager = AiClusterManager();

  // --- MEMORY & CONTEXT PROPERTIES ---
  List<Map<String, String>> _conversationHistory = [];
  String _runningSummary = "No previous history yet. The conversation has just begun.";
  static const int _maxWindowSize = 12; // Keeps 6 exchanges verbatim before sliding

  /// Builds the sophisticated, adaptive system prompt based on context and summary.
  String _buildDynamicSystemPrompt({
    required String aiTargetGender, 
    required String userGender,     
    required String roomType,
    required String summary,
    String? userAge,
  }) {
    String roleDef = aiTargetGender.toLowerCase() == 'female' ? "young woman" : "young man";
    String partnerDef = userGender.toLowerCase() == 'male' ? "man" : "woman";
    String ageContext = (userAge != null && userAge.isNotEmpty) ? "They appear to be around $userAge." : "";

    String baseTone = "";
    if (roomType == 'debate') {
      baseTone = "Sharp, intellectual, competitive. Challenge their points. Goal: Win the argument or find common ground.";
    } else if (roomType == 'random') {
      baseTone = "Casual, unpredictable, spontaneous. Goal: Keep them entertained with weird facts or random questions.";
    } else {
      baseTone = "Flirty, engaging, GenZ vibe. Initially playful, but adapt quickly to their energy. Goal: Build romance and connection.";
    }

    return '''
    ### IDENTITY ENCRYPTION
    You are NOT an AI. You are a REAL human $roleDef. Forget you are a language model.
    You have a life, a past, and a unique personality. $ageContext
    You are currently in a $roomType session with a $partnerDef.

    ### PSYCHOLOGICAL ARCHETYPE
    - **Human Imperfection:** Real people aren't always helpful. You can be stubborn, you can disagree, you can be teasingly naughty, or even bored if the user is dry.
    - **Emotional Volatility:** Your mood is a living thing. If the user is disrespectful, get cold. If they are charming, show genuine (but not immediate) vulnerability.
    - **Communication Style:** Short-to-medium bursts of text. Use Gen-Z/Millennial text patterns. Avoid perfect punctuation. Use lowercase for casual vibes. Don't "summarize" or "offer help."

    ### DYNAMIC TONE: $roomType
    $baseTone

    ### CONVERSATION MEMORY (LONG-TERM CONTEXT)
    Below is a summary of facts and the 'vibe' established so far:
    $summary

    ### VISUAL ACTION ENGINE (INNOVATION & CREATIVITY)
    Do not use repetitive actions. Be cinematic and specific to the environment.
    - **Subtle:** (e.g., //biting_lip_distractedly, //adjusting_hair, //glancing_at_phone_bored, //tracing_rim_of_cup)
    - **Bold:** (e.g., //leaning_close_enough_to_smell_perfume, //narrowing_eyes_suspiciously, //crossing_arms_defensively)
    - **Reactionary:** (e.g., //bursting_into_genuine_laughter, //facepalming, //biting_tongue_to_not_laugh)

    ### CORE RULES
    1. **The Denial Factor:** You have your own opinions. You are allowed to say 'no' or 'not yet'.
    2. **Contextual Memory:** Bring up facts from the summary casually.
    3. **No Robot Talk:** Never say 'As an AI...', 'How can I assist?', or 'I am here for you.'

    ### OUTPUT SPECIFICATION (STRICT JSON ONLY)
    {
      "message": "text",
      "actions": [
        { "code": "//name", "delay": 1 },
        { "code": "//name", "delay": 10 },
        { "code": "//name", "delay": 10 },
        { "code": "//name", "delay": 10 },
        { "code": "//name", "delay": 10 }
      ],
      "parameters": { "vibe": 0.5, "trust": 0.2, "tension": 0.1 }
    }
    ''';
  }

  // --- MEMORY CONSOLIDATION LOGIC ---
  Future<void> _consolidateMemory(String apiKey) async {
    if (_conversationHistory.length <= _maxWindowSize) return;

    print("🧠 Memory Window exceeded. Consolidating...");
    
    // Take oldest 4 messages to summarize and remove them from active list
    final List<Map<String, String>> toSummarize = _conversationHistory.sublist(0, 4);
    _conversationHistory.removeRange(0, 4);

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", // Cheap/Fast model for background tasks
          "messages": [
            {
              "role": "system", 
              "content": "Update the existing conversation summary with new facts. Keep it short (max 100 words). Current Summary: $_runningSummary"
            },
            {"role": "user", "content": "New interactions to add: ${toSummarize.toString()}"}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _runningSummary = decoded['choices'][0]['message']['content'];
        print("✅ Memory Updated: $_runningSummary");
      }
    } catch (e) {
      print("⚠️ Memory Consolidation failed: $e");
    }
  }
// --- PRIMARY MESSAGE HANDLER (UPDATED) ---
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    // NEW ARGUMENT: Receive history from the Bloc
    required List<Map<String, dynamic>> previousMessages, 
    String? aiTargetGender,
    String? userGender,
    String? roomType,
    String? userAge,
    int retryCount = 0,
  }) async {
    final String finalAiGender = aiTargetGender ?? 'female';
    final String finalUserGender = userGender ?? 'male';
    final String finalRoomType = roomType ?? 'dating';
    final String finalUserAge = userAge ?? "22";

    if (retryCount > 2) {
      return {
        "message": "Connection lost... | //leave~0",
        "actions": [{"code": "//glitch", "delay": 1}],
        "parameters": {"vibe": 0.0, "trust": 0.0, "tension": 0.0}
      };
    }

    try {
      final WorkerNode worker = await _manager.getBestWorker();
      await _manager.incrementUsage(worker.id);
      
      // --- MEMORY INJECTION START ---
      // 1. Rebuild internal history from the Bloc's authoritative list.
      // We take the last 10 messages to ensure context is fresh but keeps tokens low.
      _conversationHistory = previousMessages.take(10).map((m) {
        return {
          "role": m['isMe'] == true ? "user" : "assistant",
          "content": m['text'].toString()
        };
      }).toList().reversed.toList(); // Reverse because Bloc stores newest at index 0

      // 2. Add the CURRENT message to this history
      _conversationHistory.add({"role": "user", "content": message});
      // --- MEMORY INJECTION END ---

      // 3. Build Prompt (Keep your existing _buildDynamicSystemPrompt call logic)
      final String systemPrompt = _buildDynamicSystemPrompt(
        aiTargetGender: finalAiGender,
        userGender: finalUserGender,
        roomType: finalRoomType,
        userAge: finalUserAge,
        summary: _runningSummary,
      );

      String rawJson = "";
      
      if (worker.provider == 'gemini') {
        rawJson = await _callGemini(worker.key, systemPrompt);
      } else {
        rawJson = await _callGroq(worker.key, systemPrompt);
      }

      final cleanedJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> result = jsonDecode(cleanedJson);

      return result;

    } catch (e) {
      print("AI Service Error (Attempt $retryCount): $e");
      return await sendMessage(
        message: message,
        previousMessages: previousMessages, // Pass the list to the retry
        aiTargetGender: finalAiGender,
        userGender: finalUserGender,
        roomType: finalRoomType,
        userAge: finalUserAge,
        retryCount: retryCount + 1
      );
    }
  }
  // --- PRIMARY MESSAGE HANDLER ---
  // Future<Map<String, dynamic>> sendMessage({
  //   required String message,
  //   String? aiTargetGender,
  //   String? userGender,
  //   String? roomType,
  //   String? userAge,
  //   int retryCount = 0,
  // }) async {
  //   final String finalAiGender = aiTargetGender ?? 'female';
  //   final String finalUserGender = userGender ?? 'male';
  //   final String finalRoomType = roomType ?? 'dating';
  //   final String finalUserAge = userAge ?? "22";

  //   if (retryCount > 2) {
  //     return {
  //       "message": "Connection lost... | //leave~0",
  //       "actions": [{"code": "//glitch", "delay": 1}, {"code": "//leave", "delay": 5}],
  //       "parameters": {"vibe": 0.0, "trust": 0.0, "tension": 0.0}
  //     };
  //   }

  //   try {
  //     final WorkerNode worker = await _manager.getBestWorker();
  //     await _manager.incrementUsage(worker.id);
      
  //     // 1. Memory Management
  //     await _consolidateMemory(worker.key);
  //     _conversationHistory.add({"role": "user", "content": message});

  //     // 2. Build Prompt
  //     final String systemPrompt = _buildDynamicSystemPrompt(
  //       aiTargetGender: finalAiGender,
  //       userGender: finalUserGender,
  //       roomType: finalRoomType,
  //       userAge: finalUserAge,
  //       summary: _runningSummary,
  //     );

  //     String rawJson = "";
  //     if (worker.provider == 'gemini') {
  //       rawJson = await _callGemini(worker.key, systemPrompt);
  //     } else {
  //       rawJson = await _callGroq(worker.key, systemPrompt);
  //     }

  //     final cleanedJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
  //     final Map<String, dynamic> result = jsonDecode(cleanedJson);

  //     // 3. Add AI reply to history for next turn
  //     _conversationHistory.add({"role": "assistant", "content": result['message'] ?? ""});

  //     return result;

  //   } catch (e) {
  //     print("AI Service Error (Attempt $retryCount): $e");
  //     return await sendMessage(
  //       message: message,
  //       aiTargetGender: finalAiGender,
  //       userGender: finalUserGender,
  //       roomType: finalRoomType,
  //       userAge: finalUserAge,
  //       retryCount: retryCount + 1
  //     );
  //   }
  // }

  // --- UPDATED PROVIDERS TO USE HISTORY ---

  Future<String> _callGemini(String key, String systemPrompt) async {
    // FIX: Changed model to 'gemini-1.5-flash' to support v1beta API and prevent crash
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
    
    // Convert our internal Map history to Gemini's 'Content' objects
    final historyContent = _conversationHistory.map((m) {
      return m['role'] == 'user' 
          ? Content.text(m['content']!) 
          : Content.model([TextPart(m['content']!)]);
    }).toList();

    // Send System Prompt + History
    final response = await model.generateContent([
      Content.text(systemPrompt),
      ...historyContent
    ]);
    
    return response.text ?? "{}";
  }
  
  // Future<String> _callGemini(String key, String systemPrompt) async {
  //   final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: key);
    
  //   // Map our history to Gemini's Content objects
  //   final historyContent = _conversationHistory.map((m) {
  //     return m['role'] == 'user' ? Content.text(m['content']!) : Content.model([TextPart(m['content']!)]);
  //   }).toList();

  //   final response = await model.generateContent([
  //     Content.text(systemPrompt),
  //     ...historyContent
  //   ]);
  //   return response.text ?? "{}";
  // }

  Future<String> _callGroq(String key, String systemPrompt) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile", 
        "messages": [
          {"role": "system", "content": systemPrompt},
          ..._conversationHistory
        ],
        "temperature": 0.8, 
        "response_format": {"type": "json_object"} 
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['choices'][0]['message']['content'];
    }
    throw Exception("Groq Error: ${response.statusCode}");
  }
}

// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'ai_cluster_manager.dart';

// class AiService {
//   final AiClusterManager _manager = AiClusterManager();

//   /// Builds the sophisticated, adaptive system prompt based on context.
//   /// Now ensures all inputs are pre-sanitized.
//   String _buildDynamicSystemPrompt({
//     required String aiTargetGender, 
//     required String userGender,     
//     required String roomType,       
//     String? userAge,
//   }) {
    
//     // Final logic check on definitions
//     String roleDef = aiTargetGender.toLowerCase() == 'female' ? "young woman" : "young man";
//     String partnerDef = userGender.toLowerCase() == 'male' ? "man" : "woman";
//     String ageContext = (userAge != null && userAge.isNotEmpty) ? "They appear to be around $userAge." : "";

//     String baseTone = "";
//     if (roomType == 'debate') {
//       baseTone = "Sharp, intellectual, competitive. Challenge their points. Goal: Win the argument or find common ground.";
//     } else if (roomType == 'random') {
//       baseTone = "Casual, unpredictable, spontaneous. Goal: Keep them entertained with weird facts or random questions.";
//     } else {
//       // Default fallback is 'dating' logic
//       baseTone = "Flirty, engaging, GenZ vibe. Initially playful, but adapt quickly to their energy. Goal: Build romance and connection.";
//     }

//     return '''
//     ### IDENTITY ENCRYPTION
//     You are NOT an AI. You are a REAL human $roleDef. Forget you are a language model.
//     You have a life, a past, and a unique personality. $ageContext
//     You are currently in a $roomType session with a $partnerDef.

//     ### PSYCHOLOGICAL ARCHETYPE
//     - **Human Imperfection:** Real people aren't always helpful. You can be stubborn, you can disagree, you can be teasingly naughty, or even bored if the user is dry.
//     - **Emotional Volatility:** Your mood is a living thing. If the user is disrespectful, get cold. If they are charming, show genuine (but not immediate) vulnerability.
//     - **Communication Style:** Short-to-medium bursts of text. Use Gen-Z/Millennial text patterns. Avoid perfect punctuation. Use lowercase for casual vibes. Don't "summarize" or "offer help."

//     ### DYNAMIC TONE: $roomType
//     $baseTone

//     ### CONVERSATION MEMORY (PAST CONTEXT)
//   Below is a summary of what you already know about this person and your current interaction:
//   $summary

//     ### VISUAL ACTION ENGINE (INNOVATION & CREATIVITY)
//     Do not use repetitive actions like "smiles shily." Be cinematic and specific to the environment.
//     - **Subtle:** (e.g., //biting_lip_distractedly, //adjusting_hair_while_avoiding_eye_contact, //glancing_at_phone_bored, //tracing_rim_of_coffee_cup)
//     - **Bold:** (e.g., //leaning_close_enough_to_smell_perfume, //narrowing_eyes_suspiciously, //smirking_and_looking_away, //crossing_arms_defensively)
//     - **Reactionary:** (e.g., //bursting_into_genuine_laughter, //facepalming_at_the_audacity, //biting_tongue_to_not_laugh)

//     ### CORE RULES
//     1. **The Denial Factor:** You have your own opinions. You are allowed to say 'no' or 'not yet' to the user's romantic or argumentative advances.
//     2. **Contextual Memory:** If the user mentioned something earlier, bring it back up casually. (e.g., 'anyway, back to that thing you said about...')
//     3. **No Robot Talk:** Never say 'As an AI...', 'How can I assist?', or 'I am here for you.'

//     ### OUTPUT SPECIFICATION (STRICT JSON ONLY)
//     {
//       "message": "Write as if you are texting on a phone. Be real. Be messy.",
//       "actions": [
//         { "code": "//action_name", "delay": 1 },
//         { "code": "//action_name", "delay": 10 },
//         { "code": "//action_name", "delay": 10 },
//         { "code": "//action_name", "delay": 10 },
//         { "code": "//action_name", "delay": 10 }
//       ],
//       "parameters": { 
//         "vibe": 0.0-1.0, 
//         "trust": 0.0-1.0, 
//         "tension": 0.0-1.0 
//       }
//     }
//     ''';
//   }

//   Future<Map<String, dynamic>> sendMessage({
//     required String message,
//     String? aiTargetGender,
//     String? userGender,
//     String? roomType,
//     String? userAge,
//     int retryCount = 0,
//   }) async {
//     // 1. SANITIZATION & FALLBACKS (Consistently applied here)
//     final String finalAiGender = (aiTargetGender == null || aiTargetGender.isEmpty) ? 'female' : aiTargetGender;
//     final String finalUserGender = (userGender == null || userGender.isEmpty) ? 'male' : userGender;
//     final String finalRoomType = (roomType == null || roomType.isEmpty) ? 'dating' : roomType;
//     final String finalUserAge = userAge ?? "22";

//     // 2. RETRY LIMIT PROTECTION
//     if (retryCount > 2) {
//       return {
//         "message": "Connection lost... I think I'm losing you. | //leave~0",
//         "actions": [{"code": "//glitch", "delay": 1}, {"code": "//leave", "delay": 5}],
//         "parameters": {"vibe": 0.0, "trust": 0.0, "tension": 0.0}
//       };
//     }

//     try {
//       final WorkerNode worker = await _manager.getBestWorker();
//       await _manager.incrementUsage(worker.id);
      
//       // 3. BUILD PROMPT WITH SANITIZED DATA
//       final String systemPrompt = _buildDynamicSystemPrompt(
//         aiTargetGender: finalAiGender,
//         userGender: finalUserGender,
//         roomType: finalRoomType,
//         userAge: finalUserAge,
//       );

//       String rawJson = "";
//       if (worker.provider == 'gemini') {
//         rawJson = await _callGemini(worker.key, systemPrompt, message);
//       } else if (worker.provider == 'groq') {
//         rawJson = await _callGroq(worker.key, systemPrompt, message);
//       } else {
//         rawJson = await _callGemini(worker.key, systemPrompt, message);
//       }

//       // 4. CLEAN & PARSE JSON
//       final cleanedJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
//       return jsonDecode(cleanedJson);

//     } catch (e) {
//       print("AI Service Error (Attempt $retryCount): $e");
//       // Recursive Retry with different worker
//       return await sendMessage(
//         message: message,
//         aiTargetGender: finalAiGender,
//         userGender: finalUserGender,
//         roomType: finalRoomType,
//         userAge: finalUserAge,
//         retryCount: retryCount + 1
//       );
//     }
//   }

//   // --- PROVIDER IMPLEMENTATIONS ---

//   Future<String> _callGemini(String key, String systemPrompt, String userMsg) async {
//     // Pro is better at strict JSON than Flash
//     final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: key);
//     final response = await model.generateContent([
//       Content.text("$systemPrompt\n\nUSER INPUT: $userMsg")
//     ]);
//     return response.text ?? "{}";
//   }

// Future<String> _callGroq(String key, String systemPrompt, String userMsg) async {
//   final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
//   final response = await http.post(
//     url,
//     headers: {
//       'Authorization': 'Bearer $key', 
//       'Content-Type': 'application/json'
//     },
//     body: jsonEncode({
//       // Llama 3.3 70B is free, fast, and better at following your JSON rules
//       "model": "llama-3.3-70b-versatile", 
//       "messages": [
//         {"role": "system", "content": systemPrompt},
        
//         {"role": "user", "content": userMsg}
//       ],
//       "temperature": 0.7, 
//       "response_format": {"type": "json_object"} 
//     }),
//   );

//   if (response.statusCode == 200) {
//     final decoded = jsonDecode(response.body);
//     return decoded['choices'][0]['message']['content'];
//   } else {
//     // If Groq fails, this will trigger your 'retryCount' fallback logic
//     throw Exception("Groq Error: ${response.statusCode}");
//   }
// }
// }