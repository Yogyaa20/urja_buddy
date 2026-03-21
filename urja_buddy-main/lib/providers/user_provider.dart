import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// User State Model
class UserState {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? familyName;
  final String? unitNumber;

  UserState({
    this.uid,
    this.email,
    this.displayName,
    this.familyName,
    this.unitNumber,
  });

  // Factory to create from Firebase User + Firestore Data
  factory UserState.fromFirebase(User? user, Map<String, dynamic>? data) {
    if (user == null) return UserState();
    return UserState(
      uid: user.uid,
      email: user.email,
      displayName: data?['fullName'] ?? user.displayName ?? 'Urja User',
      familyName: data?['familyName'],
      unitNumber: data?['unitNumber'] ?? '',
    );
  }
  
  // Helper to copy state
  UserState copyWith({
    String? displayName,
    String? familyName,
    String? unitNumber,
  }) {
    return UserState(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      familyName: familyName ?? this.familyName,
      unitNumber: unitNumber ?? this.unitNumber,
    );
  }
}

// Notifier (Riverpod 3.x compatible)
class UserNotifier extends AsyncNotifier<UserState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserState> build() async {
    return _loadUser();
  }

  Future<UserState> _loadUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return UserState();
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    
    return UserState.fromFirebase(user, data);
  }

  Future<void> updateName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update Firestore
    await _firestore.collection('users').doc(user.uid).update({'fullName': newName});
    
    // Update Firebase Auth Display Name
    await user.updateDisplayName(newName);

    // Update Local State
    state.whenData((currentData) {
      state = AsyncValue.data(currentData.copyWith(displayName: newName));
    });
  }
}

// Provider (Riverpod 3.x compatible)
final userProvider = AsyncNotifierProvider<UserNotifier, UserState>(UserNotifier.new);
