import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'cached_tile_provider.dart';
import 'nearest_shelter.dart';
import 'osrm_route_service.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';
import 'widgets/gps_banner.dart';
import 'widgets/nearest_card.dart';
import 'widgets/offline_banner.dart';
import 'widgets/shelter_list_view.dart';
import 'widgets/shelter_marker.dart' show buildShelterMarker;
import 'widgets/shelter_route_info_card.dart';
import 'widgets/shelter_search_panel.dart';
import 'widgets/user_marker.dart' show buildUserMarker;

/// Shelter map with GPS-based nearest ranking, interactive routing, search,
/// and offline-aware tile rendering.
///
/// Connectivity-aware: when online, renders full OSM tiles and offers
/// driving-route navigation via OSRM. When offline, marker positions and
/// search lists still work (haversine distance), but routing falls back
/// to a straight line and tiles may not render.
///
/// Map/list view toggles via the AppBar SegmentedButton. Search is a
/// full-screen overlay. Routing fires only when online; offline taps
/// draw a straight line immediately so the user still sees the path.
class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen>
    with TickerProviderStateMixin {
  late Future<List<Shelter>> _sheltersFuture;
  Position? _userPosition;
  String? _gpsError;
  bool _isOnline = true;
  bool _showMap = true;
  StreamSubscription<bool>? _connSub;
  final MapController _mapController = MapController();

  // Slow breathing pulse on the user-location dot. 1.4s opacity 0.5↔1.0
  // per design.md §7.3 — the one piece of liveliness on a static map.
  late final AnimationController _pulse;

  // Route state (added from sehab's branch). Route is computed by OSRM
  // when online, or by haversine straight-line fallback when offline.
  Shelter? _selectedShelter;
  List<LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  bool _loadingRoute = false;

  // Search state (added from sehab's branch). When true, the full-screen
  // search overlay is shown with a text-filtered list ranked by
  // distance from the user.
  bool _showSearchPanel = false;
  List<RankedShelter> _rankedShelters = const [];

  // OSRM HTTP client wrapper. Replaced by the ViewModel in the
  // upcoming arch refactor; for now lives here with explicit dispose.
  late final OsrmRouteService _routeService = OsrmRouteService();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sheltersFuture = ShelterRepository().loadAll();
    _resolveGps();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    _isOnline = await ConnectivityHelper.isOnline();
    if (mounted) setState(() {});
    _connSub = ConnectivityHelper.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _connSub?.cancel();
    _routeService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsError = 'GPS অনুমতি নেই');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'GPS অনুমতি চিরতরে নিষিদ্ধ');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            // Bumped from medium to high — routing needs accurate
            // start point so OSRM doesn't snap the user onto a road.
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10)),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'GPS পাওয়া যায়নি');
    }
  }

  // ─── Routing ──────────────────────────────────────────────────────
  // Fetch a driving route from the user's GPS to the chosen shelter.
  // Network-gated by _isOnline so offline taps fall through to
  // _fallbackStraightLine immediately (no 8-s timeout for offline).
  // HTTP/JSON parsing lives in [OsrmRouteService] so it is unit-
  // testable without spinning up the widget tree.

  Future<void> _fetchRoute(Shelter shelter) async {
    if (_userPosition == null) return;

    setState(() {
      _loadingRoute = true;
      _selectedShelter = shelter;
    });

    if (!_isOnline) {
      _fallbackStraightLine(shelter);
      return;
    }

    final route = await _routeService.fetchRoute(
      from: LatLng(_userPosition!.latitude, _userPosition!.longitude),
      to: LatLng(shelter.lat, shelter.lon),
    );
    if (!mounted) return;
    if (route == null) {
      _fallbackStraightLine(shelter);
      return;
    }
    setState(() {
      _routePoints = route.points;
      _routeDistanceKm = route.distanceKm;
      _loadingRoute = false;
    });
    _fitMapToRoute(route.points);
  }

  void _fallbackStraightLine(Shelter shelter) {
    final userLatLng =
        LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final shelterLatLng = LatLng(shelter.lat, shelter.lon);
    final dist = haversineKm(
      userLatLng.latitude,
      userLatLng.longitude,
      shelterLatLng.latitude,
      shelterLatLng.longitude,
    );
    if (!mounted) return;
    setState(() {
      _routePoints = [userLatLng, shelterLatLng];
      _routeDistanceKm = dist;
      _loadingRoute = false;
    });
    _fitMapToRoute(_routePoints);
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.length < 2) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _selectedShelter = null;
      _routePoints = const [];
      _routeDistanceKm = null;
    });
  }

  // ─── Search ───────────────────────────────────────────────────────

  void _toggleSearchPanel() {
    if (_showSearchPanel) {
      setState(() => _showSearchPanel = false);
      return;
    }
    _sheltersFuture.then((shelters) {
      if (_userPosition != null && mounted) {
        final ranked = nearestShelters(
          lat: _userPosition!.latitude,
          lon: _userPosition!.longitude,
          all: shelters,
          k: shelters.length,
        );
        setState(() {
          _rankedShelters = ranked;
          _showSearchPanel = true;
        });
      }
    });
  }

  void _onSearchSelect(RankedShelter ranked) {
    setState(() => _showSearchPanel = false);
    _fetchRoute(ranked.shelter);
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('নিকটস্থ আশ্রয়কেন্দ্র'),
        actions: [
          IconButton(
            tooltip: 'আশ্রয় খুঁজুন',
            icon: Icon(_showSearchPanel ? Icons.close : Icons.search),
            onPressed: _toggleSearchPanel,
          ),
          if (_selectedShelter != null)
            IconButton(
              tooltip: 'রুট মুছুন',
              icon: const Icon(Icons.alt_route),
              onPressed: _clearRoute,
            ),
          if (_gpsError == null && _userPosition == null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                if (!_isOnline)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                              size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'অফলাইন — টাইলস নেই, মার্কার আছে',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('মানচিত্র'),
                      icon: Icon(Icons.map_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('তালিকা'),
                      icon: Icon(Icons.list_rounded, size: 18),
                    ),
                  ],
                  selected: {_showMap},
                  onSelectionChanged: (s) =>
                      setState(() => _showMap = s.first),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Shelter>>(
        future: _sheltersFuture,
        builder: (_, snap) {
          if (snap.hasError) return _errorState();
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shelters = snap.data!;
          final ranked = _userPosition != null
              ? nearestShelters(
                  lat: _userPosition!.latitude,
                  lon: _userPosition!.longitude,
                  all: shelters,
                  k: shelters.length,
                )
              : null;

          if (_showMap) {
            return _mapView(shelters, ranked);
          } else {
            return ShelterListView(
              shelters: ranked ??
                  shelters.map((s) => RankedShelter(s, 0)).toList(),
              onTap: (s) => _showShelterSheet(s as Shelter),
            );
          }
        },
      ),
    );
  }

  Widget _mapView(List<Shelter> shelters, List<RankedShelter>? ranked) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userPosition != null
                ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                : const LatLng(23.8, 90.4),
            initialZoom: _userPosition != null ? 11 : 8,
            backgroundColor: _isOnline
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: [
            if (_isOnline)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shongjog.app',
              ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: ShongjogTheme.ocean,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_userPosition != null)
                  buildUserMarker(
                    LatLng(
                        _userPosition!.latitude, _userPosition!.longitude),
                    _pulse,
                  ),
                ...shelters.map((s) => buildShelterMarker(
                      s,
                      _selectedShelter?.name == s.name,
                      () => _fetchRoute(s),
                    )),
              ],
            ),
          ],
        ),
        if (!_isOnline) const OfflineBanner(),
        if (_selectedShelter != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ShelterRouteInfoCard(
              selected: _selectedShelter!,
              loading: _loadingRoute,
              distanceKm: _routeDistanceKm,
              onCancel: _clearRoute,
              onDetails: () => _showShelterSheet(_selectedShelter!),
            ),
          )
        else if (ranked != null && ranked.isNotEmpty && !_showSearchPanel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: NearestCard(
              top3: ranked.take(3).toList(),
              onTapRow: (s) => _fetchRoute(s as Shelter),
            ),
          )
        else if (_gpsError != null)
          GpsBanner(
            error: _gpsError,
            stackedBelowOfflinePill: !_isOnline,
          ),
        if (_showSearchPanel)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShelterSearchPanel(
              ranked: _rankedShelters,
              onSelect: _onSearchSelect,
              onClose: _toggleSearchPanel,
            ),
          ),
      ],
    );
  }

  void _showShelterSheet(Shelter s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // Prefer the routed distance (from OSRM or fallback) since
        // it represents the actual travel distance once a route has
        // been selected; fall back to the haversine great-circle.
        final routedKm = _routeDistanceKm;
        final fallbackKm = _userPosition == null
            ? null
            : haversineKm(_userPosition!.latitude, _userPosition!.longitude,
                s.lat, s.lon);
        final km = routedKm ?? fallbackKm;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.nameBn.isNotEmpty ? s.nameBn : s.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.nameBn.isNotEmpty && s.name.isNotEmpty)
                Text(s.name,
                    style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              if (km != null) _row('দূরত্ব', '${km.toStringAsFixed(1)} কিমি'),
              if (s.capacity != null)
                _row('ধারণক্ষমতা', '${s.capacity} জন'),
              _row('উৎস', s.source),
              _row(
                  'GPS',
                  '${s.lat.toStringAsFixed(4)}, ${s.lon.toStringAsFixed(4)}'),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(k,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('মানচিত্র লোড করা যায়নি'),
          ],
        ),
      ),
    );
  }
}
