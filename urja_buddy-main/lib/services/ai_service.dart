import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqModel = 'llama-3.3-70b-versatile';
  static const String _groqApiKey = '';

  Future<String> _callGroqChat({
    required String systemPrompt,
    required String userMessage,
  }) async {
    if (_groqApiKey.isEmpty) {
      return _getFallbackResponse(userMessage);
    }

    final response = await http.post(
      Uri.parse(_groqUrl),
      headers: {
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
      throw Exception(
          'Groq API error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? [];
    String? content;

    if (choices.isNotEmpty) {
      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      content = message?['content'] as String?;
    }

    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq API returned empty content');
    }

    return content;
  }

  Future<String> getAIResponse(String userQuery) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final appliancesBox = await Hive.openBox('appliances');

      final double currentKwh =
          settingsBox.get('currentMonthKwh', defaultValue: 325.0);
      final double reductionGoal =
          settingsBox.get('reductionTargetPercent', defaultValue: 10.0);

      final appliances = appliancesBox.values.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return "${map['name']} (${map['wattage']}W, ${map['hoursPerDay']}h/day)";
      }).join(', ');

      final contextData = '''
Current Monthly Usage: ${currentKwh.toInt()} kWh
Target Reduction Goal: ${reductionGoal.toInt()}%
Appliances: ${appliances.isEmpty ? 'None listed' : appliances}
''';

      final systemPrompt = '''
You are Urja Buddy, a professional energy analyst for Indian households.
Use the provided context data and user query to give precise, money-saving advice.
If asked about costs, use the rate of ₹8.5/unit.
Be concise, helpful, and encouraging.
Do not use markdown bolding excessively. Keep it clean.
''';

      final userMessage = '''
Context:
$contextData

User Query: "$userQuery"
''';

      return await _callGroqChat(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );
    } catch (e) {
      return _getFallbackResponse(userQuery);
    }
  }

  Future<Map<String, String>> generateEnergyAudit({
    double? currentKwh,
    double? prevKwh,
  }) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final appliancesBox = await Hive.openBox('appliances');

      final double usage =
          currentKwh ?? settingsBox.get('currentMonthKwh', defaultValue: 325.0);

      final appliances = appliancesBox.values.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return "${map['name']} (${map['wattage']}W, ${map['hoursPerDay']}h/day)";
      }).join(', ');

      final prompt = '''
User is consuming ${usage.toInt()} kWh this month.
Appliances: ${appliances.isEmpty ? 'None listed' : appliances}

Output ONLY a raw JSON string with these 3 keys (no markdown, no code blocks):
1. "insight": A 1-sentence analysis of why usage is high or low.
2. "action": A personalized energy saving tip.
3. "saving": Estimated monthly saving in rupees (e.g. "₹120").
''';

      final raw = await _callGroqChat(
        systemPrompt:
            'You are Urja Buddy, a professional energy analyst. Return ONLY raw JSON text (no markdown fences).',
        userMessage: prompt,
      );

      final text =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();

      final insightMatch = RegExp(r'"insight":\s*"(.*?)"').firstMatch(text);
      final actionMatch = RegExp(r'"action":\s*"(.*?)"').firstMatch(text);
      final savingMatch = RegExp(r'"saving":\s*"(.*?)"').firstMatch(text);

      return {
        'insight': insightMatch?.group(1) ?? 'Your usage is stable.',
        'action': actionMatch?.group(1) ?? 'Keep monitoring your appliances.',
        'saving': savingMatch?.group(1) ?? '₹0',
      };
    } catch (e) {
      return {
        'insight': 'Could not analyze data.',
        'action': 'Try again later.',
        'saving': '₹0',
      };
    }
  }

  Future<String> getTipOfTheDay() async {
    return getAIResponse(
      'Give me a specific Tip of the Day based on my highest consuming appliance. '
      'If no appliances, give a general saving tip. Keep it under 20 words.',
    );
  }

  String _getFallbackResponse(String query) {
    if (query.toLowerCase().contains('tip')) {
      return 'Switch to LED bulbs to save up to 75% on lighting costs.';
    }
    return 'Urja Buddy is currently offline. Try unplugging unused devices to save energy!';
  }
}
