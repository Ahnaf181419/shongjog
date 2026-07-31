import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// SharedPreferences key mirroring whether this device holds the admin role.
  static const prefIsAdminDevice = 'pref_is_admin_device';

  bool _isAdminDevice = false;

  /// Whether this device currently claims admin, as far as the client knows.
  ///
  /// This is a *routing* signal, not a security boundary — it decides which
  /// Firestore query a service subscribes to, because a non-admin device must
  /// not issue a query the rules will reject wholesale. The actual gate is
  /// `isAdmin()` in firestore.rules; lying about this locally gets a
  /// permission-denied from the server, not data.
  bool get isAdminDevice => _isAdminDevice;

  /// Restore [isAdminDevice] across launches. Called once from `main()`.
  Future<void> loadAdminFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAdminDevice = prefs.getBool(prefIsAdminDevice) ?? false;
    } catch (e) {
      debugPrint('FirebaseAuthService: loadAdminFlag failed: $e');
    }
  }

  Future<void> _setAdminFlag(bool value) async {
    _isAdminDevice = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefIsAdminDevice, value);
    } catch (e) {
      debugPrint('FirebaseAuthService: persisting admin flag failed: $e');
    }
  }

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
      await _setAdminFlag(true);
      await _firestore
          .collection('users')
          .doc(id)
          .set({'role': 'admin'}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseAuthService: claimAdminRole failed: $e');
    }
  }

  /// Drop this device's admin role. Called when the admin signs out.
  ///
  /// Without this, logging out was purely cosmetic: it navigated away from
  /// the panel while `role: 'admin'` stayed on the device's `users/{uid}`
  /// doc forever, so the device kept its ability to create broadcasts and
  /// approve campaigns — for the life of the install, to whoever picked the
  /// phone up next. Never throws, for the same offline reason as
  /// [claimAdminRole].
  Future<void> releaseAdminRole() async {
    try {
      final id = uid;
      if (id == null) return;
      await _setAdminFlag(false);
      await _firestore
          .collection('users')
          .doc(id)
          .set({'role': 'user'}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseAuthService: releaseAdminRole failed: $e');
    }
  }
}

/// The identity every safety report and campaign is attributed to.
///
/// Prefers the Firebase auth uid, because that is the ONLY id a security rule
/// can verify: `firestore.rules` requires `userId == request.auth.uid`, which
/// is what stops a device from filing a report in someone else's name. The
/// same value goes out over the mesh, so a report arriving by Bluetooth and
/// by Firestore dedupes to one person instead of two.
///
/// **This also fixes a silent data bug.** The previous fallback was
/// `'u-${DateTime.now().millisecondsSinceEpoch}'`, and nothing ever wrote
/// `user_id` to preferences — so the fallback fired on *every* press and each
/// report carried a brand-new id. `SafetyStatusService.ingest()` dedupes on
/// `userId`, so it never deduped anything: one person tapping SAFE three
/// times became three people in the admin's totals.
///
/// The local fallback (no Firebase, offline first run) is now generated once
/// and persisted, so it is at least stable per install.
Future<String> stableUserId(SharedPreferences prefs) async {
  try {
    final id = firebaseAuthService.uid;
    if (id != null) return id;
  } catch (_) {
    // No Firebase app yet — fall through to the local id.
  }
  final cached = prefs.getString('user_id');
  if (cached != null && cached.isNotEmpty) return cached;
  final generated = 'u-${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString('user_id', generated);
  return generated;
}

/// Stamp the calling device's auth uid onto a document about to be written
/// to Firestore.
///
/// `SafetyReport.userId` and `CampaignRequest.userId` are a *local* id read
/// from SharedPreferences (`user_id`) — they travel over the mesh, they are
/// freely chosen, and they have no relationship to Firebase auth. Security
/// rules therefore cannot trust them for ownership. `ownerUid` is the one
/// field a rule can verify against `request.auth.uid`, which is what stops
/// any signed-in device from creating a report in someone else's name or
/// rewriting theirs.
///
/// Applied at the Firestore write site rather than inside `toJson()` on
/// purpose: `toJson()` is also the mesh wire format and the on-disk cache
/// format, and the uid belongs in neither.
Map<String, dynamic> withOwnerUid(Map<String, dynamic> json,
    {FirebaseAuthService? auth}) {
  try {
    // `uid` reaches FirebaseAuth.instance, which throws SYNCHRONOUSLY when
    // no Firebase app has been initialized (offline first boot, or a unit
    // test with no Firebase at all). Returning the map untouched is correct
    // there: with no auth there is no Firestore write to authorize either.
    final id = (auth ?? firebaseAuthService).uid;
    if (id == null) return json;
    return {...json, 'ownerUid': id};
  } catch (_) {
    return json;
  }
}

/// App-wide singleton — one per app instance.
final FirebaseAuthService firebaseAuthService = FirebaseAuthService();
