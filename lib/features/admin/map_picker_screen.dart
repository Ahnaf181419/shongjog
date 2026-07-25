import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../shelter/cached_tile_provider.dart';

/// Full-screen interactive map where the user can search by area,
/// tap to drop a pin, use zoom controls, and confirm coordinates.
///
/// Returns the chosen [LatLng] via [Navigator.pop], or null if cancelled.
class MapPickerScreen extends StatefulWidget {
  /// Optional initial location to center the map on.
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  LatLng? _selectedPoint;
  bool _loadingGps = true;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showResults = false;
  double _currentZoom = 13.0;
  Timer? _debounce;

  // Default: Dhaka
  static const _defaultCenter = LatLng(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedPoint = widget.initialLocation;
      _loadingGps = false;
    } else {
      _tryLocateUser();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _tryLocateUser() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final userLoc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _selectedPoint = userLoc;
          _loadingGps = false;
        });
        _mapController.move(userLoc, _currentZoom);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() => _selectedPoint = latLng);
  }

  void _confirm() {
    if (_selectedPoint == null) return;
    Navigator.pop<LatLng>(context, _selectedPoint);
  }

  // ── Area search via Nominatim (OpenStreetMap) ──────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchArea(query);
    });
  }

  Future<void> _searchArea(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&accept-language=bn',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'com.shongjog.app/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.cast<Map<String, dynamic>>();
          _showResults = _searchResults.isNotEmpty;
        });
      }
    } catch (_) {
      // Search failure is non-critical
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lon = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;

    final point = LatLng(lat, lon);
    setState(() {
      _selectedPoint = point;
      _showResults = false;
      _searchResults = [];
      _searchController.text = result['display_name'] ?? '';
    });
    _searchFocusNode.unfocus();
    _mapController.move(point, 15.0);
  }

  // ── Zoom controls ─────────────────────────────────────────
  void _zoomIn() {
    final newZoom = (_currentZoom + 1).clamp(1.0, 18.0);
    setState(() => _currentZoom = newZoom);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 1).clamp(1.0, 18.0);
    setState(() => _currentZoom = newZoom);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).mapPickerTitle),
        actions: [
          if (_selectedPoint != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selectedPoint!.latitude.toStringAsFixed(4)}, ${_selectedPoint!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ?? _defaultCenter,
              initialZoom: _currentZoom,
              onTap: _onMapTap,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _currentZoom = position.zoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shongjog.app',
                tileProvider: tileCacheProvider,
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 48,
                      height: 48,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        builder: (_, t, _) {
                          return Transform.scale(
                            scale: t,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.error,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 24 * t,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── GPS loading indicator ──
          if (_loadingGps)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: LinearProgressIndicator(minHeight: 3),
              ),
            ),

          // ── Area search bar ──
          Positioned(
            top: _loadingGps ? 20 : 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).mapPickerSearchHint,
                      prefixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showResults = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _searchArea(_searchController.text),
                  ),
                ),
                // ── Search results dropdown ──
                if (_showResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(
                          height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final displayName =
                            result['display_name'] as String? ?? '';
                        // Show shorter version: first two comma-separated parts
                        final shortName = displayName.split(',').take(2).join(',').trim();
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.location_on_outlined,
                              color: cs.primary, size: 20),
                          title: Text(
                            shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: displayName != shortName
                              ? Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant),
                                )
                              : null,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Zoom controls ──
          Positioned(
            right: 12,
            top: _loadingGps ? 80 : 72,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add_rounded,
                  tooltip: AppLocalizations.of(context).mapPickerZoomIn,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.remove_rounded,
                  tooltip: AppLocalizations.of(context).mapPickerZoomOut,
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.my_location_rounded,
                  tooltip: AppLocalizations.of(context).mapPickerMyLocation,
                  onTap: _tryLocateUser,
                ),
              ],
            ),
          ),

          // ── Instruction overlay (when no pin) ──
          if (_selectedPoint == null && !_showResults)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).mapPickerInstruction,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Confirm button ──
          if (_selectedPoint != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check_rounded),
                label: Text(AppLocalizations.of(context).mapPickerConfirm),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Zoom control button ──────────────────────────────────────
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomButton({
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
