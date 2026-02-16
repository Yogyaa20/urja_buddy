import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  Future<void> init() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
  }

  Stream<User?> authState() => FirebaseAuth.instance.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return FirebaseAuth.instance.signOut();
  }

  Future<void> saveProfile(String uid, Map<String, dynamic> profile) {
    return FirebaseFirestore.instance.collection('profiles').doc(uid).set(profile, SetOptions(merge: true));
  }

  Future<void> sendUsageAlert(String uid, String message) {
    return FirebaseFirestore.instance.collection('alerts').add({
      'uid': uid,
      'message': message,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }
}
