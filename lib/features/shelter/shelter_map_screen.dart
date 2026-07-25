import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../admin/campaign_request.dart';
import '../chat/chat_repository.dart';
import 'cached_tile_provider.dart';
import 'nearest_shelter.dart';
import 'shelter_brief_builder.dart';
import 'shelter_constants.dart';
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

  late final ShelterMapViewModel _vm = ShelterMapViewModel(
    model: modelManager,
  );

  // Slow breathing pulse on the user-location dot. 1.4s opacity
  // 0.5↔1.0 per design.md §7.3 — the one piece of liveliness on an
  // otherwise static map. Animations belong in the widget layer (close
  // to the TickerProvider's mount lifecycle), not in the VM.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ShelterConstants.pulseDuration,
  )..repeat(reverse: true);

  StreamSubscription<bool>? _connSub;
  double _currentZoom = 11.0;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onVmChanged);
    campaignRequestService.addListener(_onCampaignChanged);
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
    campaignRequestService.removeListener(_onCampaignChanged);
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onCampaignChanged() {
    if (mounted) setState(() {});
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
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(ShelterConstants.mapFitPadding),
        ),
      );
    } else if (_vm.routePoints.isEmpty) {
      _lastFittedRouteLength = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shelterTitle),
        actions: [
          IconButton(
            tooltip: l10n.shelterSearchTooltip,
            icon: Icon(_vm.showSearchPanel ? Icons.close : Icons.search),
            onPressed: () {
              _vm.toggleSearchPanel();
              // Fire the AI safety-ranking after the panel opens so the
              // ranked list reflects live hazard proximity + capacity.
              if (_vm.showSearchPanel) {
                _vm.applyAiRanking();
              }
            },
          ),
          if (_vm.selectedShelter != null)
            IconButton(
              tooltip: l10n.shelterClearRoute,
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
                            .withValues(alpha: ShelterConstants.bannerBgAlpha),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                      alpha:
                                          ShelterConstants.bannerFgAlpha),
                              size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.shelterOfflineBanner,
                              style: const TextStyle(fontSize: 13),
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
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.shelterMapView),
                      icon: const Icon(Icons.map_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.shelterListView),
                      icon: const Icon(Icons.list_rounded, size: 18),
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
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _vm.userPosition != null
                ? LatLng(
                    _vm.userPosition!.latitude, _vm.userPosition!.longitude)
                : const LatLng(23.8, 90.4),
            initialZoom: _vm.userPosition != null
                ? ShelterConstants.zoomWithUser
                : ShelterConstants.zoomWithoutUser,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                setState(() => _currentZoom = position.zoom);
              }
            },
          ),
          children: [
            // ── Always show tiles (cached tiles available offline) ──
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.shongjog.app',
              tileProvider: tileCacheProvider,
            ),
            if (_vm.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _vm.routePoints,
                color: ShongjogTheme.ocean,
                strokeWidth: ShelterConstants.routeStrokeWidth,
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
                // ── Approved campaign markers (orange, distinct from blue shelters)
                ...campaignRequestService.approvedRequests.map((c) => Marker(
                      point: LatLng(c.latitude, c.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showCampaignSheet(c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: ShongjogTheme.alert.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            c.type == CampaignType.rescueOperation
                                ? Icons.search_rounded
                                : Icons.volunteer_activism_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ),
        if (!_vm.isOnline) const OfflineBanner(),
        // ── Zoom controls ──
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapZoomButton(
                icon: Icons.add_rounded,
                tooltip: l10n.shelterZoomIn,
                onTap: () {
                  final newZoom = (_currentZoom + 1).clamp(1.0, 18.0);
                  setState(() => _currentZoom = newZoom);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
              const SizedBox(height: 4),
              _MapZoomButton(
                icon: Icons.remove_rounded,
                tooltip: l10n.shelterZoomOut,
                onTap: () {
                  final newZoom = (_currentZoom - 1).clamp(1.0, 18.0);
                  setState(() => _currentZoom = newZoom);
                  _mapController.move(_mapController.camera.center, newZoom);
                },
              ),
            ],
          ),
        ),
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
              onPoiSelect: (lat, lon, label) {
                // Drop a pin on the map for the selected POI / place.
                _vm.toggleSearchPanel();
                _mapController.move(LatLng(lat, lon), 14);
              },
              userLat: _vm.userPosition?.latitude,
              userLon: _vm.userPosition?.longitude,
            ),
          ),
      ],
    );
  }

  void _showShelterSheet(Shelter s) {
    final l10n = AppLocalizations.of(context);
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
                _row(l10n.shelterDistLabel, '${km.toStringAsFixed(1)} ${l10n.shelterKm}'),
              if (s.capacity != null)
                _row(l10n.shelterCapacityLabel, '${s.capacity} ${l10n.shelterPeopleUnit}'),
              _row(l10n.shelterSource, s.source),
              _row('GPS',
                  '${s.lat.toStringAsFixed(4)}, ${s.lon.toStringAsFixed(4)}'),
              const SizedBox(height: 16),
              // AI risk brief — one warm Bangla sentence from the model.
              // Falls back to a deterministic sentence if the model is
              // offline or fails. Shows a spinner while loading.
              _AiBriefRow(
                shelter: RankedShelter(s, km ?? 0),
                userLat: _vm.userPosition?.latitude,
                userLon: _vm.userPosition?.longitude,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCampaignSheet(CampaignRequest c) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ShongjogTheme.alert.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    c.type == CampaignType.rescueOperation
                        ? Icons.search_rounded
                        : Icons.volunteer_activism_rounded,
                    color: ShongjogTheme.alert,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.type.label(context),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ShongjogTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.shelterApproved,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ShongjogTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row(l10n.shelterAddress, c.address),
            if (c.landmark.isNotEmpty) _row(l10n.shelterLandmark, c.landmark),
            _row('GPS', '${c.latitude.toStringAsFixed(4)}, ${c.longitude.toStringAsFixed(4)}'),
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.shelterDesc,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(c.description, style: TextStyle(fontSize: 14, color: cs.onSurface)),
            ],
          ],
        ),
      ),
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

