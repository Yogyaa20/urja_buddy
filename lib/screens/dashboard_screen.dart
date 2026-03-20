import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/shimmer_loading.dart';
import '../models/energy_data.dart';
import '../services/energy_service.dart';
import '../services/ai_service.dart';
import '../services/tariff_service.dart';
import '../services/pdf_service.dart';
import '../providers/energy_provider.dart';
import '../providers/user_provider.dart';
import '../theme/urja_theme.dart';
import '../widgets/urja_gauge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Analytics state
  double _currentMonthKwh = 325;
  final double _nextMonthKwh = 309;
  double _reductionTargetPercent = 10;
  Map<String, String> _aiAuditResult = {};
  late Box _settingsBox;
  bool _isLoading = true;
  int _selectedTrendTab = 1;

  final AIService _aiService = AIService();
  final EnergyService _energyService = EnergyService();

  @override
  void initState() {
    super.initState();
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
      _fetchAiAudit();
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAiAudit({double? currentKwh}) async {
    try {
      final result = await _aiService.generateEnergyAudit(currentKwh: currentKwh);
      if (mounted) setState(() => _aiAuditResult = result);
    } catch (e) {
      // Silent error
    }
  }

  void _saveSettings() {
    _settingsBox.put('currentMonthKwh', _currentMonthKwh);
    _settingsBox.put('reductionTargetPercent', _reductionTargetPercent);
  }

  double get _estimatedBill => _currentMonthKwh * 8.5;
  double get _estimatedSavings => _estimatedBill * (_reductionTargetPercent / 100);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardShimmer();

    final energyAsync = ref.watch(energyProvider);
    final isLargeDesktop = MediaQuery.of(context).size.width > 1200;

    return energyAsync.when(
      loading: () => const DashboardShimmer(),
      error: (err, stack) => Center(
        child: Text('Error loading data: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (data) {
        final liveKwh = data.currentKWh;
        final dailyUsage = data.todayKWh;
        final status = data.status;

        if (_aiAuditResult.isEmpty && liveKwh > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchAiAudit(currentKwh: liveKwh);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SECTION 1: Dashboard Header ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Dashboard Overview",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _downloadPdfBill(context, data),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text("Download Bill"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── SECTION 2: Metric Cards ──────────────────────────────
              _buildMetricsRow(context, data),
              const SizedBox(height: 32),

              // ── SECTION 3: Charts + Leaderboard ─────────────────────
              LayoutBuilder(builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            ConsumptionTrendChart(
                              weeklyData: data.weeklyTrend,
                              monthlyData: data.monthlyTrend,
                              yearlyData: data.yearlyTrend,
                              todayTotalOverride: data.todayKWh,
                            ),
                            const SizedBox(height: 32),
                            _buildSecondaryRow(context, data),
                          ],
                        ),
                      ),
                      if (isLargeDesktop) ...[
                        const SizedBox(width: 32),
                        const Expanded(
                          flex: 1,
                          child: Column(children: [LeaderboardCard()]),
                        ),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    ConsumptionTrendChart(
                      weeklyData: data.weeklyTrend,
                      monthlyData: data.monthlyTrend,
                      yearlyData: data.yearlyTrend,
                      todayTotalOverride: data.todayKWh,
                    ),
                    const SizedBox(height: 32),
                    _buildSecondaryRow(context, data),
                  ],
                );
              }),

              if (!isLargeDesktop) ...[
                const SizedBox(height: 32),
                const LeaderboardCard(),
              ],

              // ── DIVIDER ──────────────────────────────────────────────
              const SizedBox(height: 48),
              Row(children: [
                Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Smart Energy Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: UrjaTheme.textSecondary),
                  ),
                ),
                Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))),
              ]),
              const SizedBox(height: 32),

              // ── SECTION 4: Analytics Header ──────────────────────────
              _buildAnalyticsHeader(context, status, dailyUsage),
              const SizedBox(height: 32),

              // ── SECTION 5: Analytics Content ─────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildPredictedVsCurrentCard(context, liveKwh, data),
                            const SizedBox(height: 32),
                            _buildSixMonthTrendCard(context, liveKwh, energyData: data),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 2,
                        child: _buildReductionGoalCard(context, liveKwh),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildPredictedVsCurrentCard(context, liveKwh, data),
                    const SizedBox(height: 32),
                    _buildSixMonthTrendCard(context, liveKwh, energyData: data),
                    const SizedBox(height: 32),
                    _buildReductionGoalCard(context, liveKwh),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── DASHBOARD WIDGETS ────────────────────────────────────────────────────

  Widget _buildMetricsRow(BuildContext context, EnergyData data) {
    final billDetails = TariffService.calculateBill(data.state, data.currentKWh);
    final estimatedBill = billDetails.totalPayable;
    final currentMonthIndex = DateTime.now().month - 1;
    final totalThisMonth = (data.monthlyTrend.isNotEmpty && currentMonthIndex < data.monthlyTrend.length)
        ? data.monthlyTrend[currentMonthIndex]
        : data.currentKWh;
    final dailyAvgKwh = DateTime.now().day > 0 ? totalThisMonth / DateTime.now().day : 0.0;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      final metrics = [
        Stack(
          children: [
            MetricCard(
              title: "Today's Usage",
              value: '${data.todayKWh.toStringAsFixed(1)} kWh',
              subValue: data.currentKWh > 0 ? 'Active' : 'No Devices',
              isPositive: true,
              icon: Icons.electric_bolt_rounded,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: "Reset today's usage",
                child: InkWell(
                  onTap: () => _showResetTodayDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: UrjaTheme.errorRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: UrjaTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 14, color: UrjaTheme.errorRed),
                  ),
                ),
              ),
            ),
          ],
        ),
        MetricCard(
          title: "Daily Avg Consumption",
          value: '${dailyAvgKwh.toStringAsFixed(1)} kWh',
          subValue: 'This month average',
          isPositive: true,
          icon: Icons.moving_rounded,
        ),
        MetricCard(
          title: 'Estimated Bill This Month',
          value: '₹${estimatedBill.toStringAsFixed(0)}',
          subValue: data.state != null ? '${data.state} Tariff' : 'Updating...',
          isPositive: true,
          icon: Icons.currency_rupee_rounded,
        ),
      ];

      if (isMobile) {
        return Column(
          children: metrics.map((m) => Padding(padding: const EdgeInsets.only(bottom: 16), child: m)).toList(),
        );
      }
      return Row(
        children: metrics.map((m) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: m))).toList(),
      );
    });
  }

  Widget _buildSecondaryRow(BuildContext context, EnergyData data) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SmartHubCard(
              currentLimit: data.budgetLimit,
              currentUsage: data.currentKWh,
              onLimitChanged: (val) => EnergyService().updateBudgetLimit(val),
            ),
            const SizedBox(height: 32),
            ConsumptionBreakdownChart(appliances: data.appliances),
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: SmartHubCard(
              currentLimit: data.budgetLimit,
              currentUsage: data.currentKWh,
              onLimitChanged: (val) => EnergyService().updateBudgetLimit(val),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(child: ConsumptionBreakdownChart(appliances: data.appliances)),
        ],
      );
    });
  }

  Future<void> _downloadPdfBill(BuildContext context, EnergyData data) async {
    final userState = ref.read(userProvider).value;
    if (userState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User profile not loaded yet')));
      return;
    }
    final billDetails = TariffService.calculateBill(data.state, data.currentKWh);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Bill...')));
    await PdfService.generateAndDownloadBill(
      billDetails: billDetails,
      userName: userState.familyName ?? userState.displayName ?? 'User',
      address: userState.unitNumber ?? '',
      stateName: data.state ?? 'Delhi',
    );
  }

  // ── ANALYTICS WIDGETS ────────────────────────────────────────────────────

  Widget _buildAnalyticsHeader(BuildContext context, String status, double dailyUsage) {
    Color statusColor = UrjaTheme.primaryGreen;
    String statusText = 'Status: ${status.toUpperCase()}';
    IconData statusIcon = Icons.psychology;

    if (status.toLowerCase() == 'online') {
      statusColor = const Color(0xFF00C853);
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
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Energy Analytics', style: Theme.of(context).textTheme.headlineMedium),
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
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      Text(statusText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('• Daily Avg: ${dailyUsage.toStringAsFixed(1)} kWh', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildBadge(context, 'High Prediction Confidence', Icons.check_circle),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: UrjaTheme.primaryGreen, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: UrjaTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPredictedVsCurrentCard(BuildContext context, double currentKwh, EnergyData energyData) {
    final dynamicPredicted = currentKwh > (_nextMonthKwh * 0.8) ? (currentKwh * 1.2) : _nextMonthKwh;
    final billDetails = TariffService.calculateBill(energyData.state, currentKwh);
    final estimatedBill = billDetails.totalPayable;

    return Column(
      children: [
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final userState = ref.read(userProvider);
                    final bd = TariffService.calculateBill(energyData.state, currentKwh);
                    await PdfService.generateAndDownloadBill(
                      billDetails: bd,
                      userName: userState.value?.familyName ?? userState.value?.displayName ?? 'Urja User',
                      address: userState.value?.unitNumber ?? 'F-101 Green Valley',
                      stateName: energyData.state ?? 'Delhi',
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download Bill PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1B5E20) : UrjaTheme.primaryGreen,
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1B5E20) : UrjaTheme.primaryGreen,
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Potential Savings: ${_aiAuditResult['saving']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_aiAuditResult['insight'] ?? 'Analyzing...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("Action: ${_aiAuditResult['action']}", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildSixMonthTrendCard(BuildContext context, double currentMonthlyKwh, {EnergyData? energyData}) {
    List<double> weeklyData = List.from(energyData?.weeklyTrend ?? []);
    List<double> monthlyData = List.from(energyData?.monthlyTrend ?? []);
    List<double> yearlyData = List.from(energyData?.yearlyTrend ?? []);
    double currentDailyKwh = energyData?.todayKWh ?? 0.0;

    if (weeklyData.isEmpty) weeklyData = List.filled(7, 0.0);
    if (monthlyData.isEmpty) monthlyData = List.filled(12, 0.0);
    if (yearlyData.isEmpty) yearlyData = List.filled(5, 0.0);

    List<double> currentData;
    if (_selectedTrendTab == 0) {
      currentData = weeklyData;
      if (currentDailyKwh > 0 && currentData.isNotEmpty) {
        final todayIndex = DateTime.now().weekday - 1;
        if (todayIndex >= 0 && todayIndex < currentData.length) currentData[todayIndex] = currentDailyKwh;
      }
    } else if (_selectedTrendTab == 1) {
      currentData = monthlyData;
    } else {
      currentData = yearlyData;
    }

    double maxY;
    if (_selectedTrendTab == 0) {
      final maxVal = currentData.reduce((a, b) => a > b ? a : b);
      maxY = ((maxVal * 1.2) > (currentDailyKwh * 1.5) ? (maxVal * 1.2) : (currentDailyKwh * 1.5)).clamp(20.0, 50000.0);
    } else if (_selectedTrendTab == 1) {
      maxY = (currentData.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, 50000.0);
    } else {
      maxY = (currentData.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, 100000.0);
    }

    final barGroups = currentData.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: UrjaTheme.primaryGreen,
            width: _selectedTrendTab == 1 ? 12 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Consumption Trends', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: "Reset trend data",
                    child: InkWell(
                      onTap: () => _showResetTrendDialog(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: UrjaTheme.errorRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: UrjaTheme.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.refresh_rounded, size: 14, color: UrjaTheme.errorRed),
                      ),
                    ),
                  ),
                ],
              ),
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
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => UrjaTheme.cardBackground,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = _selectedTrendTab == 0 ? 'Daily' : _selectedTrendTab == 1 ? 'Monthly' : 'Yearly';
                      return BarTooltipItem('$label: ${rod.toY.toStringAsFixed(1)} kWh', const TextStyle(color: UrjaTheme.primaryGreen, fontWeight: FontWeight.bold));
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
                        final index = value.toInt();
                        if (index < 0) return const SizedBox();
                        if (_selectedTrendTab == 0) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (index < days.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[index], style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
                        } else if (_selectedTrendTab == 1) {
                          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          if (index < months.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[index], style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
                        } else {
                          final years = List.generate(5, (i) => (DateTime.now().year - 4) + i);
                          if (index < years.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(years[index].toString(), style: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)));
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
                  getDrawingHorizontalLine: (value) => FlLine(color: UrjaTheme.glassBorder, strokeWidth: 1, dashArray: [5, 5]),
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

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTrendTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTrendTab = index),
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

  Widget _buildReductionGoalCard(BuildContext context, double currentKwh) {
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
            decoration: BoxDecoration(color: UrjaTheme.primaryGreen, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.savings, color: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Monthly Savings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('₹${_estimatedSavings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            const Text('Enter your meter readings to calculate usage.', style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 12)),
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
                    _fetchAiAudit(currentKwh: curr - prev);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim())));
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

  void _showResetTodayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UrjaTheme.cardBackground,
        title: const Text("Reset Today's Usage?", style: TextStyle(color: UrjaTheme.textPrimary)),
        content: const Text(
          "This will reset today's usage to 0. This action cannot be undone.",
          style: TextStyle(color: UrjaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: UrjaTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _energyService.resetTodayUsage();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Today's usage reset successfully!"),
                      backgroundColor: UrjaTheme.primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: UrjaTheme.errorRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UrjaTheme.errorRed),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResetTrendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UrjaTheme.cardBackground,
        title: const Text('Reset Trend Data', style: TextStyle(color: UrjaTheme.textPrimary)),
        content: const Text(
          'Choose what to reset. This action cannot be undone.',
          style: TextStyle(color: UrjaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: UrjaTheme.textSecondary)),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _energyService.resetCurrentMonthTrend();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Current month data reset!'),
                      backgroundColor: UrjaTheme.primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: UrjaTheme.errorRed),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: UrjaTheme.warningOrange,
              side: const BorderSide(color: UrjaTheme.warningOrange),
            ),
            child: const Text('This Month'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _energyService.resetAllTrendData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All trend data reset!'),
                      backgroundColor: UrjaTheme.primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: UrjaTheme.errorRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UrjaTheme.errorRed),
            child: const Text('All Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}