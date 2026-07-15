import 'package:flutter/material.dart';

import '../nearest_shelter.dart';

/// Card overlay above the map showing the [top3] nearest ranked
/// shelters (only visible when no route is active and search is
/// closed).
class NearestCard extends StatelessWidget {
  final List<RankedShelter> top3;
  final ValueChanged<dynamic /* Shelter */ > onTapRow;

  const NearestCard({
    super.key,
    required this.top3,
    required this.onTapRow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('নিকটতম ৩টি',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...top3.map((r) => _ShelterRow(
                  shelter: r.shelter,
                  km: r.km,
                  onTap: () => onTapRow(r.shelter),
                )),
          ],
        ),
      ),
    );
  }
}

class _ShelterRow extends StatelessWidget {
  final dynamic /* Shelter */ shelter;
  final double km;
  final VoidCallback onTap;

  const _ShelterRow({
    required this.shelter,
    required this.km,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nameBn = shelter.nameBn as String;
    final name = shelter.name as String;
    final shown = nameBn.isNotEmpty ? nameBn : name;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shown,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            Text(
              '${km.toStringAsFixed(1)} কিমি',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
