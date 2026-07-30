import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

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

  /// Active division filter (`all` = no filter). Mirrors the chip-row
  /// in DirectoryScreen so the two features stay visually consistent.
  String _division = 'all';

  /// Active district filter (null = all districts within the selected
  /// division). Reset to null whenever the division changes.
  String? _district;

  // Semantic search state.
  Timer? _debounce;
  SemanticSearchResult? _semanticResult;
  List<dynamic>? _semanticHits;
  bool _semanticLoading = false;

  /// Division keys -> localized labels. Reuses the emergency-directory
  /// getters so no new l10n keys are required; the labels are just the
  /// eight division names which read the same in either feature.
  static Map<String, String> _divisions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <String, String>{
      'all': l10n.allDivisions,
      'dhaka': l10n.emergencyDirDhaka,
      'chattogram': l10n.emergencyDirChattogram,
      'rajshahi': l10n.emergencyDirRajshahi,
      'khulna': l10n.emergencyDirKhulna,
      'barisal': l10n.emergencyDirBarishal,
      'sylhet': l10n.emergencyDirSylhet,
      'rangpur': l10n.emergencyDirRangpur,
      'mymensingh': l10n.emergencyDirMymensingh,
    };
  }

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
      _displayed = widget.ranked.where((r) {
        final s = r.shelter;
        // Division facet: 'all' passes everything; otherwise the
        // shelter's division key must match. Shelters without a
        // division (legacy/sample records) only show under 'all'.
        if (_division != 'all' && s.division != _division) return false;
        // District facet: null passes everything; otherwise the
        // shelter's district must match exactly.
        if (_district != null && s.district != _district) return false;
        if (query.isEmpty) return true;
        return s.name.toLowerCase().contains(query) ||
            s.nameBn.contains(query) ||
            s.source.toLowerCase().contains(query);
      }).toList();
    });
  }

  /// Whether the current dataset carries any division-tagged shelters.
  /// When false (legacy sample data), the chip row is hidden entirely.
  bool get _hasDivisions =>
      widget.ranked.any((r) => r.shelter.division != null);

  /// Sorted unique district names present in the data for the currently
  /// selected division. Empty when the division is 'all' or no records
  /// carry a district.
  List<String> get _districtsForDivision {
    if (_division == 'all') return const [];
    final set = <String>{};
    for (final r in widget.ranked) {
      if (r.shelter.division == _division && r.shelter.district != null) {
        set.add(r.shelter.district!);
      }
    }
    final list = set.toList()..sort();
    return list;
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
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                  ),
                ),
              ),
            ),
            // Division facet — mirrors DirectoryScreen's chip row so the
            // two filters look and behave identically. Only shown when
            // the dataset actually carries divisions (legacy 25-record
            // set had none); we detect that by scanning the ranked list.
            if (_hasDivisions)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in _divisions(context).entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(entry.value),
                            selected: _division == entry.key,
                            onSelected: (sel) {
                              if (!sel) return;
                              setState(() {
                                _division = entry.key;
                                _district = null; // reset on division change
                              });
                              _refresh();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // District facet — cascading from the selected division.
            // Appears only when a division is picked and the data has
            // district-tagged records for it.
            if (_division != 'all' && _districtsForDivision.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    border: const OutlineInputBorder(),
                    labelText: l10n.shelterSelectDistrict,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _district,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.shelterAllDistricts),
                        ),
                        for (final d in _districtsForDivision)
                          DropdownMenuItem<String?>(
                              value: d, child: Text(d)),
                      ],
                      onChanged: (v) {
                        setState(() => _district = v);
                        _refresh();
                      },
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
    final l10n = AppLocalizations.of(context);
    // Semantic results take priority when we have them.
    final sem = _semanticResult;
    if (sem != null &&
        sem.intent != SearchIntent.shelterFilter &&
        widget.onPoiSelect != null) {
      return _buildSemanticSection(context);
    }

    if (_displayed.isEmpty) {
      return Center(child: Text(l10n.shelterNoResults));
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shield_rounded,
                color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          title: Text(bnName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${r.km.toStringAsFixed(1)} ${l10n.shelterUnitKm}'
            '${s.capacity != null ? '  •  ${s.capacity} ${l10n.shelterUnitPeople}' : ''}'
            '  •  ${s.source}',
            style: const TextStyle(fontSize: 14),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => widget.onSelect(r),
        );
      },
    );
  }

  /// Semantic results: geocoded places or POIs from Overpass.
  Widget _buildSemanticSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_semanticLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final hits = _semanticHits ?? [];
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.shelterNoSearchResults,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(l10n.shelterTryDifferentWords,
                style: const TextStyle(fontSize: 14)),
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
          icon = Icons.place_rounded;
        } else if (h is OverpassPoi) {
          label = h.nameBn ?? h.name;
          lat = h.lat;
          lon = h.lon;
          icon = Icons.local_hospital_rounded;
        } else {
          return const SizedBox.shrink();
        }
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          title: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => widget.onPoiSelect!(lat, lon, label),
        );
      },
    );
  }
}
