import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      // debugPrint('Attempting login for: $email with password length: ${password.length}');
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // debugPrint('AuthService SignIn Error: $e');
      rethrow;
    }
  }

  // Register with email, password, and additional details
  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String unitNumber,
    String? address, // Optional, can be same as unitNumber or separate
  }) async {
    try {
      // Create user in Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user doc in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'unitNumber': unitNumber,
        'address': address ?? unitNumber, // Save address if provided, else default to unitNumber
        'createdAt': FieldValue.serverTimestamp(),
        'uid': result.user!.uid,
      });

      // Initialize energy_data for Dashboard
      await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .collection('energy_data')
          .doc('live')
          .set({
        'current_kwh': 0.0,
        'daily_usage': 0.0,
        'status': 'Normal',
        'address': address ?? 'F-101 Green Valley',
        'name': fullName,
        'last_updated': FieldValue.serverTimestamp(),
      });

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user details
  Future<DocumentSnapshot> getUserDetails() async {
    if (_auth.currentUser != null) {
      return await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    }
    throw Exception('No user logged in');
  }
}
