import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A driving route returned by [OsrmRouteService].
class OsrmRoute {
  final List<LatLng> points;
  final double distanceKm;

  const OsrmRoute({required this.points, required this.distanceKm});

  @override
  bool operator ==(Object other) =>
      other is OsrmRoute &&
      other.distanceKm == distanceKm &&
      other.points.length == points.length &&
      _listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(distanceKm, Object.hashAll(points));

  static bool _listEquals(List<LatLng> a, List<LatLng> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Fetches driving routes from the public OSRM demo server
/// (`https://router.project-osrm.org`). Stateless except for the
/// injected [http.Client] (defaults to a fresh `http.Client()`),
/// which the service owns and disposes on [dispose].
///
/// Returns `null` on **any** failure: non-200 status, body not
/// a JSON object, `code != 'Ok'`, empty `routes` array, missing
/// geometry, timeout, or exception. Each failure path emits a
/// `dart:developer.log()` line under the `shongjog.shelter`
/// logger for diagnostics.
class OsrmRouteService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving/';

  final http.Client _client;
  final Duration _timeout;

  OsrmRouteService({
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 8);

  /// Fetches a driving route from [from] to [to]. Returns null on failure.
  Future<OsrmRoute?> fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await _client.get(url).timeout(_timeout);

      if (resp.statusCode != 200) {
        developer.log(
          'OSRM non-200: ${resp.statusCode}',
          name: 'shongjog.shelter',
        );
        return null;
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(resp.body);
      } catch (_) {
        developer.log(
          'OSRM body is not valid JSON',
          name: 'shongjog.shelter',
        );
        return null;
      }
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'OSRM body is not a JSON object',
          name: 'shongjog.shelter',
        );
        return null;
      }
      if (decoded['code'] != 'Ok') {
        developer.log(
          'OSRM code != Ok: ${decoded['code']}',
          name: 'shongjog.shelter',
        );
        return null;
      }

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        developer.log('OSRM: routes empty', name: 'shongjog.shelter');
        return null;
      }
      final route = routes.first;
      if (route is! Map<String, dynamic>) {
        return null;
      }
      final geometry = route['geometry'];
      if (geometry is! Map<String, dynamic>) {
        return null;
      }
      final coords = geometry['coordinates'];
      if (coords is! List) {
        return null;
      }

      final points = <LatLng>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) return null;
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        points.add(LatLng(lat, lon));
      }

      final distMeters = route['distance'];
      if (distMeters is! num) return null;

      return OsrmRoute(
        points: points,
        distanceKm: distMeters.toDouble() / 1000.0,
      );
    } on TimeoutException {
      developer.log('OSRM timeout', name: 'shongjog.shelter');
      return null;
    } catch (e, st) {
      developer.log(
        'OSRM error: $e',
        name: 'shongjog.shelter',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Closes the underlying HTTP client. Call this when the service
  /// will no longer be used.
  void dispose() => _client.close();
}
