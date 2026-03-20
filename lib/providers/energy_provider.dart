import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/energy_data.dart';
import '../services/energy_service.dart';

final energyProvider = StreamProvider.autoDispose<EnergyData>((ref) {
  return EnergyService().energyDataStream;
});
