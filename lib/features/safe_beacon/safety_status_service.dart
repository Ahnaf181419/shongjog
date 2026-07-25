import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../l10n/app_localizations.dart';

/// The type of danger a user is reporting.
enum DangerType {
  flood,
  fire,
  earthquake,
  cyclone,
  landslide,
  trapped,
  medical,
  violence,
  other;

  /// Localized label for the danger-type picker.
  String label(AppLocalizations l10n) => switch (this) {
        DangerType.flood => l10n.safetyDangerFlood,
        DangerType.fire => l10n.safetyDangerFire,
        DangerType.earthquake => l10n.safetyDangerEarthquake,
        DangerType.cyclone => l10n.safetyDangerCyclone,
        DangerType.landslide => l10n.safetyDangerLandslide,
        DangerType.trapped => l10n.safetyDangerTrapped,
        DangerType.medical => l10n.safetyDangerMedical,
        DangerType.violence => l10n.safetyDangerViolence,
        DangerType.other => l10n.safetyDangerOther,
      };

  String get id => name;

  static DangerType fromId(String? id) =>
      DangerType.values.firstWhere(
        (e) => e.id == id,
        orElse: () => DangerType.other,
      );
}

/// A single user's safety status report.
///
/// Wire format for mesh relay — same JSON shape whether it travels
/// over Bluetooth mesh or arrives directly. The admin's
/// [SafetyStatusService] aggregates these into live counts.
class SafetyReport {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;

  /// 'safe' or 'danger'.
  final String status;

  /// Only set when [status] == 'danger'. Null when safe.
  final DangerType? dangerType;

  /// Optional free-text note from the user.
  final String note;

  final double? lat;
  final double? lon;

  final DateTime timestamp;

  /// How many mesh hops this report has travelled.
  final int hopCount;

  const SafetyReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.status,
    this.dangerType,
    this.note = '',
    this.lat,
    this.lon,
    required this.timestamp,
    this.hopCount = 0,
  });

  static const safeStatus = 'safe';
  static const dangerStatus = 'danger';

  bool get isDanger => status == dangerStatus;
  bool get isSafe => status == safeStatus;

  /// Google Maps link for the admin's "in danger" list.
  String? get mapsLink =>
      (lat != null && lon != null) ? 'https://maps.google.com/?q=$lat,$lon' : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'status': status,
        if (dangerType != null) 'dangerType': dangerType!.id,
        if (note.isNotEmpty) 'note': note,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'timestamp': timestamp.toIso8601String(),
        'hopCount': hopCount,
      };

  static SafetyReport fromJson(Map<String, dynamic> m) => SafetyReport(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? 'একজন ব্যবহারকারী',
        userPhone: m['userPhone'] as String? ?? '',
        status: m['status'] as String? ?? safeStatus,
        dangerType: m['dangerType'] != null
            ? DangerType.fromId(m['dangerType'] as String?)
            : null,
        note: m['note'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lon: (m['lon'] as num?)?.toDouble(),
        timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ??
            DateTime.now(),
        hopCount: m['hopCount'] as int? ?? 0,
      );

  String encode() => Uri.encodeComponent(
        '{${toJson().entries.map((e) => '"${e.key}":${e.value is String ? '"${e.value}"' : e.value}').join(',')}}',
      );
}

/// App-wide aggregator for safety reports.
///
/// On a user's phone: tracks only the user's own last-sent report.
/// On an admin's phone: collects incoming mesh reports into live
/// counts (total / safe / danger). The admin dashboard listens to
/// this via [ChangeNotifier].
class SafetyStatusService extends ChangeNotifier {
  SafetyStatusService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  static const _collection = 'safety_reports';

  // Resolved lazily via [_firestore] below — see the same note in
  // CampaignRequestService for why this can't be an eager field: this
  // service is a top-level global singleton constructed before
  // `Firebase.initializeApp()` runs in `main()`.
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

  /// All reports we've seen, keyed by [SafetyReport.userId] so the
  /// latest status from each user overwrites older ones.
  final Map<String, SafetyReport> _byUser = {};

  /// The current user's own last-sent report (null if never sent).
  SafetyReport? _myReport;
  SafetyReport? get myReport => _myReport;

  List<SafetyReport> get all => _byUser.values.toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get totalUsers => _byUser.length;
  int get safeCount => _byUser.values.where((r) => r.isSafe).length;
  int get dangerCount => _byUser.values.where((r) => r.isDanger).length;

  List<SafetyReport> get dangerReports =>
      _byUser.values.where((r) => r.isDanger).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  bool _initialized = false;

  /// Start listening for cross-device safety reports. This service was
  /// memory-only before Firestore was added (no local file, rebuilt from
  /// zero every launch) — mesh-relayed reports still arrive via [ingest]
  /// exactly as before; this just adds a second source feeding the same
  /// dedup-by-latest-timestamp logic, so a report can arrive via mesh OR
  /// Firestore OR both without special-casing either path. Best-effort —
  /// offline devices simply keep working from mesh + local self-report.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    try {
      _firestoreSub = _firestore
          .collection(_collection)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          ingest(SafetyReport.fromJson(doc.data()));
        }
      }, onError: (e) {
        debugPrint('SafetyStatusService Firestore stream failed: $e');
      });
    } catch (e) {
      debugPrint('SafetyStatusService Firestore subscribe failed: $e');
    }
  }

  /// Record the current user's own report.
  void setMyReport(SafetyReport r) {
    _myReport = r;
    ingest(r);
    // Wrapped in try/catch, not just .catchError: accessing [_firestore]
    // itself throws SYNCHRONOUSLY (not as a Future rejection) when no
    // Firebase app has been initialized yet, so a bare .catchError chained
    // onto .set(...) would never even run — the throw happens before
    // .set() is reached.
    try {
      _firestore.collection(_collection).doc(r.id).set(r.toJson()).catchError(
          (e) => debugPrint('SafetyStatusService: Firestore submit failed: $e'));
    } catch (e) {
      debugPrint('SafetyStatusService: Firestore submit failed: $e');
    }
  }

  /// Accept an incoming report (from mesh or local). Deduplicates by
  /// [SafetyReport.userId], keeping the latest by timestamp.
  void ingest(SafetyReport r) {
    final existing = _byUser[r.userId];
    if (existing != null && !r.timestamp.isAfter(existing.timestamp)) {
      return; // stale — keep the newer one
    }
    _byUser[r.userId] = r;
    notifyListeners();
  }

  /// Accept a decoded JSON map from the mesh listener.
  void ingestJson(String raw) {
    try {
      final decoded = Uri.decodeComponent(raw);
      ingest(SafetyReport.fromJson(
          jsonDecode(decoded) as Map<String, dynamic>));
    } catch (e) {
      debugPrint('[SafetyStatus] failed to ingest: $e');
    }
  }

  /// Clear all data (used by admin "reset" or tests).
  void clear() {
    _byUser.clear();
    _myReport = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

/// Global singleton — one per app instance.
final SafetyStatusService safetyStatusService = SafetyStatusService();
