import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:shongjog/features/shelter/osrm_route_service.dart';
import 'package:shongjog/features/shelter/shelter_map_view_model.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_repository.dart';

void main() {
  const sampleA = Shelter(
    name: 'A',
    nameBn: 'এ',
    lat: 23.0,
    lon: 90.0,
    source: 'OSM',
  );
  const sampleB = Shelter(
    name: 'B',
    nameBn: 'বি',
    lat: 23.1,
    lon: 90.1,
    source: 'OSM',
  );
  final userPos = _FakePosition(latitude: 22.0, longitude: 89.0);

  Future<Position?> resolveGeoStub({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async =>
      userPos;

  group('ShelterMapViewModel', () {
    test('init() loads shelters via injected repository', () async {
      final repo = _FakeRepo([sampleA, sampleB]);
      final vm = ShelterMapViewModel(
        repository: repo,
        resolvePosition: resolveGeoStub,
        routeService: _FakeRouteService(),
      );
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.shelters, equals([sampleA, sampleB]));
      expect(vm.userPosition, equals(userPos));
      expect(vm.gpsError, isNull);
    });

    test('fetchRoute happy path online — sets route + clears loading', () async {
      final route = OsrmRoute(
        points: const [LatLng(22.0, 89.0), LatLng(23.0, 90.0)],
        distanceKm: 14.25,
      );
      final vm = ShelterMapViewModel(
        repository: _FakeRepo([sampleA]),
        resolvePosition: resolveGeoStub,
        routeService: _FakeRouteService(handler: (_, _) => route),
      )..isOnline = true;
      addTearDown(vm.dispose);
      await vm.init();

      await vm.fetchRoute(sampleA);

      expect(vm.selectedShelter, sampleA);
      expect(vm.routePoints, equals(route.points));
      expect(vm.routeDistanceKm, 14.25);
      expect(vm.loadingRoute, false);
    });

    test(
      'fetchRoute offline uses straight-line haversine fallback (no network)',
      () async {
        var networkCalled = false;
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA]),
          resolvePosition: resolveGeoStub,
          routeService: _FakeRouteService(
            handler: (_, _) async {
              networkCalled = true;
              return null;
            },
          ),
        )..isOnline = false;
        addTearDown(vm.dispose);
        await vm.init();

        await vm.fetchRoute(sampleA);

        expect(networkCalled, false,
            reason: 'no network call when offline');
        expect(vm.selectedShelter, sampleA);
        expect(vm.routePoints, hasLength(2));
        expect(vm.routePoints.first, LatLng(22.0, 89.0));
        expect(vm.routePoints.last, LatLng(23.0, 90.0));
        expect(vm.routeDistanceKm, isNotNull);
        expect(vm.routeDistanceKm! > 0, true);
        expect(vm.loadingRoute, false);
      },
    );

    test(
      'fetchRoute online but service returns null — falls back to haversine',
      () async {
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA]),
          resolvePosition: resolveGeoStub,
          routeService: _FakeRouteService(handler: (_, _) => null),
        )..isOnline = true;
        addTearDown(vm.dispose);
        await vm.init();

        await vm.fetchRoute(sampleA);

        expect(vm.routePoints, hasLength(2));
        expect(vm.routeDistanceKm, isNotNull);
        expect(vm.loadingRoute, false);
      },
    );

    test(
      'fetchRoute race — newer request supersedes older (TIER 1 bug regression)',
      () async {
        // Without the request-id guard, the older slower call would land
        // last and clobber the newer one. The handler resolves A slowly
        // and B quickly; we expect VM state to reflect B at the end.
        final routeA = OsrmRoute(
          points: const [
            LatLng(22.0, 89.0),
            LatLng(23.0, 90.0),
          ],
          distanceKm: 10.0,
        );
        final routeB = OsrmRoute(
          points: const [
            LatLng(22.0, 89.0),
            LatLng(23.1, 90.1),
          ],
          distanceKm: 20.0,
        );
        final delayedRouteService = _FakeRouteService(handler: (from, to) async {
          // (from, to): A is lon=90.0, B is lon=90.1.
          if (to.longitude == 90.0) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return routeA;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return routeB;
        });
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA, sampleB]),
          resolvePosition: resolveGeoStub,
          routeService: delayedRouteService,
        )..isOnline = true;
        addTearDown(vm.dispose);
        await vm.init();

        // Start A (slow), then B (fast) — B fires before A resolves.
        final futA = vm.fetchRoute(sampleA);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final futB = vm.fetchRoute(sampleB);

        await Future.wait([futA, futB]);

        expect(vm.selectedShelter, sampleB,
            reason: 'newer request must win');
        expect(vm.routeDistanceKm, 20.0,
            reason: 'state must reflect the newer request');
      },
    );

    test('clearRoute wipes route state without disturbing shelters', () async {
      final route = OsrmRoute(
        points: const [LatLng(22.0, 89.0), LatLng(23.0, 90.0)],
        distanceKm: 14.25,
      );
      final vm = ShelterMapViewModel(
        repository: _FakeRepo([sampleA]),
        resolvePosition: resolveGeoStub,
        routeService: _FakeRouteService(handler: (_, _) => route),
      )..isOnline = true;
      addTearDown(vm.dispose);
      await vm.init();
      await vm.fetchRoute(sampleA);

      vm.clearRoute();

      expect(vm.selectedShelter, isNull);
      expect(vm.routePoints, isEmpty);
      expect(vm.routeDistanceKm, isNull);
      expect(vm.loadingRoute, false);
      expect(vm.shelters, equals([sampleA]),
          reason: 'clearRoute must not disturb loaded shelters');
    });

    test('toggleSearchPanel — first tap opens + ranks, second tap closes',
        () async {
      final vm = ShelterMapViewModel(
        repository: _FakeRepo([sampleA, sampleB]),
        resolvePosition: resolveGeoStub,
        routeService: _FakeRouteService(),
      )..isOnline = true;
      addTearDown(vm.dispose);
      await vm.init();

      vm.toggleSearchPanel();
      expect(vm.showSearchPanel, true);
      expect(vm.rankedShelters, hasLength(2));

      vm.toggleSearchPanel();
      expect(vm.showSearchPanel, false);
    });

    test(
      'onSearchSelect closes panel then routes the selected shelter',
      () async {
        final route = OsrmRoute(
          points: const [LatLng(22.0, 89.0), LatLng(23.0, 90.0)],
          distanceKm: 14.25,
        );
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA, sampleB]),
          resolvePosition: resolveGeoStub,
          routeService: _FakeRouteService(handler: (_, _) => route),
        )..isOnline = true;
        addTearDown(vm.dispose);
        await vm.init();

        vm.toggleSearchPanel();
        expect(vm.showSearchPanel, true);

        final first = vm.rankedShelters.first;
        await vm.onSearchSelect(first);

        expect(vm.showSearchPanel, false);
        expect(vm.selectedShelter, first.shelter);
        expect(vm.routeDistanceKm, 14.25);
      },
    );

    test(
      'fetchRoute after dispose is a no-op (TIER 1 post-await safety)',
      () async {
        final delayedRouteService = _FakeRouteService(
          handler: (_, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return OsrmRoute(
              points: const [LatLng(22.0, 89.0), LatLng(23.0, 90.0)],
              distanceKm: 14.25,
            );
          },
        );
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA]),
          resolvePosition: resolveGeoStub,
          routeService: delayedRouteService,
        )..isOnline = true;
        await vm.init();
        final pending = vm.fetchRoute(sampleA);

        vm.dispose();

        // Should NOT throw even though fetchRoute is still in flight.
        await pending;
      },
    );

    test(
      'fetchRoute calls notifyListeners for each phase a UI would care about',
      () async {
        int notifies = 0;
        final route = OsrmRoute(
          points: const [LatLng(22.0, 89.0), LatLng(23.0, 90.0)],
          distanceKm: 14.25,
        );
        final vm = ShelterMapViewModel(
          repository: _FakeRepo([sampleA]),
          resolvePosition: resolveGeoStub,
          routeService: _FakeRouteService(handler: (_, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return route;
          }),
        )..isOnline = true
          ..addListener(() => notifies++);
        addTearDown(vm.dispose);
        await vm.init();
        final before = notifies;

        await vm.fetchRoute(sampleA);

        // At minimum: 1 for entering loading, 1 for completing.
        expect(notifies - before, greaterThanOrEqualTo(2));
      },
    );
  });
}

/// Test double for [ShelterRepository].
class _FakeRepo implements ShelterRepository {
  final List<Shelter> _list;
  _FakeRepo(this._list);
  @override
  Future<List<Shelter>> loadAll() async => _list;
}

/// Test double for [OsrmRouteService]. `handler` returns the canned route
/// for a given (from, to). When no handler is supplied, every call
/// returns null (forcing the caller's fallback path).
class _FakeRouteService extends OsrmRouteService {
  final FutureOr<OsrmRoute?> Function(LatLng from, LatLng to)? handler;
  _FakeRouteService({this.handler}) : super();

  @override
  Future<OsrmRoute?> fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    if (handler == null) return null;
    return handler!(from, to);
  }
}

/// Minimal [Position] fake — only latitude and longitude are exercised
/// by the VM. Other fields fall through `noSuchMethod`.
class _FakePosition implements Position {
  @override
  final double latitude;
  @override
  final double longitude;
  _FakePosition({required this.latitude, required this.longitude});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
