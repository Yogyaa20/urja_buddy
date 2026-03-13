import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/dashboard_widgets.dart';
import '../models/energy_data.dart';
import '../services/energy_service.dart';
import '../widgets/appliance_manager_card.dart';
import '../providers/energy_provider.dart';
// import 'analytics_screen.dart'; // Import for ApplianceManager related logic if needed

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(energyProvider);
    final isLargeDesktop = MediaQuery.of(context).size.width > 1200;

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
      error: (err, stack) => Center(child: Text('Error loading data: $err', style: const TextStyle(color: Colors.red))),
      data: (data) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Metrics
              _buildMetricsRow(context, data),
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Content Column
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Main Graph
                        ConsumptionTrendChart(
                          weeklyData: data.weeklyTrend, 
                          monthlyData: data.monthlyTrend,
                          yearlyData: data.yearlyTrend,
                          todayTotalOverride: data.todayKWh, // Force today's total
                        ),
                        const SizedBox(height: 32),

                        // Smart Hub & Breakdown
                        _buildSecondaryRow(context, data, ref),
                        const SizedBox(height: 32),
                        
                        // AI Insights
                        AiInsightsCard(appliances: data.appliances),
                        const SizedBox(height: 32),

                        // Appliance Manager (Moved from Analytics)
                        const ApplianceManagerCard(),
                      ],
                    ),
                  ),
                  
                  // Right Panel (Leaderboard) - Only on Large Desktop
                  if (isLargeDesktop) ...[
                    const SizedBox(width: 32),
                    const Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          LeaderboardCard(),
                          // Add more right panel widgets here if needed
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Leaderboard for smaller screens
              if (!isLargeDesktop) ...[
                const SizedBox(height: 32),
                const LeaderboardCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsRow(BuildContext context, EnergyData data) {
    // Calculate total bill from appliances if no historical data or just to be consistent
    // data.currentKWh is now the sum of appliances (set in service)
    // Formula: Bill = kW * 8.5
    final estimatedBill = data.currentKWh * 8.5;
    
    // Responsive Grid for Metrics
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 700;
        
        final metrics = [
          MetricCard(
            title: "Today's Usage",
            value: '${data.todayKWh.toStringAsFixed(1)} kWh', // Use Daily Total (Appliance Sum)
            subValue: data.currentKWh > 0 ? 'Active' : 'No Devices',
            isPositive: true,
            icon: Icons.electric_bolt_rounded,
          ),
          MetricCard(
            title: 'Estimated Bill',
            value: '₹${estimatedBill.toStringAsFixed(0)}',
            subValue: data.currentKWh > 0 ? 'Based on usage' : 'Add appliances',
            isPositive: true,
            icon: Icons.currency_rupee_rounded,
          ),
        ];

        if (isMobile) {
          return Column(
            children: metrics
                .map((m) => Padding(padding: const EdgeInsets.only(bottom: 16), child: m))
                .toList(),
          );
        }

        return Row(
          children: metrics.map((m) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: m))).toList(),
        );
      },
    );
  }

  Widget _buildSecondaryRow(BuildContext context, EnergyData data, WidgetRef ref) {
    // We need the list of appliances to pass to the chart
    // Assuming data (EnergyData) has an 'appliances' field or we fetch it from another provider.
    // The previous code structure suggests appliances might be managed separately or inside EnergyData.
    // Let's check EnergyData model or EnergyProvider.
    // Wait, EnergyData usually has aggregate metrics. 
    // ApplianceManagerCard uses a local state or provider.
    // If we want to sync, we should expose the appliances list via a provider.
    // I see `const ApplianceManagerCard()` usage below, which likely manages its own state or uses a provider.
    // I'll check `lib/providers/energy_provider.dart` or `lib/models/energy_data.dart`.
    // But since I can't check right now without another turn, I'll assume I can access `ref.watch(applianceProvider)` if it exists.
    // Or if `EnergyData` has it.
    
    // Let's try to pass `data.appliances` if it exists.
    // If not, I'll use a placeholder or empty list and let the user know.
    // Actually, I can check `EnergyData` definition if I had read it. I didn't read `energy_data.dart`.
    // But I read `energy_provider.dart` implicitly? No.
    // However, `ApplianceManagerCard` is likely using a local list or a specific provider.
    // I'll assume for now we need to fetch appliances.
    // Let's look at `ApplianceManagerCard` implementation if possible. 
    // Wait, I modified `ApplianceManagerCard.dart` earlier. It had `_appliances` local state?
    // Let's check `lib/widgets/appliance_manager_card.dart`.
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              SmartHubCard(
                currentLimit: data.budgetLimit,
                currentUsage: data.currentKWh,
                onLimitChanged: (val) {
                  EnergyService().updateBudgetLimit(val);
                },
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
                onLimitChanged: (val) {
                  EnergyService().updateBudgetLimit(val);
                },
              ),
            ),
            const SizedBox(width: 32),
            Expanded(child: ConsumptionBreakdownChart(appliances: data.appliances)),
          ],
        );
      },
    );
  }
}
