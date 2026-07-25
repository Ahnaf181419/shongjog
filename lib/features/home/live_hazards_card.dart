import 'package:flutter/material.dart';

import '../../core/connectivity_provider.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../hazards/usgs_earthquake_service.dart';
import 'hazards_item.dart';
import 'hazards_list_screen.dart';

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
  List<HazardsItem>? _items;
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

    final results = await Future.wait([
      EonetService.fetchOpenHazards(isOnline: isOnline),
      UsgsEarthquakeService.fetchRecent(isOnline: isOnline),
      GdacsService.fetchBangladeshAlerts(isOnline: isOnline),
    ]);

    if (!mounted) return;

    final eonet = results[0] as List<EonetEvent>?;
    final quakes = results[1] as List<EarthquakeEvent>?;
    final gdacs = results[2] as List<GdacsAlert>?;

    final allFailed = eonet == null && quakes == null && gdacs == null;
    final items = <HazardsItem>[];

    for (final e in eonet ?? const <EonetEvent>[]) {
      items.add(HazardsItem.fromEonet(e, context));
    }
    for (final q in quakes ?? const <EarthquakeEvent>[]) {
      items.add(HazardsItem.fromQuake(q));
    }
    for (final g in gdacs ?? const <GdacsAlert>[]) {
      items.add(HazardsItem.fromGdacs(g, context));
    }
    items.sort((a, b) => b.weight.compareTo(a.weight));

    setState(() {
      _items = items;
      _loading = false;
      _allFailed = allFailed;
    });
  }

  void _openFullList() {
    if (_items == null || _items!.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HazardsListScreen(items: _items!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final items = _items ?? const <HazardsItem>[];
    if (items.isEmpty) {
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

    final top = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in top) ...[
          HazardsRow(item: item),
          if (item != top.last) const SizedBox(height: 6),
        ],
        if (items.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: _openFullList,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'আরও ${items.length - 3}টি দেখুন',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 14, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single hazard row — icon + one-line title · subtitle.
class HazardsRow extends StatelessWidget {
  const HazardsRow({super.key, required this.item});
  final HazardsItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(item.icon, size: 16, color: item.color),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.25,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
