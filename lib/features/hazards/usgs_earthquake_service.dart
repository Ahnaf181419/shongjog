import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// USGS Earthquake Hazards client — recent seismic activity near Bangladesh.
///
/// The USGS FDSN event API is free, requires no key, and returns GeoJSON
/// FeatureCollections of earthquake events. We use it to surface recent
/// earthquakes (last 30 days, magnitude >= 4.0) within a Bangladesh-
/// centred bounding box.
///
/// Docs: https://earthquake.usgs.gov/fdsnws/event/1/
///
/// Bangladesh sits on an active seismic zone (Sylhet, Chittagong, and
/// the Dauki fault). Pairing this feed with the triage wizard's
/// earthquake card gives users a concrete "is there activity near me?"
/// answer — real data, not a guess.
class UsgsEarthquakeService {
  static const _timeout = Duration(seconds: 10);

  /// Default window: last 30 days, magnitude >= 4.0. Anything smaller
  /// is either too frequent to be useful or not strong enough to matter
  /// for a layperson's safety check.
  static const int _defaultMinMagnitude = 4;

  /// Bounding box covering Bangladesh + adjacent seismic regions
  /// [minlatitude, maxlatitude, minlongitude, maxlongitude].
  static const double minLat = 20.0;
  static const double maxLat = 27.5;
  static const double minLon = 88.0;
  static const double maxLon = 93.5;

  /// Fetch recent earthquakes. Returns an empty list if the query
  /// succeeds but returns no events; null on offline / transport /
  /// parse failure.
  static Future<List<EarthquakeEvent>?> fetchRecent({
    int? daysBack,
    int? minMagnitude,
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    final start = DateTime.now().toUtc().subtract(
      Duration(days: daysBack ?? 30),
    );
    final minMag = minMagnitude ?? _defaultMinMagnitude;
    final uri = Uri.parse(
      'https://earthquake.usgs.gov/fdsnws/event/1/query'
      '?format=geojson'
      '&starttime=${start.toIso8601String().split('T').first}'
      '&minlatitude=$minLat'
      '&maxlatitude=$maxLat'
      '&minlongitude=$minLon'
      '&maxlongitude=$maxLon'
      '&minmagnitude=$minMag'
      '&orderby=time',
    );
    final client = HttpClient();
    try {
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(utf8.decoder)
          .toList()
          .then((chunks) => chunks.join());
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final features = json['features'];
      if (features is! List) return null;
      return features
          .map((f) => EarthquakeEvent.tryParse(f as Map<String, dynamic>))
          .whereType<EarthquakeEvent>()
          // The lat/lon bounding box above is necessarily loose — Bangladesh
          // is surrounded on three sides by India, so any rectangle that
          // covers it also sweeps in West Bengal, Assam, Meghalaya, Tripura,
          // and part of Myanmar. USGS's `place` string reliably ends in a
          // country/region name ("32 km E of Sylhet, Bangladesh" vs.
          // "45 km NW of Imphal, India"), so use that as the authoritative
          // "is this actually Bangladesh" filter rather than trusting the box.
          .where((e) => isBangladeshPlace(e.place))
          .toList();
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Whether a USGS `place` string names Bangladesh specifically, e.g.
  /// "32 km E of Sylhet, Bangladesh". Exposed for testing.
  @visibleForTesting
  static bool isBangladeshPlace(String place) =>
      place.toLowerCase().contains('bangladesh');
}

/// A single earthquake event, parsed from the USGS GeoJSON Feature shape.
class EarthquakeEvent {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double depthKm;

  const EarthquakeEvent({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
  });

  /// Parse a USGS GeoJSON Feature. Returns null if required fields are
  /// missing or malformed.
  static EarthquakeEvent? tryParse(Map<String, dynamic> feature) {
    final id = feature['id'] as String?;
    if (id == null) return null;
    final props = feature['properties'] as Map<String, dynamic>?;
    final geom = feature['geometry'] as Map<String, dynamic>?;
    if (props == null || geom == null) return null;

    final mag = (props['mag'] as num?)?.toDouble();
    if (mag == null) return null;
    final place = props['place'] as String? ?? '';
    final rawTime = props['time'] as num?;
    DateTime? time;
    if (rawTime != null) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt(), isUtc: true);
    } else {
      return null;
    }

    // GeoJSON Point: coordinates = [lon, lat, depth]
    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    final depth = coords.length >= 3 ? (coords[2] as num?)?.toDouble() ?? 0.0 : 0.0;
    if (lon == null || lat == null) return null;

    return EarthquakeEvent(
      id: id,
      magnitude: mag,
      place: place,
      time: time,
      latitude: lat,
      longitude: lon,
      depthKm: depth,
    );
  }

  /// Human-readable severity bucket. USGS uses 4.0+ as "light", but for
  /// an emergency app a 5.0+ is the relevant "did you feel it?" threshold.
  EarthquakeSeverity get severity {
    if (magnitude >= 6.0) return EarthquakeSeverity.strong;
    if (magnitude >= 5.0) return EarthquakeSeverity.moderate;
    return EarthquakeSeverity.light;
  }
}

enum EarthquakeSeverity { light, moderate, strong }

extension EarthquakeSeverityLabel on EarthquakeSeverity {
  String label(BuildContext context) => switch (this) {
        EarthquakeSeverity.light => AppLocalizations.of(context).earthquakeLight,
        EarthquakeSeverity.moderate => AppLocalizations.of(context).earthquakeModerate,
        EarthquakeSeverity.strong => AppLocalizations.of(context).earthquakeStrong,
      };
}
