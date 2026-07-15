import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:shongjog/features/shelter/osrm_route_service.dart';

void main() {
  group('OsrmRouteService', () {
    test('returns parsed route on 200 + code Ok', () async {
      // OSRM GeoJSON LineString: [longitude, latitude] per spec.
      final geometry = {
        'type': 'LineString',
        'coordinates': [
          [90.0, 23.0],
          [90.1, 23.1],
        ],
      };
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {'distance': 14250.0, 'geometry': geometry}
            ],
          }),
          200,
        );
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNotNull);
      expect(route!.points, hasLength(2));
      expect(route.points[0].latitude, 23.0);
      expect(route.points[0].longitude, 90.0);
      expect(route.points[1].latitude, 23.1);
      expect(route.points[1].longitude, 90.1);
      expect(route.distanceKm, closeTo(14.25, 0.01));
    });

    test('returns null when OSRM returns code != Ok', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'code': 'NoRoute',
            'routes': [],
          }),
          200,
        );
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('returns null when routes array is empty', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [],
          }),
          200,
        );
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('returns null on non-200 status (e.g. 429 rate limit)', () async {
      final client = MockClient((req) async {
        return http.Response('rate limited', 429);
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('returns null on timeout', () async {
      final client = MockClient((req) async {
        // Never completes within the test's tight timeout — the
        // .timeout() wrapper fires first, returns null.
        await Future<void>.delayed(const Duration(seconds: 5));
        return http.Response('{}', 200);
      });
      final svc = OsrmRouteService(
        client: client,
        timeout: const Duration(milliseconds: 50),
      );

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('returns null on malformed JSON body', () async {
      final client = MockClient((req) async {
        return http.Response('not valid json {{', 200);
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('returns null when body is valid JSON but not an object', () async {
      final client = MockClient((req) async {
        return http.Response('["unexpected array"]', 200);
      });
      final svc = OsrmRouteService(client: client);

      final route = await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(23.1, 90.1),
      );

      expect(route, isNull);
    });

    test('builds URL in correct lon,lat;lon,lat order with full overview',
        () async {
      Uri? captured;
      final client = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 0.0,
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [90.0, 23.0],
                    [91.0, 24.0],
                  ],
                }
              }
            ]
          }),
          200,
        );
      });
      final svc = OsrmRouteService(client: client);

      await svc.fetchRoute(
        from: const LatLng(23.0, 90.0),
        to: const LatLng(24.0, 91.0),
      );

      expect(captured, isNotNull);
      expect(captured!.host, 'router.project-osrm.org');
      expect(
        captured!.path,
        '/route/v1/driving/90.0,23.0;91.0,24.0',
      );
      expect(captured!.queryParameters['overview'], 'full');
      expect(captured!.queryParameters['geometries'], 'geojson');
    });
  });
}
