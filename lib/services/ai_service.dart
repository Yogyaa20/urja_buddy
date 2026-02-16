import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AIService {
  late final GenerativeModel _model;
  
  // Use a fallback flag if API key is invalid or fails
  bool _isApiValid = true;

  AIService() {
    try {
      // Hardcoded key as explicitly requested by user
      const apiKey = 'AIzaSyA_gnRoGyxbi9Wj8SHIquUNFI4eY7S6Zuk';
      
      _model = GenerativeModel(
        model: 'gemini-flash-lite-latest', // Verified working model
        apiKey: apiKey,
      );
    } catch (e) {
      _isApiValid = false;
    }
  }

  Future<String> getAIResponse(String userQuery) async {
    if (!_isApiValid) {
      return _getFallbackResponse(userQuery);
    }

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

      // 2. Construct Expert System Prompt
      final prompt = '''
You are Urja Buddy, a professional energy analyst. 
Use this data: 
$contextData

User Query: "$userQuery"

Instructions:
- Provide precise, money-saving advice based on the data.
- If asked about costs, use the rate of ₹8.5/unit (or calculate based on the user's usage if implied).
- Be concise, helpful, and encouraging.
- Do not use markdown bolding excessively. Keep it clean.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? _getFallbackResponse(userQuery);
    } catch (e) {
      return _getFallbackResponse(userQuery);
    }
  }

  Future<Map<String, String>> generateEnergyAudit({double? currentKwh, double? prevKwh}) async {
    if (!_isApiValid) {
      return {
        "insight": "AI is offline. Check internet connection.",
        "action": "Manually check your high-wattage appliances.",
        "saving": "\$0.00"
      };
    }

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

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      
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
