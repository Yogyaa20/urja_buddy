import 'dart:math';

class Slab {
  final double limit; // Upper limit of the overall units. So up to `limit` total units. (e.g., 200). Use double.infinity for the last slab.
  final double rate;

  const Slab(this.limit, this.rate);
}

class TariffPlan {
  final List<Slab> slabs;
  final double taxPercentage;
  final double fixedCharges;

  const TariffPlan({
    required this.slabs,
    required this.taxPercentage,
    this.fixedCharges = 50.0, // Base default fixed charge
  });
}

class SlabBreakdown {
  final double units;
  final double rate;
  final double amount;

  SlabBreakdown(this.units, this.rate, this.amount);
}

class BillDetails {
  final double totalUnits;
  final double subtotal;
  final double taxPercent;
  final double taxAmount;
  final double fixedCharges;
  final double totalPayable;
  final List<SlabBreakdown> slabs;
  final double freeUnitsDeducted;

  BillDetails({
    required this.totalUnits,
    required this.subtotal,
    required this.taxPercent,
    required this.taxAmount,
    required this.fixedCharges,
    required this.totalPayable,
    required this.slabs,
    required this.freeUnitsDeducted,
  });
}

class TariffService {
  // All 36 States/UTs with their specified taxes (0 to 16%) 
  // and slab representations bridging the given min and max rates.
  static final Map<String, TariffPlan> _stateTariffs = {
    'Andhra Pradesh': const TariffPlan(taxPercentage: 5, slabs: [Slab(50, 0.0), Slab(100, 1.45), Slab(300, 3.60), Slab(double.infinity, 9.50)]),
    'Arunachal Pradesh': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 2.50), Slab(300, 3.50), Slab(double.infinity, 4.50)]),
    'Assam': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 4.50), Slab(300, 6.00), Slab(double.infinity, 7.50)]),
    'Bihar': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.40), Slab(300, 5.00), Slab(double.infinity, 6.30)]),
    'Chhattisgarh': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.00), Slab(300, 4.50), Slab(double.infinity, 5.50)]),
    'Goa': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 0.0), Slab(300, 1.30), Slab(double.infinity, 4.50)]),
    'Gujarat': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 3.40), Slab(300, 4.50), Slab(double.infinity, 6.00)]),
    'Haryana': const TariffPlan(taxPercentage: 10, slabs: [Slab(200, 0.0), Slab(400, 3.00), Slab(double.infinity, 6.00)]),
    'Himachal Pradesh': const TariffPlan(taxPercentage: 6, slabs: [Slab(125, 0.0), Slab(300, 1.50), Slab(double.infinity, 4.65)]),
    'Jharkhand': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.25), Slab(300, 4.50), Slab(double.infinity, 5.75)]),
    'Karnataka': const TariffPlan(taxPercentage: 6, slabs: [Slab(200, 0.0), Slab(400, 3.75), Slab(double.infinity, 7.25)]),
    'Kerala': const TariffPlan(taxPercentage: 10, slabs: [Slab(100, 2.90), Slab(300, 5.00), Slab(double.infinity, 7.90)]),
    'Madhya Pradesh': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.50), Slab(300, 5.00), Slab(double.infinity, 6.50)]),
    'Maharashtra': const TariffPlan(taxPercentage: 16, slabs: [Slab(100, 4.43), Slab(300, 8.00), Slab(double.infinity, 12.83)]),
    'Manipur': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.50), Slab(300, 4.50), Slab(double.infinity, 5.50)]),
    'Meghalaya': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 4.00), Slab(300, 5.00), Slab(double.infinity, 6.50)]),
    'Mizoram': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.50), Slab(300, 4.50), Slab(double.infinity, 6.00)]),
    'Nagaland': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 4.00), Slab(300, 5.00), Slab(double.infinity, 6.50)]),
    'Odisha': const TariffPlan(taxPercentage: 5, slabs: [Slab(50, 0.0), Slab(200, 2.50), Slab(double.infinity, 5.50)]),
    'Punjab': const TariffPlan(taxPercentage: 10, slabs: [Slab(300, 0.0), Slab(500, 3.78), Slab(double.infinity, 7.50)]),
    'Rajasthan': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.40), Slab(300, 5.00), Slab(double.infinity, 6.30)]),
    'Sikkim': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 2.50), Slab(300, 3.50), Slab(double.infinity, 4.50)]),
    'Tamil Nadu': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 0.0), Slab(200, 1.50), Slab(double.infinity, 4.95)]),
    'Telangana': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 0.0), Slab(300, 1.45), Slab(double.infinity, 9.50)]),
    'Tripura': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.00), Slab(300, 4.50), Slab(double.infinity, 5.50)]),
    'Uttar Pradesh': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 3.35), Slab(300, 5.50), Slab(double.infinity, 8.00)]),
    'Uttarakhand': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 2.70), Slab(300, 4.50), Slab(double.infinity, 5.70)]),
    'West Bengal': const TariffPlan(taxPercentage: 5, slabs: [Slab(75, 0.0), Slab(300, 5.00), Slab(double.infinity, 8.50)]),
    'Andaman & Nicobar Islands': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 3.00), Slab(300, 4.00), Slab(double.infinity, 5.00)]),
    'Chandigarh': const TariffPlan(taxPercentage: 5, slabs: [Slab(100, 2.50), Slab(300, 4.00), Slab(double.infinity, 6.00)]),
    'Dadra & Nagar Haveli and Daman & Diu': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 2.00), Slab(300, 3.00), Slab(double.infinity, 4.00)]),
    'Delhi': const TariffPlan(taxPercentage: 5, slabs: [Slab(200, 3.00), Slab(400, 5.00), Slab(800, 6.50), Slab(1200, 7.00), Slab(double.infinity, 8.00)]),
    'Jammu & Kashmir': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 1.50), Slab(300, 3.00), Slab(double.infinity, 4.50)]),
    'Ladakh': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 1.50), Slab(300, 2.50), Slab(double.infinity, 3.50)]),
    'Lakshadweep': const TariffPlan(taxPercentage: 0, slabs: [Slab(100, 2.00), Slab(300, 2.50), Slab(double.infinity, 3.50)]),
    'Puducherry': const TariffPlan(taxPercentage: 0, slabs: [Slab(40, 0.0), Slab(100, 1.50), Slab(300, 3.00), Slab(double.infinity, 4.50)]),
  };

  static TariffPlan _getPlanForState(String? stateName) {
    if (stateName == null || stateName.isEmpty || !_stateTariffs.containsKey(stateName)) {
      // Default fallback (e.g., Delhi) if state is not found or null
      return _stateTariffs['Delhi']!;
    }
    return _stateTariffs[stateName]!;
  }

  static BillDetails calculateBill(String? stateName, double consumedUnits) {
    final plan = _getPlanForState(stateName);
    
    double pendingUnits = consumedUnits;
    double subtotal = 0.0;
    double freeUnitsDeducted = 0.0;
    List<SlabBreakdown> breakdowns = [];
    
    double previousLimit = 0.0;

    for (var slab in plan.slabs) {
      if (pendingUnits <= 0) break;

      double slabSize = slab.limit - previousLimit;
      double unitsInThisSlab = min(pendingUnits, slabSize);
      
      double amount = unitsInThisSlab * slab.rate;
      
      if (slab.rate == 0.0) {
        freeUnitsDeducted += unitsInThisSlab;
      }
      
      if (unitsInThisSlab > 0) {
        breakdowns.add(SlabBreakdown(unitsInThisSlab, slab.rate, amount));
      }

      subtotal += amount;
      pendingUnits -= unitsInThisSlab;
      previousLimit = slab.limit;
      
      if (pendingUnits <= 0) break;
    }

    final double fixedCharges = plan.fixedCharges;
    final double taxableAmount = subtotal + fixedCharges;
    final double taxAmount = taxableAmount * (plan.taxPercentage / 100);
    final double totalPayable = taxableAmount + taxAmount;

    return BillDetails(
      totalUnits: consumedUnits,
      subtotal: subtotal,
      taxPercent: plan.taxPercentage,
      taxAmount: taxAmount,
      fixedCharges: fixedCharges,
      totalPayable: totalPayable,
      slabs: breakdowns,
      freeUnitsDeducted: freeUnitsDeducted,
    );
  }
}
