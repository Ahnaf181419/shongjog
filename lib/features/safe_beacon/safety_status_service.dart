import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  /// Bangla label for the danger-type picker.
  String get labelBn => switch (this) {
        DangerType.flood => 'বন্যা',
        DangerType.fire => 'আগুন',
        DangerType.earthquake => 'ভূমিকম্প',
        DangerType.cyclone => 'ঘূর্ণিঝড়',
        DangerType.landslide => 'ভূমিধস',
        DangerType.trapped => 'আটকা পড়েছি',
        DangerType.medical => 'চিকিৎসা জরুরি',
        DangerType.violence => 'সহিংসতা / অস্থিরতা',
        DangerType.other => 'অন্যান্য',
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
  SafetyStatusService();

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

  /// Record the current user's own report.
  void setMyReport(SafetyReport r) {
    _myReport = r;
    ingest(r);
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
}

/// Global singleton — one per app instance.
final SafetyStatusService safetyStatusService = SafetyStatusService();
