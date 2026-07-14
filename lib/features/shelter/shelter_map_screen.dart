import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'cached_tile_provider.dart';
import 'nearest_shelter.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';

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
  // _searchPanel overlay is shown with a text-filtered list ranked by
  // distance from the user.
  bool _showSearchPanel = false;
  List<RankedShelter> _rankedShelters = const [];

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

  // ─── Routing (added from sehab's branch) ──────────────────────────
  // Fetch a driving route from the user's GPS to the chosen shelter.
  // Network-gated by _isOnline so offline taps fall through to
  // _fallbackStraightLine immediately (no 8-s timeout for offline).

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

    final userLatLng =
        LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final shelterLatLng = LatLng(shelter.lat, shelter.lon);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${userLatLng.longitude},${userLatLng.latitude};'
        '${shelterLatLng.longitude},${shelterLatLng.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] != null) {
          final route = (data['routes'] as List).first as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = (geometry['coordinates'] as List);
          final points = coords
              .map((c) =>
                  LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          final distMeters = (route['distance'] as num).toDouble();
          if (!mounted) return;
          setState(() {
            _routePoints = points;
            _routeDistanceKm = distMeters / 1000.0;
            _loadingRoute = false;
          });
          _fitMapToRoute(points);
          return;
        }
      }
      _fallbackStraightLine(shelter);
    } catch (_) {
      _fallbackStraightLine(shelter);
    }
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

  // ─── Search (added from sehab's branch) ───────────────────────────
  // Full-screen overlay listing all shelters ranked by distance from
  // the user, with a text-filter. Tapping a row fetches a route
  // (or straight line if offline).

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
            return _listView(ranked ??
                shelters.map((s) => RankedShelter(s, 0)).toList());
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
                  Marker(
                    point: LatLng(_userPosition!.latitude,
                        _userPosition!.longitude),
                    width: 56,
                    height: 56,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: ShongjogTheme.ocean.withValues(
                                    alpha: 0.18 + 0.18 * _pulse.value),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: ShongjogTheme.ocean,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.3),
                                      blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ...shelters.map((s) {
                  final isSelected =
                      _selectedShelter != null && _selectedShelter!.name == s.name;
                  return Marker(
                    point: LatLng(s.lat, s.lon),
                    width: isSelected ? 60 : 44,
                    height: isSelected ? 60 : 44,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _fetchRoute(s),
                        child: Container(
                          width: isSelected ? 60 : 44,
                          height: isSelected ? 60 : 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ShongjogTheme.alert
                                : ShongjogTheme.success.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isSelected ? 0.3 : 0.2),
                                blurRadius: isSelected ? 8 : 3,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: isSelected ? 32 : 24,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        if (!_isOnline) _offlineBanner(),
        if (_selectedShelter != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _routeInfoCard(),
          )
        else if (ranked != null && ranked.isNotEmpty && !_showSearchPanel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _nearestCard(ranked.take(3).toList()),
          )
        else if (_gpsError != null)
          Positioned(
            top: _isOnline ? 16 : 56,
            left: 16,
            right: 16,
            child: _gpsBanner(),
          ),
        if (_showSearchPanel)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: _searchPanel(shelters),
          ),
      ],
    );
  }

  // ─── Route info card (added from sehab's branch) ──────────────────
  // Bottom card showing the currently-routed shelter, distance + actions.
  // "বিস্তারিত" opens the full shelter sheet; "বাতিল" clears the route.

  Widget _routeInfoCard() {
    final shelter = _selectedShelter!;
    final bnName = shelter.nameBn.isNotEmpty ? shelter.nameBn : shelter.name;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShongjogTheme.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ShongjogTheme.ocean.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield,
                      color: ShongjogTheme.ocean, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bnName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (shelter.capacity != null)
                        Text('ধারণক্ষমতা: ${shelter.capacity} জন',
                            style: const TextStyle(
                                fontSize: 13,
                                color: ShongjogTheme.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingRoute)
              const Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('রুট খুঁজছি...', style: TextStyle(fontSize: 14)),
                ],
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ShongjogTheme.ocean.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route,
                        color: ShongjogTheme.ocean, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_routeDistanceKm!.toStringAsFixed(1)} কিমি',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ShongjogTheme.ocean),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearRoute,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('বাতিল'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShongjogTheme.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showShelterSheet(shelter),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('বিস্তারিত'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search panel (added from sehab's branch) ─────────────────────
  // Full-screen overlay listing ranked shelters with a filter TextField.
  // Tapping a row calls _onSearchSelect, which closes the panel and
  // starts routing.

  Widget _searchPanel(List<Shelter> shelters) {
    final queryCtrl = TextEditingController();
    List<RankedShelter> displayed = _rankedShelters;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        void filter(String q) {
          final query = q.trim().toLowerCase();
          if (query.isEmpty) {
            setLocalState(() => displayed = _rankedShelters);
            return;
          }
          setLocalState(() {
            displayed = _rankedShelters.where((r) {
              final s = r.shelter;
              return s.name.toLowerCase().contains(query) ||
                  s.nameBn.contains(query) ||
                  s.source.toLowerCase().contains(query);
            }).toList();
          });
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: queryCtrl,
                    autofocus: true,
                    onChanged: filter,
                    decoration: InputDecoration(
                      hintText: 'আশ্রয়কেন্দ্র খুঁজুন...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          queryCtrl.clear();
                          filter('');
                          _toggleSearchPanel();
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: displayed.isEmpty
                      ? const Center(
                          child: Text('কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: displayed.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = displayed[i];
                            final s = r.shelter;
                            final bnName =
                                s.nameBn.isNotEmpty ? s.nameBn : s.name;
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      ShongjogTheme.ocean.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shield,
                                    color: ShongjogTheme.ocean, size: 22),
                              ),
                              title: Text(bnName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${r.km.toStringAsFixed(1)} কিমি'
                                '${s.capacity != null ? '  •  ${s.capacity} জন' : ''}'
                                '  •  ${s.source}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _onSearchSelect(r),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _listView(List<RankedShelter> shelters) {
    if (shelters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('কোনো আশ্রয়কেন্দ্রের তথ্য নেই'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: shelters.length,
      itemBuilder: (_, i) {
        final r = shelters[i];
        final s = r.shelter;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: ShongjogTheme.iconBadge(context),
              child: const Icon(Icons.shield_outlined, size: 22),
            ),
            title: Text(
              s.nameBn.isNotEmpty ? s.nameBn : s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (r.km > 0) '${r.km.toStringAsFixed(1)} কিমি',
                if (s.capacity != null) 'ধারণক্ষমতা: ${s.capacity} জন',
                if (r.km == 0 && s.capacity == null) s.source,
              ].join(' • '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showShelterSheet(s),
          ),
        );
      },
    );
  }

  Widget _offlineBanner() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ShongjogTheme.surfaceDark,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded,
                color: ShongjogTheme.oceanBright, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'অফলাইন — মানচিত্রের টাইলস লোড হবে না, তবে আশ্রয়কেন্দ্রের অবস্থান দেখা যাচ্ছে',
                style: TextStyle(
                  fontSize: 14,
                  color: ShongjogTheme.inkDark.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearestCard(List<RankedShelter> top3) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('নিকটতম ৩টি',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...top3.map((r) => _shelterRow(r.shelter, r.km)),
          ],
        ),
      ),
    );
  }

  Widget _shelterRow(Shelter s, double km) {
    return InkWell(
      onTap: () => _fetchRoute(s),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.nameBn.isNotEmpty ? s.nameBn : s.name,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            Text(
              '${km.toStringAsFixed(1)} কিমি',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
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

  Widget _gpsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off,
            color: _gpsError != null
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gpsError ??
                  'সমগ্র বাংলাদেশ দেখানো হচ্ছে — GPS থেকে দূরত্ব নির্ণয় করা যাবে না',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
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
