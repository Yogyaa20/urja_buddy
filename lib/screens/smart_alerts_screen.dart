import 'package:flutter/material.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';

class SmartAlertsScreen extends StatefulWidget {
  const SmartAlertsScreen({super.key});

  @override
  State<SmartAlertsScreen> createState() => _SmartAlertsScreenState();
}

class _SmartAlertsScreenState extends State<SmartAlertsScreen> {
  final List<Map<String, dynamic>> _alerts = [
    {
      'id': 1,
      'title': 'Consumption Spike Detected',
      'message': 'Unusual high energy usage detected in HVAC system.',
      'level': 'critical', // red
      'time': '10 mins ago',
      'icon': Icons.warning_rounded,
    },
    {
      'id': 2,
      'title': 'AC Budget Exceeded',
      'message': 'Air Conditioner has exceeded the daily set budget of 15kWh.',
      'level': 'warning', // yellow
      'time': '2 hours ago',
      'icon': Icons.thermostat_rounded,
    },
    {
      'id': 3,
      'title': 'Peak Rate Active',
      'message': 'Current electricity rates are 1.5x higher until 8 PM.',
      'level': 'warning', // yellow
      'time': '4 hours ago',
      'icon': Icons.trending_up_rounded,
    },
    {
      'id': 4,
      'title': 'Weekly Report Ready',
      'message': 'Your weekly consumption analysis is ready to view.',
      'level': 'info', // blue
      'time': 'Yesterday',
      'icon': Icons.assignment_rounded,
    },
  ];

  void _dismissAlert(int id) {
    setState(() {
      _alerts.removeWhere((alert) => alert['id'] == id);
    });
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'critical':
        return UrjaTheme.errorRed;
      case 'warning':
        return UrjaTheme.warningOrange;
      case 'info':
        return UrjaTheme.accentCyan;
      default:
        return UrjaTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          if (_alerts.isEmpty)
            Center(
              child: Text(
                'No active alerts',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            ..._alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildAlertCard(context, alert),
                )),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UrjaTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: UrjaTheme.warningOrange, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Alerts Center',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time notifications about your energy consumption and system status',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final color = _getLevelColor(alert['level'] as String);
    
    return GlassCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(alert['icon'] as IconData, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                alert['title'] as String,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: color,
                                      fontSize: 18,
                                    ),
                              ),
                              Text(
                                alert['time'] as String,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert['message'] as String,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => _dismissAlert(alert['id'] as int),
                      icon: const Icon(Icons.close_rounded, color: UrjaTheme.textSecondary),
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
