import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/shimmer_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/energy_provider.dart';
import '../models/energy_data.dart';
import '../models/appliance.dart';

import '../services/ai_service.dart';
import '../services/energy_service.dart';
import '../widgets/urja_gauge.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // State Variables
  double _currentMonthKwh = 325;
  final double _nextMonthKwh = 309; // Predicted
  double _reductionTargetPercent = 10;
  Map<String, String> _aiAuditResult = {};
  
  // Hive Box
  late Box _settingsBox;
  bool _isLoading = true;
  final AIService _aiService = AIService();
  final EnergyService _energyService = EnergyService();
  // late Stream<Map<String, dynamic>> _usageStream; // Removed

  // Chart Data State
  // List<BarChartGroupData>? _chartData; // Removed unused field

  @override
  void initState() {
    super.initState();
    // _usageStream = _energyService.liveUsageStream; // Removed
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _settingsBox = await Hive.openBox('settings');

      if (mounted) {
        setState(() {
          _currentMonthKwh = _settingsBox.get('currentMonthKwh', defaultValue: 325.0);
          _reductionTargetPercent = _settingsBox.get('reductionTargetPercent', defaultValue: 10.0);
          _isLoading = false;
        });
      }
      
      // Fetch AI Audit
      _fetchAiAudit();
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAiAudit({double? currentKwh}) async {
    try {
      final result = await _aiService.generateEnergyAudit(currentKwh: currentKwh);
      if (mounted) {
        setState(() {
          _aiAuditResult = result;
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  void _saveSettings() {
    _settingsBox.put('currentMonthKwh', _currentMonthKwh);
    _settingsBox.put('reductionTargetPercent', _reductionTargetPercent);
  }

  double get _estimatedBill => _currentMonthKwh * 8.5; // Formula from user (Rupees)
  double get _estimatedSavings => _estimatedBill * (_reductionTargetPercent / 100);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardShimmer();

    final energyAsync = ref.watch(energyProvider);

    return energyAsync.when(
      loading: () => const DashboardShimmer(),
      error: (err, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $err'),
                backgroundColor: UrjaTheme.errorRed,
              ),
            );
          });
        return const Center(child: Text('Error loading data'));
      },
      data: (energyData) {
        final liveKwh = energyData.currentKWh;
        final dailyUsage = energyData.todayKWh;
        final status = energyData.status;

        // Trigger AI Audit if we have live data and haven't fetched it yet or it was default
        if (_aiAuditResult.isEmpty && liveKwh > 0) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             _fetchAiAudit(currentKwh: liveKwh);
           });
        }
          
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, status, dailyUsage),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildPredictedVsCurrentCard(context, liveKwh),
                                const SizedBox(height: 32),
                                // _buildApplianceManagerCard(context), // Removed
                                const SizedBox(height: 32),
                                _buildSixMonthTrendCard(context, liveKwh, energyData: energyData),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildReductionGoalCard(context, liveKwh),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildPredictedVsCurrentCard(context, liveKwh),
                          const SizedBox(height: 32),
                          // _buildApplianceManagerCard(context), // Moved to Dashboard
                          const SizedBox(height: 32),
                          _buildSixMonthTrendCard(context, liveKwh, energyData: energyData),
                          const SizedBox(height: 32),
                          _buildReductionGoalCard(context, liveKwh),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAIChatDialog(context),
            backgroundColor: UrjaTheme.primaryGreen,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Ask Urja AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    );
  }


  // Updated widgets to accept liveKwh
  Widget _buildPredictedVsCurrentCard(BuildContext context, double currentKwh) {
    // Dynamic prediction based on current usage
    // If current usage > predicted, adjust predicted to show it's exceeded or close
    // Simple logic: If current > 80% of predicted, bump predicted slightly to show growth trend
    final dynamicPredicted = currentKwh > (_nextMonthKwh * 0.8) ? (currentKwh * 1.2) : _nextMonthKwh;
    
    // Use the class-level getter to avoid code duplication and unused warning
    final estimatedBill = currentKwh * 8.5; // Recalculate based on live data
    
    return Column(
      children: [
        // New AI Insight Card at the top
        if (_aiAuditResult.isNotEmpty) ...[
          _buildAIAuditCard(context),
          const SizedBox(height: 24),
        ],
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Predicted vs Current Usage', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.edit, color: UrjaTheme.textSecondary),
                    tooltip: 'Edit Current Usage',
                    onPressed: () => _showManualEntryDialog(context, currentKwh),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Gauge/Meter Integration for Live kWh
              Center(
                child: UrjaGauge(
                  kWh: currentKwh,
                  percent: (currentKwh / 500).clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(height: 24),

              _buildProgressBar(context, 'Next Month (Predicted)', dynamicPredicted, 500, UrjaTheme.warningOrange),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimated Bill', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          '₹${estimatedBill.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1B5E20) : UrjaTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: UrjaTheme.cardBackground,
                            title: const Text('Detailed Breakdown', style: TextStyle(color: UrjaTheme.textPrimary)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildBreakdownRow('Energy Charge', '₹${(estimatedBill * 0.8).toStringAsFixed(2)}'),
                                const SizedBox(height: 8),
                                _buildBreakdownRow('Fixed Charges', '₹${(estimatedBill * 0.1).toStringAsFixed(2)}'),
                                const SizedBox(height: 8),
                                _buildBreakdownRow('Taxes (10%)', '₹${(estimatedBill * 0.1).toStringAsFixed(2)}'),
                                const Divider(color: UrjaTheme.glassBorder, height: 24),
                                _buildBreakdownRow('Total Estimate', '₹${estimatedBill.toStringAsFixed(2)}', isBold: true),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close', style: TextStyle(color: UrjaTheme.primaryGreen)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UrjaTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('View Breakdown'),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
        const SizedBox(height: 32),
        // Connected Appliances Section
        _buildConnectedAppliancesCard(context),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: UrjaTheme.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: UrjaTheme.textPrimary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildConnectedAppliancesCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connected Appliances', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0, // Square aspect ratio for centered layout
          children: [
            _buildApplianceToggleCard(context, 'AC', '1.5 kWh', Icons.ac_unit, true),
            _buildApplianceToggleCard(context, 'Refrigerator', '0.8 kWh', Icons.kitchen, true),
            _buildApplianceToggleCard(context, 'Lights', '0.2 kWh', Icons.lightbulb, false),
            _buildApplianceToggleCard(context, 'Geyser', '0.0 kWh', Icons.water_drop, false),
          ],
        ),
      ],
    );
  }

  // Reference Map for Standard Appliance Ratings
  final Map<String, String> _standardRatings = {
    'AC': '1.5 - 2.0 kWh',
    'Refrigerator': '0.1 - 0.2 kWh',
    'Geyser': '2.0 - 3.0 kWh',
    'Lights': '0.01 kWh',
    'LED Lights': '0.01 kWh',
    'Fan': '0.05 - 0.1 kWh',
    'TV': '0.1 - 0.2 kWh',
    'Washing Machine': '0.5 - 1.0 kWh',
  };

  Widget _buildApplianceToggleCard(BuildContext context, String name, String consumption, IconData icon, bool isActive) {
    // Local state for toggle simulation
    return StatefulBuilder(
      builder: (context, setState) {
        // Get standard rating or default
        final rating = _standardRatings[name] ?? _standardRatings[name.split(' ').first] ?? '-- kWh';
        final displayRating = 'Avg: $rating';

        return GestureDetector(
          onTap: () {
            setState(() {
              isActive = !isActive;
            });
          },
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: isActive ? UrjaTheme.primaryGreen : UrjaTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  displayRating,
                  style: TextStyle(
                    color: isActive ? UrjaTheme.primaryGreen : UrjaTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildAIAuditCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Text('Urja AI Energy Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Potential Savings: ${_aiAuditResult['saving']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _aiAuditResult['insight'] ?? 'Analyzing...',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Action: ${_aiAuditResult['action']}",
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAIChatDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> messages = [];
    bool isThinking = false; // Re-introduced for UI feedback

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
                child: GlassCard(
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: UrjaTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          const Text('Urja AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: UrjaTheme.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: UrjaTheme.glassBorder),
                      
                      // Chat Area
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'Ask me anything about your energy usage!',
                                  style: TextStyle(color: UrjaTheme.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final isUser = msg['role'] == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isUser ? UrjaTheme.primaryGreen : UrjaTheme.glassBorder.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        msg['content']!,
                                        style: TextStyle(color: isUser ? Colors.white : UrjaTheme.textPrimary),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      
                      if (isThinking)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Urja Buddy is thinking...', style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),

                      // Input Area
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                style: const TextStyle(color: UrjaTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Type your question...',
                                  hintStyle: const TextStyle(color: UrjaTheme.textSecondary),
                                  filled: true,
                                  fillColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                onSubmitted: (_) => _sendMessage(setState, controller, messages, (val) => isThinking = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => _sendMessage(setState, controller, messages, (val) => isThinking = val),
                              icon: const Icon(Icons.send, color: UrjaTheme.primaryGreen),
                              style: IconButton.styleFrom(
                                backgroundColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendMessage(StateSetter setState, TextEditingController controller, List<Map<String, String>> messages, Function(bool) setLoading) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': text});
      controller.clear();
      setLoading(true); // Start loading
    });

    // Call AI
    final response = await _aiService.getAIResponse(text);

    setState(() {
      messages.add({'role': 'assistant', 'content': response});
      setLoading(false); // Stop loading
    });
  }

  Widget _buildProgressBar(BuildContext context, String label, double value, double max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text('${value.toInt()} kWh', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (value / max).clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String status, double dailyUsage) {
    Color statusColor = UrjaTheme.primaryGreen;
    String statusText = 'Status: ${status.toUpperCase()}';
    IconData statusIcon = Icons.psychology;

    if (status.toLowerCase() == 'online') {
      statusColor = const Color(0xFF00C853); // Bright Green for Online
      statusText = 'LIVE SYNC ACTIVE';
      statusIcon = Icons.wifi;
    } else if (status.toLowerCase() == 'offline') {
      statusColor = UrjaTheme.errorRed;
      statusText = 'OFFLINE';
      statusIcon = Icons.wifi_off;
    } else if (status == 'High Usage') {
      statusColor = UrjaTheme.warningOrange;
    }
    
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              statusIcon, 
              color: statusColor, 
              size: 32
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Energy Analytics',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (status.toLowerCase() == 'online')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Text(
                      '• Daily Avg: ${dailyUsage.toStringAsFixed(1)} kWh',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildBadge(context, 'High Prediction Confidence', Icons.check_circle),
                    const SizedBox(width: 12),
                    _buildBadge(context, '6 Months of Data', Icons.history),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UrjaTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: UrjaTheme.primaryGreen, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: UrjaTheme.primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ... (Other widgets remain same)


  int _selectedTrendTab = 1; // 0: Weekly, 1: Monthly, 2: Yearly

  Widget _buildSixMonthTrendCard(BuildContext context, double currentMonthlyKwh, {EnergyData? energyData}) {
    List<double> weeklyData = [];
    List<double> monthlyData = [];
    List<double> yearlyData = [];
    double currentDailyKwh = 0.0;
    
    if (energyData != null) {
      weeklyData = List.from(energyData.weeklyTrend);
      monthlyData = List.from(energyData.monthlyTrend);
      yearlyData = List.from(energyData.yearlyTrend);
      currentDailyKwh = energyData.todayKWh;
    }
    
    // Fallback if empty
    if (weeklyData.isEmpty) weeklyData = List.filled(7, 0.0);
    if (monthlyData.isEmpty) monthlyData = List.filled(12, 0.0);
    if (yearlyData.isEmpty) yearlyData = List.filled(5, 0.0);

    // Determine data based on selection
    List<double> currentData = [];
    
    if (_selectedTrendTab == 0) {
      // Daily (Week) View
      currentData = weeklyData;
      // Ensure today's data is accurate from the live calculation
      if (currentDailyKwh > 0 && currentData.isNotEmpty) {
        final todayIndex = DateTime.now().weekday - 1;
        if (todayIndex >= 0 && todayIndex < currentData.length) {
          currentData[todayIndex] = currentDailyKwh;
        }
      }
    } else if (_selectedTrendTab == 1) {
      // Monthly View
      currentData = monthlyData;
      // Optional: Update current month if needed, but rely mostly on logs
      // If we want to be super real-time, we could ensure current month includes today's live usage
      // But typically logs are close enough. The user issue was specifically about Daily view showing Monthly data.
    } else {
      // Yearly View
      currentData = yearlyData;
    }

    // Determine current data to show
    List<double> displayData = currentData;
    double maxY;
    
    if (_selectedTrendTab == 0) {
      final maxVal = displayData.reduce((curr, next) => curr > next ? curr : next);
      // Ensure min Y is at least 20 or 1.5x of today's usage
      final minMaxY = currentDailyKwh * 1.5;
      final calculatedMaxY = maxVal * 1.2;
      maxY = (calculatedMaxY > minMaxY ? calculatedMaxY : minMaxY).clamp(20.0, 50000.0);
    } else if (_selectedTrendTab == 1) {
      final maxVal = displayData.reduce((curr, next) => curr > next ? curr : next);
      maxY = (maxVal * 1.2).clamp(100.0, 50000.0);
    } else {
      final maxVal = displayData.reduce((curr, next) => curr > next ? curr : next);
      maxY = (maxVal * 1.2).clamp(1000.0, 100000.0);
    }

    final barGroups = _getChartData(displayData, maxY);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consumption Trends', style: Theme.of(context).textTheme.titleLarge),
              Container(
                decoration: BoxDecoration(
                  color: UrjaTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: UrjaTheme.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabButton('Week', 0),
                    _buildTabButton('Month', 1),
                    _buildTabButton('Year', 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true, // Enable touch for tooltip
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => UrjaTheme.cardBackground,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label;
                      if (_selectedTrendTab == 0) {
                        label = 'Daily';
                      } else if (_selectedTrendTab == 1) {
                        label = 'Monthly';
                      } else {
                        label = 'Yearly';
                      }
                      
                      return BarTooltipItem(
                        '$label: ${rod.toY.toStringAsFixed(1)} kWh',
                        const TextStyle(
                          color: UrjaTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta _) {
                        int index = value.toInt();
                        if (index < 0) return const SizedBox();
                        
                        // Dynamic labels
                        if (_selectedTrendTab == 0) { // Weekly
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (index < days.length) {
                             return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[index], style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
                          }
                        } else if (_selectedTrendTab == 1) { // Monthly
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                           if (index < months.length) {
                             // Show every 2nd label to save space on small screens if needed
                             return Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[index], style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
                          }
                        } else { // Yearly
                          final currentYear = DateTime.now().year;
                          final years = List.generate(5, (i) => (currentYear - 4) + i);
                          if (index < years.length) {
                             return Padding(padding: const EdgeInsets.only(top: 8), child: Text(years[index].toString(), style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
                          }
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text('${value.toInt()}', style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: UrjaTheme.glassBorder,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to generate chart data dynamically
  List<BarChartGroupData> _getChartData(List<double> data, double maxY) {
    return data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: UrjaTheme.primaryGreen,
            width: _selectedTrendTab == 1 ? 12 : 16, // Thinner bars for monthly view
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY, // Full height background
              color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }).toList();
  }

  // List<BarChartGroupData> _getTrendData(double currentKwh) {
  //   if (_selectedTrendTab == 0) { // Weekly Data (Mock)
  //      return [
  //       _makeBarGroup(0, 15), _makeBarGroup(1, 18), _makeBarGroup(2, 12),
  //       _makeBarGroup(3, 20), _makeBarGroup(4, 22), _makeBarGroup(5, 25), _makeBarGroup(6, 10),
  //     ];
  //   } else if (_selectedTrendTab == 1) { // Monthly Data
  //     return [
  //       _makeBarGroup(0, 450), _makeBarGroup(1, 420), _makeBarGroup(2, 380),
  //       _makeBarGroup(3, 400), _makeBarGroup(4, 350), _makeBarGroup(5, currentKwh, isCurrent: true),
  //     ];
  //   } else { // Yearly Data (Mock)
  //      return [
  //       _makeBarGroup(0, 3500), _makeBarGroup(1, 3800), _makeBarGroup(2, 3600),
  //       _makeBarGroup(3, 4000), _makeBarGroup(4, 4200), _makeBarGroup(5, 4500),
  //     ];
  //   }
  // }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTrendTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTrendTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? UrjaTheme.primaryGreen.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? UrjaTheme.primaryGreen : Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // BarChartGroupData _makeBarGroup(int x, double y, {bool isCurrent = false}) {
  //   return BarChartGroupData(
  //     x: x,
  //     barRods: [
  //       BarChartRodData(
  //         toY: y,
  //         color: isCurrent ? UrjaTheme.primaryGreen : UrjaTheme.accentCyan.withValues(alpha: 0.7),
  //         width: 20,
  //         borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildReductionGoalCard(BuildContext context, double currentKwh) {
    // Use class-level getters
    final estimatedSavings = _estimatedSavings;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reduction Goal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          const Text('Target Savings'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: UrjaTheme.primaryGreen,
                    inactiveTrackColor: UrjaTheme.glassBorder,
                    thumbColor: Colors.white,
                    overlayColor: UrjaTheme.primaryGreen.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _reductionTargetPercent,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: '${_reductionTargetPercent.toInt()}%',
                    onChanged: (val) {
                      setState(() {
                        _reductionTargetPercent = val;
                        _saveSettings();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_reductionTargetPercent.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UrjaTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.savings, color: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Monthly Savings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('₹${estimatedSavings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated Manual Entry Dialog
  void _showManualEntryDialog(BuildContext context, double currentKwh) {
    final prevController = TextEditingController();
    final currentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UrjaTheme.cardBackground,
        title: const Text('Manual Meter Reading', style: TextStyle(color: UrjaTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your meter readings to calculate usage.',
              style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: prevController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: UrjaTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Previous Reading (kWh)',
                labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
              ),
            ),
            TextField(
              controller: currentController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: UrjaTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Current Reading (kWh)',
                labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: UrjaTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prev = double.tryParse(prevController.text);
              final curr = double.tryParse(currentController.text);
              
              if (prev != null && curr != null) {
                try {
                  await _energyService.saveMeterReading(previousReading: prev, currentReading: curr);
                  if (context.mounted) {
                    Navigator.pop(context);
                    // Refresh AI Audit with new data
                    _fetchAiAudit(currentKwh: curr - prev);
                  }
                } catch (e) {
                  if (context.mounted) {
                    // Extract clean message from exception
                    final message = e.toString().replaceAll('Exception:', '').trim();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UrjaTheme.primaryGreen),
            child: const Text('Calculate & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // _showApplianceDialog removed
}


