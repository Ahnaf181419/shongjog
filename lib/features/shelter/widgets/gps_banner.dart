import 'package:flutter/material.dart';

import 'package:shongjog/l10n/app_localizations.dart';
import '../../../app/theme.dart';

/// Banner showing GPS status, surfaced when GPS isn't available
/// (permission denied, service disabled, or a generic error).
///
/// When [error] is non-null the banner indicates an error state
/// (red icon + the error text); otherwise it advises the user that
/// distances can't be computed.
class GpsBanner extends StatelessWidget {
  /// Localized GPS error message, or null when GPS simply hasn't
  /// produced a position yet.
  final String? error;

  /// When true, the banner anchors below the AppBar.bottom pill
  /// instead of immediately below the AppBar title row.
  final bool stackedBelowOfflinePill;

  const GpsBanner({
    super.key,
    required this.error,
    required this.stackedBelowOfflinePill,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: stackedBelowOfflinePill ? 56 : 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_off_rounded,
              color: error != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error ?? AppLocalizations.of(context).shelterGpsUnavailable,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
