import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import 'cached_tile_provider.dart';
import 'nearest_shelter.dart';
import 'shelter_map_view_model.dart';
import 'shelter_model.dart';
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
/// All state and behaviour is held by [ShelterMapViewModel]; this screen
/// is a thin view that wires AppBar actions, AppBar.bottom offline pill,
/// and the body's Stack overlays to the VM.
class ShelterMapScreen extends StatefulWidget {
  const ShelterMapScreen({super.key});
  @override
  State<ShelterMapScreen> createState() => _ShelterMapScreenState();
}

class _ShelterMapScreenState extends State<ShelterMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  // Tracks the last routePoints length we fitted the camera to. When
  // the VM's routePoints change, we re-fit. Keeps the VM free of any
  // MapController dependency.
  int _lastFittedRouteLength = 0;

  late final ShelterMapViewModel _vm = ShelterMapViewModel();

  // Slow breathing pulse on the user-location dot. 1.4s opacity
  // 0.5↔1.0 per design.md §7.3 — the one piece of liveliness on an
  // otherwise static map. Animations belong in the widget layer (close
  // to the TickerProvider's mount lifecycle), not in the VM.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onVmChanged);
    _connSub = ConnectivityHelper.onConnectivityChanged.listen(_vm.setOnline);
    // Seed the VM's online flag from the global connectivity singleton
    // so the first frame correctly hides / shows the offline pill.
    _vm.setOnline(_vm.connectivityIsOnline);
    // Kick off async init (load shelters + GPS). Done without awaiting
    // because the VM populates state and notifies.
    _vm.init();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _connSub?.cancel();
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    // Re-fit the camera when a new route is drawn (routePoints length
    // transitions from empty to non-empty). The VM doesn't know about
    // the MapController; the screen owns this side-effect.
    if (_vm.routePoints.length >= 2 &&
        _vm.routePoints.length != _lastFittedRouteLength) {
      _lastFittedRouteLength = _vm.routePoints.length;
      final bounds = LatLngBounds.fromPoints(_vm.routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } else if (_vm.routePoints.isEmpty) {
      _lastFittedRouteLength = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('নিকটস্থ আশ্রয়কেন্দ্র'),
        actions: [
          IconButton(
            tooltip: 'আশ্রয় খুঁজুন',
            icon: Icon(_vm.showSearchPanel ? Icons.close : Icons.search),
            onPressed: _vm.toggleSearchPanel,
          ),
          if (_vm.selectedShelter != null)
            IconButton(
              tooltip: 'রুট মুছুন',
              icon: const Icon(Icons.alt_route),
              onPressed: _vm.clearRoute,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                if (!_vm.isOnline)
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
                          const Expanded(
                            child: Text(
                              'অফলাইন — টাইলস নেই, মার্কার আছে',
                              style: TextStyle(fontSize: 13),
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
                  onSelectionChanged: (s) => setState(
                      () => _showMap = s.first),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (_, _) {
          if (_vm.shelters.isEmpty && _vm.gpsError == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final ranked = _vm.userPosition != null
              ? nearestShelters(
                  lat: _vm.userPosition!.latitude,
                  lon: _vm.userPosition!.longitude,
                  all: _vm.shelters,
                  k: _vm.shelters.length,
                )
              : null;

          return Column(
            children: [
              if (_vm.gpsError == null && _vm.userPosition == null)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _showMap
                    ? _buildMap(_vm.shelters, ranked)
                    : ShelterListView(
                        shelters: ranked ??
                            _vm.shelters
                                .map((s) => RankedShelter(s, 0))
                                .toList(),
                        onTap: (s) => _showShelterSheet(s as Shelter),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _showMap = true;

  Widget _buildMap(List<Shelter> shelters, List<RankedShelter>? ranked) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _vm.userPosition != null
                ? LatLng(
                    _vm.userPosition!.latitude, _vm.userPosition!.longitude)
                : const LatLng(23.8, 90.4),
            initialZoom: _vm.userPosition != null ? 11 : 8,
            backgroundColor: _vm.isOnline
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: [
            if (_vm.isOnline)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shongjog.app',
              ),
            if (_vm.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _vm.routePoints,
                    color: ShongjogTheme.ocean,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_vm.userPosition != null)
                  buildUserMarker(
                    LatLng(_vm.userPosition!.latitude,
                        _vm.userPosition!.longitude),
                    _pulse,
                  ),
                ...shelters.map((s) => buildShelterMarker(
                      s,
                      _vm.selectedShelter?.name == s.name,
                      () => _vm.fetchRoute(s),
                    )),
              ],
            ),
          ],
        ),
        if (!_vm.isOnline) const OfflineBanner(),
        if (_vm.selectedShelter != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ShelterRouteInfoCard(
              selected: _vm.selectedShelter!,
              loading: _vm.loadingRoute,
              distanceKm: _vm.routeDistanceKm,
              onCancel: _vm.clearRoute,
              onDetails: () => _showShelterSheet(_vm.selectedShelter!),
            ),
          )
        else if (ranked != null && ranked.isNotEmpty && !_vm.showSearchPanel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: NearestCard(
              top3: ranked.take(3).toList(),
              onTapRow: (s) => _vm.fetchRoute(s as Shelter),
            ),
          )
        else if (_vm.gpsError != null)
          GpsBanner(
            error: _vm.gpsError,
            stackedBelowOfflinePill: !_vm.isOnline,
          ),
        if (_vm.showSearchPanel)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShelterSearchPanel(
              ranked: _vm.rankedShelters,
              onSelect: _vm.onSearchSelect,
              onClose: _vm.toggleSearchPanel,
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
        // Prefer the routed distance; fall back to haversine.
        final routedKm = _vm.routeDistanceKm;
        final fallbackKm = _vm.userPosition == null
            ? null
            : haversineKm(_vm.userPosition!.latitude,
                _vm.userPosition!.longitude, s.lat, s.lon);
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
              if (km != null)
                _row('দূরত্ব', '${km.toStringAsFixed(1)} কিমি'),
              if (s.capacity != null)
                _row('ধারণক্ষমতা', '${s.capacity} জন'),
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
}
