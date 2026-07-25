import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Overpass API client (free, key-less, OSM).
///
/// Queries OpenStreetMap for points of interest (hospitals, clinics,
/// pharmacies, police stations, fire stations) near a given point.
/// Docs: https://wiki.openstreetmap.org/wiki/Overpass_API
class OverpassService {
  static const _timeout = Duration(seconds: 12);
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  /// Search for POIs of type [amenity] within [radiusM] metres of the
  /// given point. Returns at most [limit] results.
  static Future<List<OverpassPoi>?> searchPois({
    required double lat,
    required double lon,
    required String amenity,
    int radiusM = 5000,
    int limit = 10,
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    // Overpass QL: node["amenity"=X](around:R,lat,lon);
    final query =
        '[out:json][timeout:10];node["amenity"="$amenity"](around:$radiusM,$lat,$lon);out $limit;';
    final uri = Uri.parse(_endpoint);
    final client = HttpClient();
    try {
      client.connectionTimeout = _timeout;
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded');
      req.headers.set(HttpHeaders.userAgentHeader, 'com.shongjog.app/1.0');
      req.write('data=${Uri.encodeQueryComponent(query)}');
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final elements = json['elements'];
      if (elements is! List) return null;
      return elements
          .map((e) => OverpassPoi.tryParse(e as Map<String, dynamic>))
          .whereType<OverpassPoi>()
          .toList();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}

class OverpassPoi {
  final String name;
  final String? nameBn;
  final double lat;
  final double lon;
  final String amenity;

  const OverpassPoi({
    required this.name,
    this.nameBn,
    required this.lat,
    required this.lon,
    required this.amenity,
  });

  static OverpassPoi? tryParse(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>?;
    if (tags == null) return null;
    final name = tags['name'] as String? ?? '';
    if (name.isEmpty) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return OverpassPoi(
      name: name,
      nameBn: tags['name:bn'] as String?,
      lat: lat,
      lon: lon,
      amenity: tags['amenity'] as String? ?? '',
    );
  }
}
