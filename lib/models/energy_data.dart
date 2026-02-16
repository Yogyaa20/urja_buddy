import 'appliance.dart';

class EnergyData {
  final double todayKWh;
  final double currentKWh;
  final double budgetLimit;
  final String status;
  final List<double> monthlyTrend;
  final List<double> yearlyTrend;
  final List<double> weeklyTrend;
  final List<Appliance> appliances; // Add appliances list

  const EnergyData({
    required this.todayKWh,
    required this.currentKWh,
    required this.budgetLimit,
    required this.status,
    required this.monthlyTrend,
    required this.yearlyTrend,
    required this.weeklyTrend,
    this.appliances = const [], // Default empty
  });

  factory EnergyData.fromMap(Map<String, dynamic> map, {List<Appliance> appliances = const []}) {
    return EnergyData(
      todayKWh: (map['daily_usage'] as num?)?.toDouble() ?? 0.0,
      currentKWh: (map['current_kwh'] as num?)?.toDouble() ?? 0.0,
      budgetLimit: (map['budget_limit'] as num?)?.toDouble() ?? 250.0,
      status: map['status'] as String? ?? 'Online',
      monthlyTrend: (map['monthly_trend'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      yearlyTrend: (map['yearly_trend'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      weeklyTrend: (map['weekly_trend'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      appliances: appliances,
    );
  }

  factory EnergyData.initial() {
    return const EnergyData(
      todayKWh: 0.0,
      currentKWh: 0.0,
      budgetLimit: 250.0,
      status: 'Offline',
      monthlyTrend: [],
      yearlyTrend: [],
      weeklyTrend: [],
      appliances: [],
    );
  }

  double get usagePercent => (currentKWh / budgetLimit).clamp(0.0, 1.0);
  
  // Carbon footprint estimation (approx 0.85 kg CO2 per kWh - India avg)
  double get carbonFootprint => currentKWh * 0.85;

  EnergyData copyWith({
    double? todayKWh,
    double? currentKWh,
    double? budgetLimit,
    String? status,
    List<double>? monthlyTrend,
    List<double>? yearlyTrend,
    List<double>? weeklyTrend,
    List<Appliance>? appliances,
  }) {
    return EnergyData(
      todayKWh: todayKWh ?? this.todayKWh,
      currentKWh: currentKWh ?? this.currentKWh,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      status: status ?? this.status,
      monthlyTrend: monthlyTrend ?? this.monthlyTrend,
      yearlyTrend: yearlyTrend ?? this.yearlyTrend,
      weeklyTrend: weeklyTrend ?? this.weeklyTrend,
      appliances: appliances ?? this.appliances,
    );
  }
}
