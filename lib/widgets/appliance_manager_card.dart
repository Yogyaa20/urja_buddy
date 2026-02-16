import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appliance.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../services/ai_service.dart';
import '../services/energy_service.dart';
import '../providers/energy_provider.dart';

class ApplianceManagerCard extends ConsumerStatefulWidget {
  const ApplianceManagerCard({super.key});

  @override
  ConsumerState<ApplianceManagerCard> createState() => _ApplianceManagerCardState();
}

class _ApplianceManagerCardState extends ConsumerState<ApplianceManagerCard> {
  // Local state removed in favor of Riverpod
  bool _isLoading = false; // Managed by StreamProvider state
  String _dailyTip = 'Loading AI Tip...';
  final AIService _aiService = AIService();
  final EnergyService _energyService = EnergyService();

  @override
  void initState() {
    super.initState();
    _fetchAiTip();
  }
  
  // _loadData removed

  Future<void> _fetchAiTip() async {
    try {
      final tip = await _aiService.getTipOfTheDay();
      if (mounted) {
        setState(() {
          _dailyTip = tip;
        });
      }
    } catch (e) {
      debugPrint("AI Tip Error: $e");
    }
  }

  // _saveAppliances removed
  // _addAppliance removed (logic in dialog)

  void _editAppliance(Appliance app) async {
    try {
      await _energyService.updateAppliance(app);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'), backgroundColor: UrjaTheme.errorRed),
        );
      }
    }
  }

  void _deleteAppliance(String id) async {
    try {
      await _energyService.deleteAppliance(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: UrjaTheme.errorRed),
        );
      }
    }
  }


  double _calculateTotalCost(List<Appliance> appliances) {
    return appliances.fold(0, (sum, item) => sum + item.monthlyCost);
  }

  @override
  Widget build(BuildContext context) {
    final energyAsync = ref.watch(energyProvider);
    
    return energyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: UrjaTheme.primaryGreen)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: UrjaTheme.errorRed))),
      data: (energyData) {
        final appliances = energyData.appliances;
        
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Appliance Manager', style: Theme.of(context).textTheme.titleLarge),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: UrjaTheme.glassBorder,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total: ₹${_calculateTotalCost(appliances).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: UrjaTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: UrjaTheme.primaryGreen),
                        onPressed: () => _showApplianceDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (appliances.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Icon(Icons.devices_other, size: 48, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          'No appliances added yet. Tap \'+\' to start tracking.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).disabledColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appliances.length,
                  separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), height: 32),
                  itemBuilder: (context, index) {
                    final app = appliances[index];
                    return InkWell(
                      onTap: () => _showApplianceDialog(context, appliance: app),
                      child: _buildApplianceItem(
                        context, 
                        app.name, 
                        '${app.wattage.toInt()}W', 
                        '${app.hoursPerDay}h/day', 
                        '₹${app.monthlyCost.toStringAsFixed(2)}', 
                        Icons.electrical_services,
                        isOverBudget: app.monthlyCost > 20, 
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: UrjaTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text('AI Tip of the Day', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              _buildSmartTip(context, '1', _dailyTip),
            ],
          ),
        );
      }
    );
  }

  Widget _buildApplianceItem(BuildContext context, String name, String power, String usage, String cost, IconData icon, {bool isOverBudget = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (isOverBudget) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'High Cost',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text('$power • $usage', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(
          cost,
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildSmartTip(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _showApplianceDialog(BuildContext context, {Appliance? appliance}) {
    final nameController = TextEditingController(text: appliance?.name ?? '');
    final wattsController = TextEditingController(text: appliance?.wattage.toString() ?? '');
    final hoursController = TextEditingController(text: appliance?.hoursPerDay.toString() ?? '');
    bool isSmartConnecting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: UrjaTheme.cardBackground,
              title: Text(appliance == null ? 'Add Appliance' : 'Edit Appliance', style: const TextStyle(color: UrjaTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: UrjaTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wattsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: UrjaTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Wattage (W)',
                            labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Smart Plug Button
                      IconButton(
                        icon: isSmartConnecting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.wifi, color: UrjaTheme.primaryGreen),
                        tooltip: 'Connect Smart Device',
                        onPressed: isSmartConnecting ? null : () async {
                          setState(() => isSmartConnecting = true);
                          try {
                            final watts = await _energyService.connectSmartDevice(nameController.text);
                            wattsController.text = watts.toStringAsFixed(0);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected! Live Wattage: ${watts.toInt()}W')));
                            }
                          } finally {
                            if (context.mounted) setState(() => isSmartConnecting = false);
                          }
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: UrjaTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Hours per Day',
                      labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
                    ),
                  ),
                ],
              ),
              actions: [
                if (appliance != null)
                  TextButton(
                    onPressed: () {
                      _deleteAppliance(appliance.id);
                      Navigator.pop(context);
                    },
                    child: const Text('Delete', style: TextStyle(color: UrjaTheme.errorRed)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: UrjaTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text;
                    final watts = double.tryParse(wattsController.text);
                    final hours = double.tryParse(hoursController.text);

                    if (name.isNotEmpty && watts != null && hours != null) {
                      if (appliance == null) {
                        // Create new appliance object
                        final newApp = Appliance(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          wattage: watts,
                          hoursPerDay: hours,
                        );

                        try {
                          await _energyService.addAppliance(newApp);
                          if (!context.mounted) return;
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Appliance added & Dashboard updated!'),
                              backgroundColor: UrjaTheme.primaryGreen,
                            ),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: UrjaTheme.errorRed),
                            );
                          }
                        }
                      } else {
                        final updatedApp = Appliance(
                          id: appliance.id,
                          name: name,
                          wattage: watts,
                          hoursPerDay: hours,
                        );
                        _editAppliance(updatedApp);
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: UrjaTheme.primaryGreen),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

}
