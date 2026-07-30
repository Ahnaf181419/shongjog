import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/connectivity_provider.dart';
import '../chat/local_llm.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import 'nearest_shelter.dart';
import 'osrm_route_service.dart';
import 'shelter_constants.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';
import 'shelter_safety_ranker.dart';

/// Why [ShelterMapViewModel.userPosition] is unavailable. Surfaced so the
/// screen can map each case to a distinct, actionable localized message
/// (the VM stays free of `AppLocalizations` — pure Dart, unit-testable).
enum GpsFailureReason {
  /// OS-level location services are OFF. Action: ask the user to turn
  /// them on in Android Settings.
  serviceDisabled,

  /// Runtime permission denied or permanently denied. Action: re-prompt
  /// or guide to system settings.
  permissionDenied,

  /// Position resolution exceeded both the high- and medium-accuracy
  /// time limits. Typically a cold-start GPS indoors.
  timeout,

  /// Any other failure (plugin error, unexpected exception).
  unknown,
}

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
  final Future<bool> Function() _isLocationServiceEnabled;

  /// Repository-provided shelter list. Empty until [init] completes.
  List<Shelter> shelters = const [];

  /// Last GPS fix, or null when no fix is available (yet).
  Position? userPosition;

  /// Why GPS failed, or null when GPS is simply not ready (still loading)
  /// or succeeded. The screen maps this to a localized message; the VM
  /// stores only the structured reason so it stays free of l10n imports.
  GpsFailureReason? gpsFailure;

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
    this.model,
    Future<Position?> Function({
      required LocationAccuracy accuracy,
      required Duration timeLimit,
    })?
        resolvePosition,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<bool> Function()? isLocationServiceEnabled,
    bool initialOnline = true,
  })  : _repository = repository ?? ShelterRepository(),
        _routeService = routeService ?? OsrmRouteService(),
        _connectivity = connectivity ?? connectivityProvider,
        _resolvePosition = resolvePosition ?? _defaultGeolocator,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _isLocationServiceEnabled =
            isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
        isOnline = initialOnline;

  /// Optional on-device LLM for AI safety-ranking (Option 2). When
  /// null, the distance-only ranking is used (current behaviour).
  final LocalLlm? model;

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
  /// then notifies. Safe to call once.
  ///
  /// GPS resolution delegates to [acquireUserPosition], which the
  /// locate-me button can re-invoke on demand to retry after a cold-start
  /// timeout or a late permission grant.
  Future<void> init() async {
    try {
      shelters = await _repository.loadAll();
    } catch (e) {
      debugPrint('[ShelterMapVM] shelter load failed: $e');
      shelters = const [];
    }
    // Notify immediately so the map renders with shelter markers
    // while GPS resolves in the background.
    notifyListeners();

    await acquireUserPosition();
  }

  /// Acquire (or re-acquire) the user's GPS position. Returns `true` when
  /// a position is available after the call, `false` otherwise. Safe to
  /// call repeatedly — the locate-me button uses this to retry after a
  /// cold-start timeout or a permission grant.
  ///
  /// Every failure branch sets a structured [gpsFailureReason] (so the
  /// screen can show an actionable banner) and logs via `debugPrint`
  /// (so a real-device failure is diagnosable in logcat). Clears any
  /// stale failure before retrying so a successful retry removes the
  /// banner.
  Future<bool> acquireUserPosition() async {
    // 1. OS-level location services must be ON before any permission
    //    prompt or position fetch can succeed.
    try {
      final serviceEnabled = await _isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[ShelterMapVM] location services disabled (OS level)');
        gpsFailure = GpsFailureReason.serviceDisabled;
        userPosition = null;
        if (!_disposed) notifyListeners();
        return false;
      }
    } catch (e) {
      // Don't hard-fail on the check itself — proceed to permission flow
      // and let the position fetch surface a real error if any.
      debugPrint('[ShelterMapVM] isLocationServiceEnabled threw: $e');
    }

    // 2. Runtime permission flow.
    try {
      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[ShelterMapVM] permission denied: $permission');
        gpsFailure = GpsFailureReason.permissionDenied;
        userPosition = null;
        if (!_disposed) notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[ShelterMapVM] permission flow threw: $e');
      gpsFailure = GpsFailureReason.unknown;
      userPosition = null;
      if (!_disposed) notifyListeners();
      return false;
    }

    // 3. Resolve position with a fallback accuracy chain. Clear any
    //    stale failure optimistically so a successful retry hides the
    //    banner.
    gpsFailure = null;
    try {
      userPosition = await _resolvePosition(
        accuracy: LocationAccuracy.high,
        timeLimit: ShelterConstants.gpsTimeout,
      );
    } on TimeoutException {
      debugPrint('[ShelterMapVM] high-accuracy timed out after '
          '${ShelterConstants.gpsTimeout.inSeconds}s, retrying medium...');
      try {
        userPosition = await _resolvePosition(
          accuracy: LocationAccuracy.medium,
          timeLimit: ShelterConstants.gpsFallbackTimeout,
        );
      } catch (e) {
        debugPrint('[ShelterMapVM] medium-accuracy fallback failed: $e');
        gpsFailure = GpsFailureReason.timeout;
        userPosition = null;
      }
    } catch (e) {
      debugPrint('[ShelterMapVM] position resolve failed: $e');
      gpsFailure = GpsFailureReason.unknown;
      userPosition = null;
    }

    if (!_disposed) notifyListeners();
    return userPosition != null;
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
  ///
  /// Shelters are ranked from the user's GPS position when available;
  /// otherwise we fall back to a Bangladesh centre (Dhaka) so the panel
  /// is still usable — and division/district chips still render — even
  /// without a location fix.
  void toggleSearchPanel() {
    if (showSearchPanel) {
      showSearchPanel = false;
      notifyListeners();
      return;
    }
    final lat = userPosition?.latitude ?? ShelterConstants.fallbackLat;
    final lon = userPosition?.longitude ?? ShelterConstants.fallbackLon;
    rankedShelters = nearestShelters(
      lat: lat,
      lon: lon,
      all: shelters,
      k: shelters.length,
    );
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

  /// AI safety-ranking (Option 2 in docs/AI-MAP-FEATURES.md).
  ///
  /// After [toggleSearchPanel] computes the distance-ranked list, this
  /// method optionally fetches live hazards and asks the model to
  /// re-order the shelters safest-first. On ANY failure (no model,
  /// no hazards, model error, unparseable response) the distance-only
  /// ranking is kept — the map never blocks.
  ///
  /// Safe to call when [showSearchPanel] is false or [rankedShelters]
  /// is empty (no-op).
  Future<void> applyAiRanking() async {
    if (_disposed) return;
    if (!showSearchPanel || rankedShelters.isEmpty) return;
    if (userPosition == null) return;

    // Fetch live hazards in parallel. Both are best-effort — null on
    // offline / failure.
    final isOnline = _connectivity.isOnline;
    final results = await Future.wait([
      EonetService.fetchOpenHazards(isOnline: isOnline),
      GdacsService.fetchBangladeshAlerts(isOnline: isOnline),
    ]);
    final hazards = results[0] as List<EonetEvent>?;
    final alerts = results[1] as List<GdacsAlert>?;

    final prompt = ShelterSafetyRanker.buildPrompt(
      userLat: userPosition!.latitude,
      userLon: userPosition!.longitude,
      candidates: rankedShelters,
      hazards: hazards,
      alerts: alerts,
    );
    // No hazards or only one shelter → keep distance ranking.
    if (prompt == null || model == null) return;

    try {
      final response = await model!.generate(prompt);
      if (_disposed) return;
      final reordered = ShelterSafetyRanker.parseResponse(
          response, rankedShelters);
      if (reordered != null) {
        rankedShelters = reordered;
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('[ShelterMapVM] AI ranking failed, keeping distance order: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _routeService.dispose();
    super.dispose();
  }
}
