import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'nearest_shelter.dart';
import 'shelter_model.dart';
import 'shelter_repository.dart';

/// Shelter map with GPS-based nearest ranking, interactive routing, and search.
class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen> {
  late Future<List<Shelter>> _sheltersFuture;
  Position? _userPosition;
  String? _gpsError;
  final MapController _mapController = MapController();

  // Route state
  Shelter? _selectedShelter;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  bool _loadingRoute = false;

  // Search state
  bool _showSearchPanel = false;
  List<RankedShelter> _rankedShelters = [];

  @override
  void initState() {
    super.initState();
    _sheltersFuture = ShelterRepository().loadAll();
    _resolveGps();
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
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10)),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'GPS পাওয়া যায়নি');
    }
  }

  // ─── Routing ──────────────────────────────────────────────────────

  Future<void> _fetchRoute(Shelter shelter) async {
    if (_userPosition == null) return;

    setState(() {
      _loadingRoute = true;
    });

    final userLatLng = LatLng(_userPosition!.latitude, _userPosition!.longitude);
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
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          final distMeters = (route['distance'] as num).toDouble();
          setState(() {
            _routePoints = points;
            _routeDistanceKm = distMeters / 1000.0;
            _selectedShelter = shelter;
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
    final userLatLng = LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final shelterLatLng = LatLng(shelter.lat, shelter.lon);
    final dist = haversineKm(
      userLatLng.latitude, userLatLng.longitude,
      shelterLatLng.latitude, shelterLatLng.longitude,
    );
    setState(() {
      _routePoints = [userLatLng, shelterLatLng];
      _routeDistanceKm = dist;
      _selectedShelter = shelter;
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
      _routePoints = [];
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
        ],
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

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userPosition != null
                      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                      : const LatLng(23.8, 90.4),
                  initialZoom: _userPosition != null ? 11 : 7,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ShongjogTheme.ocean,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.person,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ...shelters.map((s) {
                        final isSelected = _selectedShelter?.name == s.name;
                        return Marker(
                          point: LatLng(s.lat, s.lon),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _fetchRoute(s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ShongjogTheme.alert
                                    : ShongjogTheme.ocean,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: isSelected ? 8 : 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.shield,
                                color: Colors.white,
                                size: isSelected ? 26 : 22,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // Route info card
              if (_selectedShelter != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _routeInfoCard(),
                )
              // Nearest shelters card (when no route active)
              else if (ranked != null && ranked.isNotEmpty && !_showSearchPanel)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _nearestCard(ranked.take(3).toList()),
                ),

              // GPS banner
              if (_userPosition == null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _gpsBanner(),
                ),

              // Search panel
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
        },
      ),
    );
  }

  // ─── Route info card ──────────────────────────────────────────────

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
                            style: TextStyle(
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
                  Text('রুট খুঁজছি...',
                      style: TextStyle(fontSize: 14)),
                ],
              )
            else ...[
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
            ],
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

  // ─── Nearest card ─────────────────────────────────────────────────

  Widget _nearestCard(List<RankedShelter> top3) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShongjogTheme.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('নিকটতম ৩টি',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ShongjogTheme.inkSecondary)),
            const SizedBox(height: 4),
            ...top3.map((r) => _shelterRow(r)),
          ],
        ),
      ),
    );
  }

  Widget _shelterRow(RankedShelter ranked) {
    final s = ranked.shelter;
    final bnName = s.nameBn.isNotEmpty ? s.nameBn : s.name;
    return InkWell(
      onTap: () => _fetchRoute(s),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: ShongjogTheme.ocean, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bnName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${ranked.km.toStringAsFixed(1)} কিমি',
              style: TextStyle(
                  fontSize: 13, color: ShongjogTheme.inkSecondary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: ShongjogTheme.inkMuted),
          ],
        ),
      ),
    );
  }

  // ─── Search panel ─────────────────────────────────────────────────

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
                                  color: ShongjogTheme.ocean
                                      .withValues(alpha: 0.1),
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

  // ─── Bottom sheet ─────────────────────────────────────────────────

  void _showShelterSheet(Shelter s) {
    final km = _routeDistanceKm;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: ShongjogTheme.ocean, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.nameBn.isNotEmpty ? s.nameBn : s.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.nameBn.isNotEmpty && s.name.isNotEmpty)
                Text(s.name,
                    style: TextStyle(
                        fontSize: 14, color: ShongjogTheme.inkSecondary)),
              const SizedBox(height: 16),
              if (km != null) _row('দূরত্ব', '${km.toStringAsFixed(1)} কিমি'),
              if (s.capacity != null) _row('ধারণক্ষমতা', '${s.capacity} জন'),
              _row('উৎস', s.source),
              _row('GPS',
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
                      fontSize: 13, color: ShongjogTheme.inkSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  // ─── GPS banner ───────────────────────────────────────────────────

  Widget _gpsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off,
            color: _gpsError != null
                ? ShongjogTheme.alert
                : ShongjogTheme.inkSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gpsError ??
                  'সমগ্র বাংলাদেশ দেখানো হচ্ছে — GPS থেকে দূরত্ব নির্ণয় করা যাবে না',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 56, color: ShongjogTheme.inkMuted),
            const SizedBox(height: 16),
            const Text('মানচিত্র লোড করা যায়নি'),
          ],
        ),
      ),
    );
  }
}
