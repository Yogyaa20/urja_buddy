import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'Llama-3.3-70b-versatile';
  static const String _groqApiKey =
      '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';

  Future<String> _callGroqChat({
    required String systemPrompt,
    required String userMessage,
  }) async {
    if (_groqApiKey.isEmpty) {
      throw Exception('MISSING_GROQ_API_KEY');
    }

    final response = await http.post(
      Uri.parse(_groqUrl),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': _groqModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices = decoded['choices'] as List<dynamic>? ?? <dynamic>[];
    String? content;
    if (choices.isNotEmpty) {
      final Map<String, dynamic> firstChoice = choices.first as Map<String, dynamic>;
      final Map<String, dynamic>? message =
          firstChoice['message'] as Map<String, dynamic>?;
      content = message?['content'] as String?;
    }

    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq API returned empty content');
    }

    return content;
  }

  Future<String> getAIResponse(String userQuery) async {
    try {
      // 1. Fetch Context Data from Hive
      final settingsBox = await Hive.openBox('settings');
      final appliancesBox = await Hive.openBox('appliances');

      final double currentKwh = settingsBox.get('currentMonthKwh', defaultValue: 325.0);
      final double reductionGoal = settingsBox.get('reductionTargetPercent', defaultValue: 10.0);
      
      final appliances = appliancesBox.values.map((e) {
        final map = Map<String, dynamic>.from(e);
        return "${map['name']} (${map['wattage']}W, ${map['hoursPerDay']}h/day)";
      }).join(', ');

      final String contextData = '''
Current Monthly Usage: ${currentKwh.toInt()} kWh
Target Reduction Goal: ${reductionGoal.toInt()}%
Appliances: ${appliances.isEmpty ? 'None listed' : appliances}
''';

      final systemPrompt = '''
You are Urja Buddy, a professional energy analyst.
Use the provided context data and user query to give precise, money-saving advice.
If asked about costs, use the rate of ₹8.5/unit (or calculate based on the user's usage if implied).
Be concise, helpful, and encouraging.
Do not use markdown bolding excessively. Keep it clean.
''';

      final userMessage = '''
Context:
$contextData

User Query: "$userQuery"
''';

      final reply =
          await _callGroqChat(systemPrompt: systemPrompt, userMessage: userMessage);
      return reply;
    } catch (e) {
      if (e.toString().contains('MISSING_GROQ_API_KEY')) {
        return "Urja Buddy configuration error: Groq API key is missing.";
      }
      return _getFallbackResponse(userQuery);
    }
  }

  Future<Map<String, String>> generateEnergyAudit({double? currentKwh, double? prevKwh}) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final appliancesBox = await Hive.openBox('appliances');

      final double usage = currentKwh ?? settingsBox.get('currentMonthKwh', defaultValue: 325.0);
      // final double previous = prevKwh ?? 350.0; // Mock previous month for comparison
      
      final appliances = appliancesBox.values.map((e) {
        final map = Map<String, dynamic>.from(e);
        return "${map['name']} (${map['wattage']}W, ${map['hoursPerDay']}h/day)";
      }).join(', ');

      final prompt = '''
      User Sameer is consuming ${usage.toInt()} kWh.
      Appliances: $appliances
      
      Give a 1-sentence energy saving tip based on this.
      
      Output ONLY a JSON string with these 3 keys:
      1. "insight": A 1-sentence analysis of why usage is high/low.
      2. "action": The personalized tip requested above.
      3. "saving": Estimated monthly saving in \$ (e.g. "\$15.50").
      Do not include markdown code blocks. Just the raw JSON string.
      ''';

      final systemPrompt = '''
You are Urja Buddy, a professional energy analyst.
Return ONLY raw JSON text (no markdown fences).
''';

      final raw =
          await _callGroqChat(systemPrompt: systemPrompt, userMessage: prompt);
      final text = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Simple parsing (since we don't want to add dart:convert if not needed, but it's standard)
      // We'll use regex to extract for robustness without importing dart:convert if user didn't request it, 
      // but standard approach is better. Let's assume basic string parsing for safety or just regex.
      
      final insightMatch = RegExp(r'"insight":\s*"(.*?)"').firstMatch(text);
      final actionMatch = RegExp(r'"action":\s*"(.*?)"').firstMatch(text);
      final savingMatch = RegExp(r'"saving":\s*"(.*?)"').firstMatch(text);

      return {
        "insight": insightMatch?.group(1) ?? "Your usage is stable.",
        "action": actionMatch?.group(1) ?? "Keep monitoring your appliances.",
        "saving": savingMatch?.group(1) ?? "\$0.00"
      };

    } catch (e) {
      return {
        "insight": "Could not analyze data.",
        "action": "Try again later.",
        "saving": "₹0.00"
      };
    }
  }

  Future<String> getTipOfTheDay() async {
    return getAIResponse("Give me a specific 'Tip of the Day' based on my highest consuming appliance. If no appliances, give a general saving tip. Keep it under 20 words.");
  }

  String _getFallbackResponse(String query) {
    if (query.contains('Tip')) {
      return "Switch to LED bulbs to save up to 75% on lighting costs.";
    }
    return "Urja Buddy is currently offline. Please check your internet connection or try again later. In the meantime, try unplugging unused devices!";
  }
}
