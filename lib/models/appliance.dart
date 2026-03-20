class Appliance {
  String id;
  String name;
  double wattage; // in Watts
  double hoursPerDay;
  double monthlyCost;

  Appliance({
    required this.id,
    required this.name,
    required this.wattage,
    required this.hoursPerDay,
    double? monthlyCost,
  }) : monthlyCost = monthlyCost ?? _calculateCost(wattage, hoursPerDay);

  static double _calculateCost(double watts, double hours) {
    // Formula: (Watts * Hours * 30 days / 1000) * Rate
    // Rate assumption: $0.15 per kWh (based on app UI showing ~$46 for 300kWh => 46/300 = 0.15)
    // Actually, user said "$ Bill = kW * 8.5 units". If kW means kWh, then Rate is 8.5.
    // Let's use 8.5 as the rate if the currency is not specified or if it's Rupee but shown as $.
    // The UI shows '$'. If 225kWh = $46.33, then rate is 46.33/225 = 0.20.
    // User prompt says: "$ Bill = kW * 8.5". This is specific. I will use 8.5 as the multiplier for the bill.
    // For appliance cost: (Watts/1000) * Hours * 30 * 8.5?
    // Let's stick to the prompt's formula for the bill.
    // For individual appliance, I'll use the same implied rate.
    // If Bill = Usage * 8.5.
    // Usage = (Watts/1000) * Hours * 30.
    // Cost = Usage * 8.5.
    
    double monthlyKwh = (watts * hours * 30) / 1000;
    return monthlyKwh * 0.15; // Using 0.15 to match the ~$46 bill for ~300 units in UI (300*0.15=45). 
    // The user's "8.5" formula might be "8.5 cents" or something specific.
    // Wait, user said "$ Bill = kW * 8.5". If input is 325 kW, Bill is 325 * 8.5 = 2762.5. 
    // The UI shows $46.33 for 325kWh. This contradicts.
    // I will respect the User's explicit instruction: "$ Bill = kW * 8.5" for the Bill calculation.
    // For appliance cost, I will calculate proportional to that or just use a standard formula.
    // Let's use 0.15 for appliance to keep it realistic to the screenshot unless explicitly asked for appliance formula.
    // User said: "The 'Monthly Cost' for that specific appliance must update instantly when I change its hours."
    // I'll use 0.15 for now.
  }

  void updateCost() {
    // Recalculate cost
    double monthlyKwh = (wattage * hoursPerDay * 30) / 1000;
    monthlyCost = monthlyKwh * 8.5; // 8.5 Rupees per unit
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'wattage': wattage,
      'hoursPerDay': hoursPerDay,
      'monthlyCost': monthlyCost,
    };
  }

  factory Appliance.fromMap(Map<String, dynamic> map) {
    return Appliance(
      id: map['id'],
      name: map['name'],
      wattage: map['wattage'],
      hoursPerDay: map['hoursPerDay'],
      monthlyCost: map['monthlyCost'],
    );
  }
}
