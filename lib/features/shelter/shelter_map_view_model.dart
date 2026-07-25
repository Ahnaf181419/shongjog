import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/connectivity_provider.dart';
import 'nearest_shelter.dart';
import 'osrm_route_service.dart';
import 'shelter_constants.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';

/// State and behaviour for the shelter map, shared between the GPS,
/// connectivity, OSRM routing, and search surfaces.
///
/// Listens via standard [ChangeNotifier] so the screen wraps the body
/// in a [ListenableBuilder].
///
/// Concurrency safety:
///   * [_routeRequestId] is incremented on every [fetchRoute] call; an
///     in-flight call whose id no longer matches is silently abandoned,
///     so a stale slow response cannot clobber a newer selection.
///   * [_disposed] is set in [dispose]; all awaits are followed by a
///     `_disposed || req != _routeRequestId` guard so we never call
///     [notifyListeners] (or read the disposed VM) after teardown.
class ShelterMapViewModel extends ChangeNotifier {
  final ShelterRepository _repository;
  final OsrmRouteService _routeService;
  final ConnectivityProvider _connectivity;

  final Future<Position?> Function({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) _resolvePosition;

  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;

  /// Repository-provided shelter list. Empty until [init] completes.
  List<Shelter> shelters = const [];

  /// Last GPS fix, or null when no fix is available (yet).
  Position? userPosition;

  /// Localized GPS error message, or null when GPS is simply not ready.
  String? gpsError;

  /// Whether the device currently has a usable network interface.
  /// Drives the offline-gate in [fetchRoute]; updated externally by the
  /// screen (which is the subscriber to the connectivity stream).
  bool isOnline;

  /// The shelter the route is currently drawn to. Survives across
  /// fetches so the polyline is anchored to the user's last pick
  /// until they tap "বাতিল" or pick another shelter.
  Shelter? selectedShelter;

  /// Decoded OSRM polyline points. Empty when no route is active.
  List<LatLng> routePoints = const [];

  /// Routed distance in km — `meters / 1000` from OSRM, or the
  /// haversine great-circle fallback when offline. Null when no route.
  double? routeDistanceKm;

  /// True between the start of [fetchRoute] and either the success path
  /// or the fallback path completion.
  bool loadingRoute = false;

  /// Whether the full-screen search overlay is open.
  bool showSearchPanel = false;

  /// Cached ranked shelter list (last [toggleSearchPanel] open).
  List<RankedShelter> rankedShelters = const [];

  int _routeRequestId = 0;
  bool _disposed = false;

  ShelterMapViewModel({
    ShelterRepository? repository,
    OsrmRouteService? routeService,
    ConnectivityProvider? connectivity,
    Future<Position?> Function({
      required LocationAccuracy accuracy,
      required Duration timeLimit,
    })?
        resolvePosition,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    bool initialOnline = true,
  })  : _repository = repository ?? ShelterRepository(),
        _routeService = routeService ?? OsrmRouteService(),
        _connectivity = connectivity ?? connectivityProvider,
        _resolvePosition = resolvePosition ?? _defaultGeolocator,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        isOnline = initialOnline;

  static Future<Position?> _defaultGeolocator({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings:
          LocationSettings(accuracy: accuracy, timeLimit: timeLimit),
    );
  }

  /// Hook the screen calls once on mount. Loads shelters, resolves GPS,
  /// reads initial connectivity, then notifies. Safe to call once.
  Future<void> init() async {
    try {
      shelters = await _repository.loadAll();
    } catch (_) {
      shelters = const [];
    }
    // Notify immediately so the map renders with shelter markers
    // while GPS resolves in the background.
    notifyListeners();

    try {
      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        gpsError = 'GPS অনুমতি দেওয়া হয়নি';
      } else {
        userPosition = await _resolvePosition(
          accuracy: LocationAccuracy.high,
          timeLimit: ShelterConstants.gpsTimeout,
        );
      }
    } catch (_) {
      gpsError = 'GPS পাওয়া যায়নি';
    }

    notifyListeners();
  }

  /// Called by the screen on each connectivity change to keep the VM in
  /// sync with the underlying provider. Public so the screen owns the
  /// listener subscription lifecycle.
  void setOnline(bool online) {
    if (isOnline == online) return;
    isOnline = online;
    notifyListeners();
  }

  /// Synchronous read of the underlying connectivity provider. Useful in
  /// [fetchRoute] for ad-hoc checks if the screen forgot to push a
  /// [setOnline] notification.
  bool get connectivityIsOnline => _connectivity.isOnline;

  /// Fetches a driving route from [userPosition] to [shelter]. Honors
  /// the offline gate: when [isOnline] is false, draws a haversine
  /// straight line immediately. Older in-flight calls are abandoned on
  /// a newer selection.
  Future<void> fetchRoute(Shelter shelter) async {
    if (userPosition == null) return;
    final req = ++_routeRequestId;

    selectedShelter = shelter;
    loadingRoute = true;
    if (!_disposed) notifyListeners();

    if (!isOnline && !_connectivity.isOnline) {
      _fallbackStraightLine(shelter, req);
      return;
    }

    final route = await _routeService.fetchRoute(
      from: LatLng(userPosition!.latitude, userPosition!.longitude),
      to: LatLng(shelter.lat, shelter.lon),
    );

    if (_disposed || req != _routeRequestId) return;
    if (route == null) {
      _fallbackStraightLine(shelter, req);
      return;
    }
    routePoints = route.points;
    routeDistanceKm = route.distanceKm;
    loadingRoute = false;
    if (!_disposed) notifyListeners();
  }

  void _fallbackStraightLine(Shelter shelter, int req) {
    if (_disposed || req != _routeRequestId) return;
    final user = LatLng(userPosition!.latitude, userPosition!.longitude);
    final dst = LatLng(shelter.lat, shelter.lon);
    final dist =
        haversineKm(user.latitude, user.longitude, dst.latitude, dst.longitude);
    routePoints = [user, dst];
    routeDistanceKm = dist;
    loadingRoute = false;
    if (!_disposed) notifyListeners();
  }

  /// Clear the active route. Does not touch shelters or other state.
  void clearRoute() {
    selectedShelter = null;
    routePoints = const [];
    routeDistanceKm = null;
    loadingRoute = false;
    notifyListeners();
  }

  /// Toggle the full-screen search overlay. When opening, computes
  /// [rankedShelters] once. When closing, no-op.
  void toggleSearchPanel() {
    if (showSearchPanel) {
      showSearchPanel = false;
      notifyListeners();
      return;
    }
    if (userPosition != null) {
      rankedShelters = nearestShelters(
        lat: userPosition!.latitude,
        lon: userPosition!.longitude,
        all: shelters,
        k: shelters.length,
      );
    }
    showSearchPanel = true;
    notifyListeners();
  }

  /// Closes the search overlay then routes to [ranked]. Returns the
  /// in-flight [fetchRoute] future so callers (or tests) can await it.
  Future<void> onSearchSelect(RankedShelter ranked) async {
    showSearchPanel = false;
    notifyListeners();
    await fetchRoute(ranked.shelter);
  }

  @override
  void dispose() {
    _disposed = true;
    _routeService.dispose();
    super.dispose();
  }
}
