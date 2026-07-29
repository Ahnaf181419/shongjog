import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../shelter_model.dart';

/// Bottom card showing the currently-routed shelter's distance and
/// the cancel / details actions. Visible only while a route is
/// active (i.e. [selected] != null).
///
/// Renders "রুট খুঁজছি..." while [loading] is true; otherwise shows
/// the formatted distance in the ocean-color pill.
class ShelterRouteInfoCard extends StatelessWidget {
  final Shelter selected;
  final bool loading;
  final double? distanceKm;
  final VoidCallback onCancel;
  final VoidCallback onDetails;

  const ShelterRouteInfoCard({
    super.key,
    required this.selected,
    required this.loading,
    required this.distanceKm,
    required this.onCancel,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bnName = selected.nameBn.isNotEmpty ? selected.nameBn : selected.name;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
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
                  child: const Icon(Icons.shield_rounded,
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
                      if (selected.capacity != null)
                        Text(l10n.shelterCapacityCount('${selected.capacity}'),
                            style: const TextStyle(
                                fontSize: 14,
                                color: ShongjogTheme.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(l10n.shelterFindingRoute, style: const TextStyle(fontSize: 14)),
                ],
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ShongjogTheme.ocean.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        color: ShongjogTheme.ocean, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${(distanceKm?.toStringAsFixed(1) ?? '—')} ${l10n.shelterKm}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ShongjogTheme.ocean),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.cancel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShongjogTheme.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: Text(l10n.shelterDetails),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
