import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction.dart';

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<Prediction> predictNextMonth(List<double> historyKWh) async {
    final uri = Uri.parse('$baseUrl/predict');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'history_kwh': historyKWh}),
    );
    final data = jsonDecode(res.body);
    return Prediction(
      estimatedAmount: (data['estimated_amount'] as num).toDouble(),
      percentChange: (data['percent_change'] as num).toDouble(),
      nextMonthKWh: (data['next_month_kwh'] as num).toDouble(),
    );
  }

  Future<Map<String, double>> getNILMInsights(Map<String, double> applianceMap) async {
    final uri = Uri.parse('$baseUrl/nilm');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'appliances': applianceMap}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}
