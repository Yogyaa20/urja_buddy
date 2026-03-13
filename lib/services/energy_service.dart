import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/energy_data.dart';
import '../models/appliance.dart';

class EnergyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream for live usage updates (returns EnergyData model)
  Stream<EnergyData> get energyDataStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(EnergyData.initial());
    }

    // Use a StreamController to merge multiple streams manually
    // This allows us to react to ANY change in Live, Logs, OR Appliances
    final controller = StreamController<EnergyData>();

    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final dailyLogsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .collection('daily_logs');
        
    final appliancesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances');

    // Helper variables to store latest state
    Map<String, dynamic> lastLiveData = {};
    List<Appliance> lastAppliances = [];
    List<QueryDocumentSnapshot> lastLogs = [];

    // Calculation Logic
    void emitUpdate() {
      if (controller.isClosed) return;

      // 1. Calculate Projected Usage from Appliances (Daily Sum)
      double dailyKwhSum = 0;
      for (var app in lastAppliances) {
        dailyKwhSum += (app.wattage * app.hoursPerDay) / 1000;
      }
      
      // Calculate Projected Monthly based on daily sum
      final projectedMonthlyKwh = dailyKwhSum * 30;
      
      // Update Live Data
      // 'current_kwh' -> Monthly Projected (for Bill)
      // 'daily_usage' -> Daily Sum (for Today's Usage)
      final updatedLiveData = Map<String, dynamic>.from(lastLiveData);
      updatedLiveData['current_kwh'] = projectedMonthlyKwh;
      updatedLiveData['daily_usage'] = dailyKwhSum;
      
      // 2. Process Trends
      DateTime now = DateTime.now();
      
      // Weekly (Mon-Sun)
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime startOfQuery = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 7));
      DateTime endOfQuery = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
      
      List<double> weeklyTrend = List.filled(7, 0.0);
      List<double> monthlyTrend = List.filled(12, 0.0);
      List<double> yearlyTrend = List.filled(5, 0.0);
      
      final currentYear = now.year;

      for (var doc in lastLogs) {
         final data = doc.data() as Map<String, dynamic>;
         final timestamp = data['date'] as Timestamp;
         final date = timestamp.toDate();
         final kwh = (data['kwh'] as num?)?.toDouble() ?? 0.0;
         
         // A. Weekly
         if (date.isAfter(startOfQuery.subtract(const Duration(seconds: 1))) && 
             date.isBefore(endOfQuery)) {
            int dayIndex = date.weekday - 1; 
            if (dayIndex >= 0 && dayIndex < 7) {
               weeklyTrend[dayIndex] = kwh;
            }
         }

         // B. Monthly
         if (date.year == now.year) {
           int monthIndex = date.month - 1;
           if (monthIndex >= 0 && monthIndex < 12) {
             monthlyTrend[monthIndex] += kwh;
           }
         }
         
         // C. Yearly
         int yearDiff = date.year - (currentYear - 4);
         if (yearDiff >= 0 && yearDiff < 5) {
           yearlyTrend[yearDiff] += kwh;
         }
      }

      // Override Today's Trend with Real-time Calculation to ensure sync
      int todayIndex = now.weekday - 1;
      if (todayIndex >= 0 && todayIndex < 7) {
        weeklyTrend[todayIndex] = dailyKwhSum;
      }
      
      // Also update current month accumulation with projection/current if needed?
      // For now, let's keep monthly/yearly based on logs + today's override if logical.
      // But Weekly is the primary "Real-time" view user checks.

      controller.add(EnergyData.fromMap(updatedLiveData).copyWith(
        weeklyTrend: weeklyTrend,
        monthlyTrend: monthlyTrend,
        yearlyTrend: yearlyTrend,
        appliances: lastAppliances,
      ));
    }

    // Listeners
    final s1 = liveDocRef.snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        lastLiveData = snapshot.data() as Map<String, dynamic>;
      } else {
        lastLiveData = {};
      }
      emitUpdate();
    });

    final s2 = appliancesRef.snapshots().listen((snapshot) {
      lastAppliances = snapshot.docs.map((doc) => Appliance.fromMap(doc.data())).toList();
      emitUpdate();
    });

    // Helper for Yearly Query Bounds
    final startOfFiveYears = DateTime(DateTime.now().year - 4, 1, 1);
    final endOfFiveYears = DateTime(DateTime.now().year + 1, 1, 1);
    
    final s3 = dailyLogsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfFiveYears))
        .where('date', isLessThan: Timestamp.fromDate(endOfFiveYears))
        .orderBy('date')
        .snapshots()
        .listen((snapshot) {
      lastLogs = snapshot.docs;
      emitUpdate();
    });

    controller.onCancel = () {
      s1.cancel();
      s2.cancel();
      s3.cancel();
    };

    return controller.stream;
  }

  String _getTodayDateId() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Legacy Stream for specific widgets if needed (optional)
  Stream<Map<String, dynamic>> get liveUsageStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value({
        'current_kwh': 20.0,
        'daily_usage': 12.5,
        'status': 'Online',
      });
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        return {
          'current_kwh': (data['current_kwh'] as num?)?.toDouble() ?? 20.0,
          'daily_usage': (data['daily_usage'] as num?)?.toDouble() ?? 12.5,
          'status': data['status'] as String? ?? 'Online',
        };
      }
      return {
        'current_kwh': 20.0,
        'daily_usage': 12.5,
        'status': 'Online',
      };
    });
  }

  // Fetch Appliances (Future)
  Future<List<Appliance>> fetchAppliances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final appliancesSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .get();

    return appliancesSnapshot.docs
        .map((doc) => Appliance.fromMap(doc.data()))
        .toList();
  }

  // Add Appliance and Update Stats
  Future<void> addAppliance(Appliance app) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Save to sub-collection
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(app.id)
        .set(app.toMap());

    // 2. Calculate daily consumption in kWh
    final dailyKwh = (app.wattage * app.hoursPerDay) / 1000;

    // 3. Update global energy stats
    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _firestore.runTransaction((transaction) async {
      final liveSnapshot = await transaction.get(liveDocRef);
      final dailyLogSnapshot = await transaction.get(dailyLogRef);

      // A. Update Daily Log (The source of truth for the graph)
      if (!dailyLogSnapshot.exists) {
        transaction.set(dailyLogRef, {
          'date': Timestamp.fromDate(DateTime.now()), // Save actual date
          'kwh': dailyKwh,
        });
      } else {
        transaction.update(dailyLogRef, {
          'kwh': FieldValue.increment(dailyKwh),
        });
      }

      // B. Update Live Aggregate (for total cost/usage)
      if (!liveSnapshot.exists) {
        transaction.set(liveDocRef, {
          'current_kwh': dailyKwh,
          'daily_usage': dailyKwh,
          'budget_limit': 250.0,
          'status': 'Online',
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(liveDocRef, {
          'current_kwh': FieldValue.increment(dailyKwh),
          'daily_usage': FieldValue.increment(dailyKwh),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Update Appliance
  Future<void> updateAppliance(Appliance app) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Get Old Appliance Data to Calculate Difference
    final appDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(app.id)
        .get();

    if (!appDoc.exists) return;

    final oldData = appDoc.data()!;
    final oldWattage = (oldData['wattage'] as num).toDouble();
    final oldHours = (oldData['hoursPerDay'] as num).toDouble();
    final oldDailyKwh = (oldWattage * oldHours) / 1000;

    final newDailyKwh = (app.wattage * app.hoursPerDay) / 1000;
    final diffKwh = newDailyKwh - oldDailyKwh;

    // 2. Update Appliance Document
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(app.id)
        .update(app.toMap());

    // 3. Update Global Energy Stats (Live & Log)
    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _firestore.runTransaction((transaction) async {
      // A. Update Daily Log
      final dailyLogSnapshot = await transaction.get(dailyLogRef);
      if (dailyLogSnapshot.exists) {
        transaction.update(dailyLogRef, {
          'kwh': FieldValue.increment(diffKwh),
        });
      } else {
        // If no log for today, create one with the difference (unlikely but safe)
        transaction.set(dailyLogRef, {
          'date': Timestamp.fromDate(DateTime.now()),
          'kwh': diffKwh > 0 ? diffKwh : 0, 
        });
      }

      // B. Update Live Aggregate
      final liveSnapshot = await transaction.get(liveDocRef);
      if (liveSnapshot.exists) {
        transaction.update(liveDocRef, {
          'current_kwh': FieldValue.increment(diffKwh),
          'daily_usage': FieldValue.increment(diffKwh),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Delete Appliance
  Future<void> deleteAppliance(String applianceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Get the appliance to deduct its usage
    final appDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(applianceId)
        .get();

    if (!appDoc.exists) return;

    final appData = appDoc.data()!;
    final wattage = (appData['wattage'] as num).toDouble();
    final hours = (appData['hoursPerDay'] as num).toDouble();
    final dailyKwh = (wattage * hours) / 1000;

    // 2. Delete from sub-collection
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(applianceId)
        .delete();

    // 3. Update global energy stats (deduct usage)
    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _firestore.runTransaction((transaction) async {
      // A. Update Daily Log
      final dailyLogSnapshot = await transaction.get(dailyLogRef);
      if (dailyLogSnapshot.exists) {
        transaction.update(dailyLogRef, {
          'kwh': FieldValue.increment(-dailyKwh),
        });
      }

      // B. Update Live Aggregate
      final liveSnapshot = await transaction.get(liveDocRef);
      if (liveSnapshot.exists) {
        transaction.update(liveDocRef, {
          'current_kwh': FieldValue.increment(-dailyKwh),
          'daily_usage': FieldValue.increment(-dailyKwh),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Save manual meter reading
  Future<void> saveMeterReading({
    required double previousReading,
    required double currentReading,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    if (currentReading < previousReading) {
      throw Exception('Current reading cannot be lower than previous');
    }

    final usage = currentReading - previousReading;
    
    // Update the live doc
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .set({
      'current_kwh': usage,
      'previous_reading': previousReading,
      'current_reading': currentReading,
      'last_updated': FieldValue.serverTimestamp(),
      'source': 'manual_meter',
    }, SetOptions(merge: true));
  }

  // Update kWh from CSV Upload
  Future<void> updateKwhFromCsv(double totalKwh) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .set({
      'current_kwh': totalKwh,
      'last_updated': FieldValue.serverTimestamp(),
      'source': 'csv_upload',
    }, SetOptions(merge: true));
  }

  // Update Budget Limit
  Future<void> updateBudgetLimit(double newLimit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .set({
      'budget_limit': newLimit,
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Simulate Smart Plug Connection
  Future<double> connectSmartDevice(String deviceName) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return a random "live" wattage between 50W and 2000W
    // In a real app, this would connect to Tuya/Shelly API
    return (50 + (DateTime.now().millisecond % 1950)).toDouble();
  }
}
