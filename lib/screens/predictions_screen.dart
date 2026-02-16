import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/urja_theme.dart';

class PredictionsScreen extends StatelessWidget {
  const PredictionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final spots = List.generate(12, (i) => FlSpot(i.toDouble(), (180 + i * 3).toDouble()));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Predictions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SizedBox(
            height: 400,
            child: LineChart(
              LineChartData(
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(colors: [UrjaTheme.primaryGreen, UrjaTheme.accentCyan]),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [UrjaTheme.primaryGreen.withValues(alpha: 0.2), UrjaTheme.accentCyan.withValues(alpha: 0.2)])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
