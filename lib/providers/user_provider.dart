import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// User State Model
class UserState {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? unitNumber;

  UserState({
    this.uid,
    this.email,
    this.displayName,
    this.unitNumber,
  });

  // Factory to create from Firebase User + Firestore Data
  factory UserState.fromFirebase(User? user, Map<String, dynamic>? data) {
    if (user == null) return UserState();
    return UserState(
      uid: user.uid,
      email: user.email,
      displayName: data?['fullName'] ?? user.displayName ?? 'Urja User',
      unitNumber: data?['unitNumber'] ?? '',
    );
  }
  
  // Helper to copy state
  UserState copyWith({
    String? displayName,
    String? unitNumber,
  }) {
    return UserState(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      unitNumber: unitNumber ?? this.unitNumber,
    );
  }
}

// Notifier
class UserNotifier extends StateNotifier<AsyncValue<UserState>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserNotifier() : super(const AsyncValue.loading()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        state = AsyncValue.data(UserState());
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      state = AsyncValue.data(UserState.fromFirebase(user, data));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({'fullName': newName});
      
      // Update Firebase Auth Display Name (Optional but good practice)
      await user.updateDisplayName(newName);

      // Update Local State
      state.whenData((userData) {
        state = AsyncValue.data(userData.copyWith(displayName: newName));
      });
      
    } catch (e) {
      // Handle error (maybe rethrow for UI to catch)
      // debugPrint('Error updating name: $e');
      rethrow;
    }
  }
}

// Provider
final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<UserState>>((ref) {
  return UserNotifier();
});
