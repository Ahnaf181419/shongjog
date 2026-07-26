import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_auth_service.dart';

/// One device that has run Shongjog and signed in anonymously.
///
/// Written to `users/{uid}` by the device itself — the same doc the admin
/// role is claimed on, so a device's registration and its role live
/// together rather than in two collections that could drift apart.
class RegisteredDevice {
  final String uid;
  final String name;

  /// Last time this device wrote its heartbeat. Drives [isOnline].
  final DateTime? lastSeen;

  /// `'admin'` for a device that has passed the admin PIN gate, else null.
  final String? role;

  const RegisteredDevice({
    required this.uid,
    required this.name,
    this.lastSeen,
    this.role,
  });

  bool get isAdmin => role == 'admin';

  /// A device is "online" if its heartbeat is fresher than
  /// [DeviceRegistryService.onlineWindow]. Android suspends timers for a
  /// backgrounded isolate, so a phone that has been put away stops
  /// heartbeating and ages out on its own — no explicit sign-out needed.
  bool get isOnline {
    final seen = lastSeen;
    if (seen == null) return false;
    return DateTime.now().toUtc().difference(seen) <
        DeviceRegistryService.onlineWindow;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'lastSeen': lastSeen?.toIso8601String(),
        if (role != null) 'role': role,
      };

  static RegisteredDevice fromJson(String uid, Map<String, dynamic> m) =>
      RegisteredDevice(
        uid: m['uid'] as String? ?? uid,
        name: m['name'] as String? ?? '',
        lastSeen: DateTime.tryParse(m['lastSeen'] as String? ?? '')?.toUtc(),
        role: m['role'] as String?,
      );
}

/// Cross-device presence for the admin panel's Users page and stat row.
///
/// Before this existed, "Users" listed only [MeshService] peers — devices
/// within Bluetooth range of the admin's phone — and the dashboard's user
/// and offline-session counts were hardcoded literals. Neither told an
/// admin anything about the people actually running the app. This service
/// is the shared registry those two surfaces read instead.
///
/// Mesh is not replaced by this, it is complemented: mesh answers "who is
/// physically near me right now, with no network", this answers "who is
/// running the app at all". The Users page shows both.
class DeviceRegistryService extends ChangeNotifier {
  DeviceRegistryService({
    FirebaseFirestore? firestore,
    String? Function()? uidProvider,
  })  : _injectedFirestore = firestore,
        // The field is private and the parameter is not — Dart has no
        // private named parameter, so an initializing formal can't say this.
        // ignore: prefer_initializing_formals
        _uidProvider = uidProvider;

  static const _collection = 'users';

  /// How fresh a heartbeat must be for a device to count as online.
  /// Comfortably longer than [heartbeatInterval] so one dropped write
  /// doesn't flip a live device to offline.
  static const Duration onlineWindow = Duration(minutes: 8);

  /// How often a foregrounded device rewrites its `lastSeen`.
  static const Duration heartbeatInterval = Duration(minutes: 3);

  // Resolved lazily — this is a top-level singleton whose constructor runs
  // at library load, before `Firebase.initializeApp()` in `main()`, and
  // `FirebaseFirestore.instance` throws synchronously until then. Same
  // reasoning as CampaignRequestService.
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Where this device's uid comes from. Injectable because the default —
  /// [firebaseAuthService] — reads `FirebaseAuth.instance`, which throws
  /// `[core/no-app]` under `flutter test` where no Firebase app exists.
  final String? Function()? _uidProvider;
  String? get _uid => (_uidProvider ?? () => firebaseAuthService.uid)();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _heartbeat;

  final Map<String, RegisteredDevice> _byUid = {};

  List<RegisteredDevice> get devices => _byUid.values.toList()
    ..sort((a, b) {
      // Online first, then most-recently-seen — an admin scanning this list
      // during an incident cares about who is reachable now.
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final at = a.lastSeen, bt = b.lastSeen;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

  int get totalDevices => _byUid.length;
  int get onlineCount => _byUid.values.where((d) => d.isOnline).length;
  int get offlineCount => totalDevices - onlineCount;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Register this device, then keep the roster live. Best-effort in every
  /// direction: with no network the app simply shows an empty roster and
  /// Firestore's own write cache flushes the heartbeat when it reconnects.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await registerSelf();
    try {
      _sub = _firestore.collection(_collection).snapshots().listen((snap) {
        for (final doc in snap.docs) {
          _byUid[doc.id] = RegisteredDevice.fromJson(doc.id, doc.data());
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('DeviceRegistryService: stream failed: $e');
      });
    } catch (e) {
      debugPrint('DeviceRegistryService: subscribe failed: $e');
    }
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => registerSelf());
  }

  /// Write this device's row. Uses `merge` so it never clobbers the
  /// `role: 'admin'` field [FirebaseAuthService.claimAdminRole] writes to
  /// the same doc.
  ///
  /// Everything is inside the try: reading the uid goes through
  /// `FirebaseAuth.instance`, which *throws synchronously* when no Firebase
  /// app has been initialized — so a bare guard outside the catch would take
  /// the whole init path down on a device with no Firebase config.
  Future<void> registerSelf() async {
    try {
      final uid = _uid;
      if (uid == null) return; // anonymous sign-in hasn't landed yet
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? '';
      await _firestore.collection(_collection).doc(uid).set({
        'uid': uid,
        'name': name,
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DeviceRegistryService: registerSelf failed: $e');
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// App-wide singleton — one per app instance.
final DeviceRegistryService deviceRegistryService = DeviceRegistryService();
