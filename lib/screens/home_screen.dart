import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../widgets/main_layout.dart';
import '../services/energy_service.dart';
import '../theme/urja_theme.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'smart_alerts_screen.dart';
import 'community_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription? _usageSubscription;
  DateTime? _lastAlertTime;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const AnalyticsScreen(),
    const SmartAlertsScreen(),
    const CommunityScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startUsageMonitoring();
  }

  void _startUsageMonitoring() {
    _usageSubscription = EnergyService().energyDataStream.listen((data) {
      if (!mounted) return;

      final currentKwh = data.currentKWh;
      // Get the user's set limit from the global provider (via stream data)
      final limit = data.budgetLimit;

      if (currentKwh > limit) {
        _triggerHighUsageAlert(currentKwh, limit);
      }
    });
  }

  void _triggerHighUsageAlert(double current, double limit) {
    final now = DateTime.now();
    // Prevent spamming: Show alert only once every 5 minutes
    if (_lastAlertTime != null && now.difference(_lastAlertTime!) < const Duration(minutes: 5)) {
      return;
    }

    _lastAlertTime = now;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: UrjaTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'High Usage Warning!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current usage (${current.toStringAsFixed(1)} kWh) exceeds your limit of ${limit.toInt()} kWh.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'SETTINGS',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to Dashboard to change limit or Settings
            setState(() => _currentIndex = 0); // Go to Dashboard
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      child: _pages[_currentIndex < _pages.length ? _currentIndex : 0],
    );
  }
}
