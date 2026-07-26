import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Nominatim geocoding client (free, key-less, OSM).
///
/// Converts a place name ("ঢাকা মেডিকেল কলেজ") into lat/lon coordinates.
/// Docs: https://nominatim.org/release-docs/develop/api/Search/
///
/// Rate-limited to 1 request/second by the public server. We send a
/// descriptive User-Agent as required by the usage policy.
class NominatimService {
  static const _timeout = Duration(seconds: 8);

  static Future<List<NominatimResult>?> search({
    required String query,
    int limit = 3,
    bool isOnline = true,
  }) async {
    if (!isOnline || query.trim().isEmpty) return null;
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&format=json'
      '&limit=$limit'
      '&accept-language=bn,en',
    );
    try {
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'com.shongjog.app/1.0'},
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('[Nominatim] non-200 status: ${res.statusCode}');
        return null;
      }
      final list = jsonDecode(res.body);
      if (list is! List) return null;
      return list
          .map((e) => NominatimResult.tryParse(e as Map<String, dynamic>))
          .whereType<NominatimResult>()
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('[Nominatim] search failed: $e');
      return null;
    }
  }
}

class NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  const NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  static NominatimResult? tryParse(Map<String, dynamic> json) {
    final name = json['display_name'] as String?;
    final lat = double.tryParse(json['lat'] as String? ?? '');
    final lon = double.tryParse(json['lon'] as String? ?? '');
    if (name == null || lat == null || lon == null) return null;
    return NominatimResult(displayName: name, lat: lat, lon: lon);
  }
}