// ── Map zoom control button ──────────────────────────────────
class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: cs.onSurface, size: 24),
          ),
        ),
      ),
    );
  }
}

/// AI risk-brief row for the tapped-shelter bottom sheet.
///
/// Loads asynchronously when the sheet opens. Shows the deterministic
/// fallback immediately (so the sheet never has an empty section),
/// then replaces it with the model's one-sentence Bangla brief when
/// generation completes. On failure, keeps the fallback.
class _AiBriefRow extends StatefulWidget {
  final RankedShelter shelter;
  final double? userLat;
  final double? userLon;

  const _AiBriefRow({
    required this.shelter,
    this.userLat,
    this.userLon,
  });

  @override
  State<_AiBriefRow> createState() => _AiBriefRowState();
}

class _AiBriefRowState extends State<_AiBriefRow> {
  String? _brief;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBrief();
  }

  Future<void> _loadBrief() async {
    // Start with the deterministic fallback.
    final fallback = ShelterBriefBuilder.fallbackBrief(shelter: widget.shelter);
    if (!mounted) return;
    setState(() {
      _brief = fallback;
      _loading = true;
    });

    // Try the model.
    try {
      final prompt = ShelterBriefBuilder.buildPrompt(
        userLat: widget.userLat,
        userLon: widget.userLon,
        shelter: widget.shelter,
      );
      if (prompt != null && modelManager.isReady) {
        final answer = await modelManager.generate(prompt);
        final cleaned = ChatRepository.truncateAtTurnMarker(answer);
        if (!mounted) return;
        if (cleaned.trim().isNotEmpty) {
          setState(() {
            _brief = cleaned;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Keep the fallback.
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI ঝুঁকি মূল্যায়ন',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (_loading && _brief != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _brief!,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: cs.primary),
                      ),
                    ],
                  )
                else
                  Text(
                    _brief ?? '...',
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
