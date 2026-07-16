import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One entry in the offline emergency directory.
class EmergencyEntry {
  final String nameBn;
  final String name;
  final String phone;
  final String division; // 'all' | 'dhaka' | 'chattogram' | etc.
  final String type; // 'police' | 'fire' | 'hospital' | 'helpline' | ...

  const EmergencyEntry({
    required this.nameBn,
    required this.name,
    required this.phone,
    required this.division,
    required this.type,
  });

  factory EmergencyEntry.fromJson(Map<String, dynamic> j) => EmergencyEntry(
        nameBn: j['nameBn'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        division: j['division'] as String? ?? 'all',
        type: j['type'] as String? ?? 'other',
      );
}

/// Loads and parses the offline emergency directory from
/// `assets/emergency/directory.json`. Cached in memory after the
/// first read.
class DirectoryLoader {
  static const _assetPath = 'assets/emergency/directory.json';
  static List<EmergencyEntry>? _cache;

  static Future<List<EmergencyEntry>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(EmergencyEntry.fromJson)
        .toList();
    _cache = list;
    return list;
  }

  /// Returns entries matching [division] OR 'all'. If [division] is
  /// null, returns everything.
  static Future<List<EmergencyEntry>> forDivision(String? division) async {
    final all = await loadAll();
    if (division == null || division.isEmpty || division == 'all') return all;
    return all
        .where((e) => e.division == 'all' || e.division == division)
        .toList();
  }

  /// In-memory test seam. Lets widget tests inject a custom list.
  @visibleForTesting
  static void debugSetEntries(List<EmergencyEntry> entries) {
    _cache = entries;
  }

  /// Test seam to clear the cache between runs.
  @visibleForTesting
  static void debugClearCache() {
    _cache = null;
  }
}