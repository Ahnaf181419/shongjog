import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../nearest_shelter.dart';

/// List view (when the map/list SegmentedButton is in list mode)
/// showing all [shelters] ranked by distance. Tapping a row calls
/// [onTap] with the underlying Shelter.
class ShelterListView extends StatelessWidget {
  final List<RankedShelter> shelters;
  final ValueChanged<dynamic /* Shelter */ > onTap;

  const ShelterListView({
    super.key,
    required this.shelters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (shelters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.shelterNoData),
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
                if (r.km > 0) '${r.km.toStringAsFixed(1)} ${l10n.shelterKm}',
                if (s.capacity != null) l10n.shelterCapacityCount('${s.capacity}'),
                if (r.km == 0 && s.capacity == null) s.source,
              ].join(' • '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onTap(s),
          ),
        );
      },
    );
  }
}
