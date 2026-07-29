import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../hazards/usgs_earthquake_service.dart';
import 'hazards_item.dart';
import 'live_hazards_card.dart';

/// Full-screen scrollable list of all active hazards near Bangladesh.
///
/// Pushed from [LiveHazardsCard] when the user taps "আরও Xটি দেখুন".
/// Each row is tappable and opens the source URL (USGS event page, GDACS
/// alert page) via [url_launcher]. EONET events have no external URL so
/// they just show coordinates.
class HazardsListScreen extends StatelessWidget {
  const HazardsListScreen({super.key, required this.items});

  final List<HazardsItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hazardsAllAlerts),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return _HazardTile(item: item);
        },
      ),
    );
  }
}

class _HazardTile extends StatelessWidget {
  const _HazardTile({required this.item});
  final HazardsItem item;

  Future<void> _openSource(BuildContext context) async {
    final url = _sourceUrl();
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _sourceUrl() {
    final raw = item.rawEvent;
    if (raw is EarthquakeEvent) {
      return 'https://earthquake.usgs.gov/earthquakes/eventpage/${raw.id}';
    }
    if (raw is GdacsAlert) {
      return raw.link;
    }
    if (raw is EonetEvent) {
      return 'https://eonet.gsfc.nasa.gov/events/${raw.id}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUrl = _sourceUrl() != null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasUrl ? () => _openSource(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUrl)
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
