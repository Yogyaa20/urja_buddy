import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class UrjaGauge extends StatelessWidget {
  final double kWh;
  final double percent;
  const UrjaGauge({super.key, required this.kWh, required this.percent});
  @override
  Widget build(BuildContext context) {
    final used = percent;
    final remaining = 1 - percent;
    // Color Logic: Green by default, Orange > 50%, Red > 100 kWh
    final bool isCritical = kWh > 100;
    final bool isWarning = kWh > 50 && !isCritical;
    
    final List<Color> gradientColors = isCritical 
        ? [const Color(0xFFFF5252), const Color(0xFFE53935)] // Red Gradient
        : isWarning 
            ? [const Color(0xFFFF9800), const Color(0xFFFB8C00)] // Orange Gradient
            : [const Color(0xFF00C853), const Color(0xFF00E676)]; // Green Gradient (Default)

    final Color textColor = isCritical ? const Color(0xFFD32F2F) : isWarning ? const Color(0xFFF57C00) : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradientColors[0].withValues(alpha: 0.1), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 70,
                startDegreeOffset: -90,
                sections: [
                  PieChartSectionData(
                    value: used * 100,
                    title: '',
                    gradient: LinearGradient(colors: gradientColors),
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: remaining * 100,
                    title: '',
                    color: const Color(0xFFF1F2F6),
                    radius: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${kWh.toStringAsFixed(1)} kWh', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: textColor, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Live usage', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
