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
