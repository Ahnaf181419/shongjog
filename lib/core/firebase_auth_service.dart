import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Anonymous-auth identity for the Firestore-backed admin panel.
///
/// No SMS/OTP, no SHA-1 registration — every device gets a stable Firestore
/// uid for free via [FirebaseAuth.signInAnonymously]. "Admin" is a role the
/// device claims on its own `users/{uid}` doc after passing the existing
/// hardcoded PIN gate in `admin_login_screen.dart`; this is a client-asserted,
/// non-cryptographic gate — acceptable for hackathon demo scope (documented
/// in `firestore.rules`), tightenable post-hackathon with a real backend
/// check (e.g. a Cloud Function that verifies an invite code).
///
/// Not a [ChangeNotifier] — nothing in the UI reacts to auth-state changes;
/// callers just await [ensureSignedIn] / [claimAdminRole].
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _injectedAuth = auth,
        _injectedFirestore = firestore;

  // Stored as nullable and resolved lazily via the getters below — NOT
  // eagerly in the constructor. This service is a top-level global
  // singleton (see bottom of file), so its constructor runs at library
  // load time, before `Firebase.initializeApp()` has executed in
  // `main()`. `FirebaseAuth.instance`/`FirebaseFirestore.instance` both
  // call `Firebase.app()` internally, which throws synchronously if no
  // app has been initialized yet — eagerly evaluating either in the
  // constructor would crash app boot before Firebase even gets a chance
  // to initialize.
  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;

  /// Sign in anonymously if this device hasn't already. Swallows all
  /// failures (e.g. no network on first launch, Firebase project
  /// unreachable) — the app must still boot and work fully offline.
  Future<void> ensureSignedIn() async {
    try {
      if (_auth.currentUser != null) return;
      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('FirebaseAuthService: ensureSignedIn failed: $e');
    }
  }

  /// Mark this device's anonymous uid as an admin in Firestore. Called from
  /// the admin login screen after the local PIN check succeeds. Never
  /// throws — if this device is offline, Firestore's own write cache queues
  /// the doc and syncs it once back online; local login proceeds regardless.
  Future<void> claimAdminRole() async {
    try {
      final id = uid;
      if (id == null) return;
      await _firestore
          .collection('users')
          .doc(id)
          .set({'role': 'admin'}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseAuthService: claimAdminRole failed: $e');
    }
  }
}

/// App-wide singleton — one per app instance.
final FirebaseAuthService firebaseAuthService = FirebaseAuthService();
