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

    final userDocRef = _firestore.collection('users').doc(user.uid);

    Map<String, dynamic> lastLiveData = {};
    List<Appliance> lastAppliances = [];
    List<QueryDocumentSnapshot> lastLogs = [];
    String? userState;

    void emitUpdate() {
      if (controller.isClosed) return;

      double dailyKwhSum = 0;
      for (var app in lastAppliances) {
        dailyKwhSum += (app.wattage * app.hoursPerDay) / 1000;
      }

      final todayDate = _getTodayDateId();
      final lastResetDate = lastLiveData['last_reset_date'] as String?;

      // Auto-reset on new day
      if (lastResetDate != null && lastResetDate != todayDate) {
        dailyKwhSum = 0;
        _resetDailyUsageInFirestore(user.uid, todayDate);
      }

      // Manual reset override: if user manually reset today,
      // use stored daily_usage (0) instead of recalculating from appliances
      final manualResetDate = lastLiveData['manual_reset_date'] as String?;
      if (manualResetDate == todayDate) {
        final storedDailyUsage = (lastLiveData['daily_usage'] as num?)?.toDouble() ?? 0.0;
        dailyKwhSum = storedDailyUsage;
      }

      final projectedMonthlyKwh = dailyKwhSum * 30;

      final updatedLiveData = Map<String, dynamic>.from(lastLiveData);
      updatedLiveData['current_kwh'] = projectedMonthlyKwh;
      updatedLiveData['daily_usage'] = dailyKwhSum;

      DateTime now = DateTime.now();
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

        if (date.isAfter(startOfQuery.subtract(const Duration(seconds: 1))) &&
            date.isBefore(endOfQuery)) {
          int dayIndex = date.weekday - 1;
          if (dayIndex >= 0 && dayIndex < 7) {
            weeklyTrend[dayIndex] = kwh;
          }
        }

        if (date.year == now.year) {
          int monthIndex = date.month - 1;
          if (monthIndex >= 0 && monthIndex < 12) {
            monthlyTrend[monthIndex] += kwh;
          }
        }

        int yearDiff = date.year - (currentYear - 4);
        if (yearDiff >= 0 && yearDiff < 5) {
          yearlyTrend[yearDiff] += kwh;
        }
      }

      int todayIndex = now.weekday - 1;
      if (todayIndex >= 0 && todayIndex < 7) {
        weeklyTrend[todayIndex] = dailyKwhSum;
      }

      controller.add(EnergyData.fromMap(updatedLiveData).copyWith(
        weeklyTrend: weeklyTrend,
        monthlyTrend: monthlyTrend,
        yearlyTrend: yearlyTrend,
        appliances: lastAppliances,
        state: userState,
      ));
    }

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

    final s4 = userDocRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        userState = snapshot.data()?['state'] as String?;
        emitUpdate();
      }
    });

    controller.onCancel = () {
      s1.cancel();
      s2.cancel();
      s3.cancel();
      s4.cancel();
    };

    return controller.stream;
  }

  String _getTodayDateId() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _resetDailyUsageInFirestore(String uid, String todayDate) async {
    final liveDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('energy_data')
        .doc('live');

    await liveDocRef.set({
      'daily_usage': 0,
      'last_reset_date': todayDate,
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureDailyReset(String uid) async {
    final liveDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('energy_data')
        .doc('live');

    final snapshot = await liveDocRef.get();
    final data = snapshot.data();
    final lastResetDate = data?['last_reset_date'] as String?;
    final todayDate = _getTodayDateId();

    if (lastResetDate != todayDate) {
      await _resetDailyUsageInFirestore(uid, todayDate);
    }
  }

  // ── NEW: Manual reset of today's usage ──────────────────────────────────
  Future<void> resetTodayUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final todayDate = _getTodayDateId();
    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDate);

    await _firestore.runTransaction((transaction) async {
      // Reset today's log to 0
      transaction.set(dailyLogRef, {
        'date': Timestamp.fromDate(DateTime.now()),
        'kwh': 0.0,
      });

      // Reset live daily_usage and set manual_reset_date flag
      // manual_reset_date prevents stream from recalculating from appliances
      transaction.set(liveDocRef, {
        'daily_usage': 0.0,
        'last_reset_date': todayDate,
        'manual_reset_date': todayDate,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Legacy Stream
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

  Future<void> addAppliance(Appliance app) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(app.id)
        .set(app.toMap());

    final dailyKwh = (app.wattage * app.hoursPerDay) / 1000;

    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _ensureDailyReset(user.uid);

    await _firestore.runTransaction((transaction) async {
      final liveSnapshot = await transaction.get(liveDocRef);
      final dailyLogSnapshot = await transaction.get(dailyLogRef);

      if (!dailyLogSnapshot.exists) {
        transaction.set(dailyLogRef, {
          'date': Timestamp.fromDate(DateTime.now()),
          'kwh': dailyKwh,
        });
      } else {
        transaction.update(dailyLogRef, {
          'kwh': FieldValue.increment(dailyKwh),
        });
      }

      if (!liveSnapshot.exists) {
        transaction.set(liveDocRef, {
          'current_kwh': dailyKwh,
          'daily_usage': dailyKwh,
          'budget_limit': 250.0,
          'status': 'Online',
          'last_reset_date': _getTodayDateId(),
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

  Future<void> updateAppliance(Appliance app) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

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

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(app.id)
        .update(app.toMap());

    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _ensureDailyReset(user.uid);

    await _firestore.runTransaction((transaction) async {
      final dailyLogSnapshot = await transaction.get(dailyLogRef);
      if (dailyLogSnapshot.exists) {
        transaction.update(dailyLogRef, {'kwh': FieldValue.increment(diffKwh)});
      } else {
        transaction.set(dailyLogRef, {
          'date': Timestamp.fromDate(DateTime.now()),
          'kwh': diffKwh > 0 ? diffKwh : 0,
        });
      }

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

  Future<void> deleteAppliance(String applianceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

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

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(applianceId)
        .delete();

    final liveDocRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live');

    final todayDateId = _getTodayDateId();
    final dailyLogRef = liveDocRef.collection('daily_logs').doc(todayDateId);

    await _ensureDailyReset(user.uid);

    await _firestore.runTransaction((transaction) async {
      final dailyLogSnapshot = await transaction.get(dailyLogRef);
      if (dailyLogSnapshot.exists) {
        transaction.update(dailyLogRef, {'kwh': FieldValue.increment(-dailyKwh)});
      }

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

  Future<double> connectSmartDevice(String deviceName) async {
    await Future.delayed(const Duration(seconds: 2));
    return (50 + (DateTime.now().millisecond % 1950)).toDouble();
  }

  // Reset current month logs
  Future<void> resetCurrentMonthTrend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final logsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .collection('daily_logs');

    final snapshot = await logsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Reset ALL historical trend logs
  Future<void> resetAllTrendData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final logsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('energy_data')
        .doc('live')
        .collection('daily_logs');

    const batchSize = 400;
    while (true) {
      final snapshot = await logsRef.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}