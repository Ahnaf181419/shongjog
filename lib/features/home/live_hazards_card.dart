import 'package:flutter/material.dart';

import '../../core/connectivity_provider.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../hazards/usgs_earthquake_service.dart';

/// Home-screen card showing live natural hazards near Bangladesh.
///
/// Pulls three free, key-less feeds in parallel on first build:
///   - NASA EONET (cyclones, floods, wildfires, volcanoes…)
///   - USGS Earthquakes (last 30 days, M >= 4.0)
///   - GDACS UN/JRC alerts (with Green/Orange/Red severity)
///
/// When offline, the card is not rendered at all — consistent with
/// the app's offline-first thesis. When online but every feed fails,
/// the card renders a neutral tap-to-retry affordance. When at least
/// one feed succeeds with zero items, the card shows a green
/// 'এই মুহূর্তে কোনো ঝুঁকি নেই' (no active hazards right now) state — a
/// meaningful, reassuring signal rather than silence.
class LiveHazardsCard extends StatefulWidget {
  const LiveHazardsCard({super.key});

  @override
  State<LiveHazardsCard> createState() => _LiveHazardsCardState();
}

class _LiveHazardsCardState extends State<LiveHazardsCard> {
  List<_HazardsItem>? _items;
  bool _loading = true;
  bool _allFailed = false;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    _wasOnline = connectivityProvider.isOnline;
    connectivityProvider.addListener(_onConnectivityChanged);
    _load();
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  /// Auto-refresh when the network comes back online — a user returning
  /// from airplane mode should see fresh hazards without a manual tap.
  void _onConnectivityChanged() {
    final now = connectivityProvider.isOnline;
    if (now && !_wasOnline) {
      _load();
    }
    _wasOnline = now;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _allFailed = false;
    });

    final isOnline = connectivityProvider.isOnline;

    // Fire all three in parallel. Each returns null on failure (offline,
    // transport error, parse error) — null is distinct from an empty list.
    final results = await Future.wait([
      EonetService.fetchOpenHazards(isOnline: isOnline),
      UsgsEarthquakeService.fetchRecent(isOnline: isOnline),
      GdacsService.fetchBangladeshAlerts(isOnline: isOnline),
    ]);

    if (!mounted) return;

    final eonet = results[0] as List<EonetEvent>?;
    final quakes = results[1] as List<EarthquakeEvent>?;
    final gdacs = results[2] as List<GdacsAlert>?;

    final allFailed =
        eonet == null && quakes == null && gdacs == null;
    final items = <_HazardsItem>[];

    // Severity ordering: red GDACS > strong quake > active EONET > moderate
    // quake > orange GDACS > weak quake > everything else.
    for (final e in eonet ?? const <EonetEvent>[]) {
      items.add(_HazardsItem.fromEonet(e));
    }
    for (final q in quakes ?? const <EarthquakeEvent>[]) {
      items.add(_HazardsItem.fromQuake(q));
    }
    for (final g in gdacs ?? const <GdacsAlert>[]) {
      items.add(_HazardsItem.fromGdacs(g));
    }
    items.sort((a, b) => b.weight.compareTo(a.weight));

    setState(() {
      _items = items;
      _loading = false;
      _allFailed = allFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't render the card at all when offline — it would only ever
    // show a spinner-then-retry, which adds noise to the home screen.
    if (!connectivityProvider.isOnline) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.crisis_alert_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'সতর্কতা',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (!_loading)
                  InkWell(
                    onTap: _load,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'তথ্য আনা হচ্ছে…',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_allFailed) {
      return InkWell(
        onTap: _load,
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'তথ্য আনা যায়নি। আবার চেষ্টা করুন।',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final items = _items ?? const <_HazardsItem>[];
    if (items.isEmpty) {
      // Every reachable feed returned zero items — a genuinely good signal.
      return Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'এই মুহূর্তে কোনো ঝুঁকি নেই',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
        ],
      );
    }

    // Cap to 3 to keep the card compact — the full list isn't more useful
    // than the top hazards, and longer cards push the rest of the home
    // screen below the fold.
    final top = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in top) ...[
          _HazardsRow(item: item),
          if (item != top.last) const SizedBox(height: 6),
        ],
        if (items.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'আরও ${items.length - 3}টি',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Normalised hazard item — the three feeds have different shapes, so we
/// project each into a common (icon, title, severity) triple for display.
class _HazardsItem {
  final IconData icon;
  final String title;
  final Color color;
  final int weight; // higher = more urgent

  const _HazardsItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.weight,
  });

  factory _HazardsItem.fromEonet(EonetEvent e) {
    return _HazardsItem(
      icon: _iconForEonet(e.category),
      title: e.title,
      color: _colorForEonet(e.category),
      // Active EONET events (cyclones, floods) are high-urgency.
      weight: 60 + (e.isActive ? 20 : 0) + _eonetBoost(e.category),
    );
  }

  factory _HazardsItem.fromQuake(EarthquakeEvent q) {
    return _HazardsItem(
      icon: Icons.public,
      title: 'M ${q.magnitude.toStringAsFixed(1)} — ${q.place}',
      color: _colorForQuake(q.severity),
      weight: 80 + q.magnitude.toInt() * 5,
    );
  }

  factory _HazardsItem.fromGdacs(GdacsAlert g) {
    final w = switch (g.severity) {
      GdacsSeverity.red => 200,
      GdacsSeverity.orange => 110,
      GdacsSeverity.green => 30,
      GdacsSeverity.unknown => 50,
    };
    return _HazardsItem(
      icon: Icons.campaign_rounded,
      title: g.title,
      color: _colorForGdacs(g.severity),
      weight: w,
    );
  }

  static IconData _iconForEonet(EonetCategory c) => switch (c) {
        EonetCategory.severeStorms => Icons.thunderstorm_rounded,
        EonetCategory.floods => Icons.water_rounded,
        EonetCategory.earthquakes => Icons.public,
        EonetCategory.wildfires => Icons.local_fire_department_rounded,
        EonetCategory.volcanoes => Icons.whatshot_rounded,
        EonetCategory.landslides => Icons.landscape_rounded,
        EonetCategory.extremeTemperatures => Icons.thermostat_rounded,
        EonetCategory.drought => Icons.grain_rounded,
        EonetCategory.seaLakeIce => Icons.ac_unit_rounded,
        EonetCategory.manmade || EonetCategory.other => Icons.crisis_alert_rounded,
      };

  static Color _colorForEonet(EonetCategory c) {
    // Cyclones + floods + volcanoes are the most dangerous for Bangladesh.
    return switch (c) {
      EonetCategory.severeStorms ||
      EonetCategory.floods ||
      EonetCategory.volcanoes ||
      EonetCategory.landslides =>
        const Color(0xFFD32F2F), // red
      EonetCategory.earthquakes ||
      EonetCategory.wildfires =>
        const Color(0xFFE65100), // deep orange
      _ => const Color(0xFFEF6C00), // amber
    };
  }

  static int _eonetBoost(EonetCategory c) => switch (c) {
        EonetCategory.severeStorms => 30,
        EonetCategory.floods => 25,
        EonetCategory.volcanoes => 20,
        EonetCategory.earthquakes => 15,
        _ => 0,
      };

  static Color _colorForQuake(EarthquakeSeverity s) => switch (s) {
        EarthquakeSeverity.strong => const Color(0xFFD32F2F),
        EarthquakeSeverity.moderate => const Color(0xFFE65100),
        EarthquakeSeverity.light => const Color(0xFFEF6C00),
      };

  static Color _colorForGdacs(GdacsSeverity s) => switch (s) {
        GdacsSeverity.red => const Color(0xFFD32F2F),
        GdacsSeverity.orange => const Color(0xFFE65100),
        GdacsSeverity.green => const Color(0xFF2E7D32),
        GdacsSeverity.unknown => const Color(0xFFEF6C00),
      };
}

class _HazardsRow extends StatelessWidget {
  const _HazardsRow({required this.item});
  final _HazardsItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(item.icon, size: 16, color: item.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
