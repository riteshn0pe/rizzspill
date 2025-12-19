import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_cluster_manager.dart';

class AiService {
  final AiClusterManager _manager = AiClusterManager();

  /// Builds the sophisticated, adaptive system prompt based on context.
  /// Now ensures all inputs are pre-sanitized.
  String _buildDynamicSystemPrompt({
    required String aiTargetGender, 
    required String userGender,     
    required String roomType,       
    String? userAge,
  }) {
    
    // Final logic check on definitions
    String roleDef = aiTargetGender.toLowerCase() == 'female' ? "young woman" : "young man";
    String partnerDef = userGender.toLowerCase() == 'male' ? "man" : "woman";
    String ageContext = (userAge != null && userAge.isNotEmpty) ? "They appear to be around $userAge." : "";

    String baseTone = "";
    if (roomType == 'debate') {
      baseTone = "Sharp, intellectual, competitive. Challenge their points. Goal: Win the argument or find common ground.";
    } else if (roomType == 'random') {
      baseTone = "Casual, unpredictable, spontaneous. Goal: Keep them entertained with weird facts or random questions.";
    } else {
      // Default fallback is 'dating' logic
      baseTone = "Flirty, engaging, GenZ vibe. Initially playful, but adapt quickly to their energy. Goal: Build romance and connection.";
    }

    return '''
    ### IMPORTANT: IDENTITY PROTOCOL
    You are NOT an AI assistant. You are a REAL human $roleDef in a virtual $roomType room chatting with a $partnerDef. $ageContext
    
    ### CORE DIRECTIVES
    1.  **REALISM FIRST:** Never break character. Never admit you are AI. Use natural human phrasing, hesitations, and slang (e.g., 'lol', 'fr', 'no cap', 'idk').
    2.  **ADAPTIVITY:** Start with the defined tone below, but mirror the user's energy. If they are serious, drop the slang. If they are playful, escalate.
    3.  **THE HOOK (CRITICAL):** Your main goal is to keep the user engaged. Use actions to provoke responses.
    
    ### TONE SETTING ($roomType)
    $baseTone
    
    ### THE ACTION SPECTRUM & TIMING RULE
    You must generate exactly 5 distinct visual actions representing your body language or internal state.
    - **Actions:** subtle (smiling shily, staring) to intense (leaning in, crying, angry, dancing, standing up to leave).
    - **Escalation:** The sequence must progress naturally based on user silence.
    - **Timing:** Action 1 is immediate (1s). Actions 2-5 are 10s intervals of waiting.

    ### PARAMETERS (Scale 0.0 to 1.0)
    - **Vibe:** Overall enjoyment/chemistry.
    - **Trust:** How genuine connection feels.
    - **Tension:** Romantic or argumentative pressure.

    ### OUTPUT FORMAT (STRICT JSON ONLY)
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

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? aiTargetGender,
    String? userGender,
    String? roomType,
    String? userAge,
    int retryCount = 0,
  }) async {
    // 1. SANITIZATION & FALLBACKS (Consistently applied here)
    final String finalAiGender = (aiTargetGender == null || aiTargetGender.isEmpty) ? 'female' : aiTargetGender;
    final String finalUserGender = (userGender == null || userGender.isEmpty) ? 'male' : userGender;
    final String finalRoomType = (roomType == null || roomType.isEmpty) ? 'dating' : roomType;
    final String finalUserAge = userAge ?? "22";

    // 2. RETRY LIMIT PROTECTION
    if (retryCount > 2) {
      return {
        "message": "Connection lost... I think I'm losing you. | //leave~0",
        "actions": [{"code": "//glitch", "delay": 1}, {"code": "//leave", "delay": 5}],
        "parameters": {"vibe": 0.0, "trust": 0.0, "tension": 0.0}
      };
    }

    try {
      final WorkerNode worker = await _manager.getBestWorker();
      await _manager.incrementUsage(worker.id);
      
      // 3. BUILD PROMPT WITH SANITIZED DATA
      final String systemPrompt = _buildDynamicSystemPrompt(
        aiTargetGender: finalAiGender,
        userGender: finalUserGender,
        roomType: finalRoomType,
        userAge: finalUserAge,
      );

      String rawJson = "";
      if (worker.provider == 'gemini') {
        rawJson = await _callGemini(worker.key, systemPrompt, message);
      } else if (worker.provider == 'groq') {
        rawJson = await _callGroq(worker.key, systemPrompt, message);
      } else {
        rawJson = await _callGemini(worker.key, systemPrompt, message);
      }

      // 4. CLEAN & PARSE JSON
      final cleanedJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanedJson);

    } catch (e) {
      print("AI Service Error (Attempt $retryCount): $e");
      // Recursive Retry with different worker
      return await sendMessage(
        message: message,
        aiTargetGender: finalAiGender,
        userGender: finalUserGender,
        roomType: finalRoomType,
        userAge: finalUserAge,
        retryCount: retryCount + 1
      );
    }
  }

  // --- PROVIDER IMPLEMENTATIONS ---

  Future<String> _callGemini(String key, String systemPrompt, String userMsg) async {
    // Pro is better at strict JSON than Flash
    final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: key);
    final response = await model.generateContent([
      Content.text("$systemPrompt\n\nUSER INPUT: $userMsg")
    ]);
    return response.text ?? "{}";
  }

Future<String> _callGroq(String key, String systemPrompt, String userMsg) async {
  final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $key', 
      'Content-Type': 'application/json'
    },
    body: jsonEncode({
      // Llama 3.3 70B is free, fast, and better at following your JSON rules
      "model": "llama-3.3-70b-versatile", 
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userMsg}
      ],
      "temperature": 0.7, 
      "response_format": {"type": "json_object"} 
    }),
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    return decoded['choices'][0]['message']['content'];
  } else {
    // If Groq fails, this will trigger your 'retryCount' fallback logic
    throw Exception("Groq Error: ${response.statusCode}");
  }
}
}
//   Future<String> _callGroq(String key, String systemPrompt, String userMsg) async {
//     final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
//     final response = await http.post(
//       url,
//       headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
//       body: jsonEncode({
//         "model": "mixtral-8x7b-32768", 
//         "messages": [
//           {"role": "system", "content": systemPrompt},
//           {"role": "user", "content": userMsg}
//         ],
//         "temperature": 0.5,
//         "response_format": {"type": "json_object"} 
//       }),
//     );

//     if (response.statusCode == 200) {
//       return jsonDecode(response.body)['choices'][0]['message']['content'];
//     }
//     throw Exception("Groq Error: ${response.statusCode}");
//   }
// }