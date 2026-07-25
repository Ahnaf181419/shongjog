import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../../../core/connectivity_provider.dart';
import '../nearest_shelter.dart';
import '../nominatim_service.dart';
import '../overpass_service.dart';
import '../semantic_search_service.dart';

/// Full-screen search overlay listing [ranked] shelters with a live
/// text filter. Tapping a row calls [onSelect]; the X in the suffix
/// slot (or the close action) calls [onClose].
///
/// State is owned by this widget: it allocates and disposes its own
/// [TextEditingController] for the filter field — preventing the
/// "controller created in a rebuild-able method" leak that the
/// inline version in the State class had.
class ShelterSearchPanel extends StatefulWidget {
  final List<RankedShelter> ranked;
  final ValueChanged<RankedShelter> onSelect;
  final VoidCallback onClose;

  /// Optional callback for when a semantic-search POI (hospital,
  /// pharmacy, etc. from Overpass) or a geocoded place (from
  /// Nominatim) is selected. When null, the semantic search text
  /// field is not shown.
  final void Function(double lat, double lon, String label)? onPoiSelect;

  /// Optional user position for POI radius search. When null, POI
  /// queries can't run (the Overpass API needs a centre point).
  final double? userLat;
  final double? userLon;

  const ShelterSearchPanel({
    super.key,
    required this.ranked,
    required this.onSelect,
    required this.onClose,
    this.onPoiSelect,
    this.userLat,
    this.userLon,
  });

  @override
  State<ShelterSearchPanel> createState() => _ShelterSearchPanelState();
}

class _ShelterSearchPanelState extends State<ShelterSearchPanel> {
  final TextEditingController _ctrl = TextEditingController();
  late List<RankedShelter> _displayed = widget.ranked;

  // Semantic search state.
  Timer? _debounce;
  SemanticSearchResult? _semanticResult;
  List<dynamic>? _semanticHits;
  bool _semanticLoading = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ShelterSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.ranked, oldWidget.ranked)) {
      _displayed = widget.ranked;
      _refresh();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onSearchChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _refresh();
    // Semantic search: debounce + classify + fetch.
    final query = _ctrl.text.trim();
    if (query.isEmpty || widget.onPoiSelect == null) {
      setState(() {
        _semanticResult = null;
        _semanticHits = null;
        _semanticLoading = false;
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSemanticSearch(query);
    });
  }

  Future<void> _runSemanticSearch(String query) async {
    final result = SemanticSearchService.classify(query);
    if (!mounted) return;
    setState(() {
      _semanticResult = result;
      _semanticLoading = true;
      _semanticHits = null;
    });

    final isOnline = connectivityProvider.isOnline;
    try {
      switch (result.intent) {
        case SearchIntent.shelterFilter:
          // No external search needed — the shelter filter above
          // already handles this.
          setState(() => _semanticLoading = false);
          break;
        case SearchIntent.geocode:
          final hits = await NominatimService.search(
              query: query, isOnline: isOnline);
          if (!mounted) return;
          setState(() {
            _semanticHits = hits;
            _semanticLoading = false;
          });
          break;
        case SearchIntent.poiQuery:
          if (widget.userLat == null || widget.userLon == null) {
            setState(() => _semanticLoading = false);
            return;
          }
          final hits = await OverpassService.searchPois(
            lat: widget.userLat!,
            lon: widget.userLon!,
            amenity: result.poiTag ?? 'hospital',
            isOnline: isOnline,
          );
          if (!mounted) return;
          setState(() {
            _semanticHits = hits;
            _semanticLoading = false;
          });
          break;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _semanticLoading = false);
    }
  }

  void _refresh() {
    final query = _ctrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayed = widget.ranked;
        return;
      }
      _displayed = widget.ranked.where((r) {
        final s = r.shelter;
        return s.name.toLowerCase().contains(query) ||
            s.nameBn.contains(query) ||
            s.source.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.shelterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the body: shelter list by default, semantic results when
  /// the query classified as geocode/poiQuery and returned hits.
  Widget _buildBody(BuildContext context) {
    // Semantic results take priority when we have them.
    final sem = _semanticResult;
    if (sem != null &&
        sem.intent != SearchIntent.shelterFilter &&
        widget.onPoiSelect != null) {
      return _buildSemanticSection(context);
    }

    if (_displayed.isEmpty) {
      return const Center(child: Text('কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _displayed.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _displayed[i];
        final s = r.shelter;
        final bnName = s.nameBn.isNotEmpty ? s.nameBn : s.name;
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield,
                color: ShongjogTheme.ocean, size: 22),
          ),
          title: Text(bnName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${r.km.toStringAsFixed(1)} কিমি'
            '${s.capacity != null ? '  •  ${s.capacity} জন' : ''}'
            '  •  ${s.source}',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onSelect(r),
        );
      },
    );
  }

  /// Semantic results: geocoded places or POIs from Overpass.
  Widget _buildSemanticSection(BuildContext context) {
    if (_semanticLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final hits = _semanticHits ?? [];
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('কোনো ফলাফল পাওয়া যায়নি',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            const Text('অন্য শব্দ দিয়ে চেষ্টা করুন',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        // Handle both NominatimResult and OverpassPoi.
        final h = hits[i];
        final String label;
        final double lat;
        final double lon;
        final IconData icon;
        if (h is NominatimResult) {
          label = h.displayName;
          lat = h.lat;
          lon = h.lon;
          icon = Icons.place;
        } else if (h is OverpassPoi) {
          label = h.nameBn ?? h.name;
          lat = h.lat;
          lon = h.lon;
          icon = Icons.local_hospital;
        } else {
          return const SizedBox.shrink();
        }
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ShongjogTheme.ocean, size: 22),
          ),
          title: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onPoiSelect!(lat, lon, label),
        );
      },
    );
  }
}
