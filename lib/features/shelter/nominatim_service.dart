import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final client = HttpClient();
    try {
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'com.shongjog.app/1.0');
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body);
      if (list is! List) return null;
      return list
          .map((e) => NominatimResult.tryParse(e as Map<String, dynamic>))
          .whereType<NominatimResult>()
          .take(limit)
          .toList();
    } catch (_) {
      return null;
    } finally {
      client.close();
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
