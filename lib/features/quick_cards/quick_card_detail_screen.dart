import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../app/theme.dart';
import 'cards_data.dart';
import '../../core/bangla_numerals.dart';

/// Full-screen view of a single [QuickCard]. Pushed from the triage
/// wizard's "View Card" CTA so the wizard's terminal screen can stay
/// focused on the immediate act-now steps and the operator handoff,
/// while the deep first-aid script is one tap away.
///
/// The screen is purely presentational — no plugin imports, no IO.
class QuickCardDetailScreen extends StatelessWidget {
  final String cardId;

  const QuickCardDetailScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = _findCard(cardId, l10n);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: ShongjogTheme.cardSurface(context),
      appBar: AppBar(
        title: Text(card.titleBn),
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.onSurface,
        leading: IconButton(
          tooltip: l10n.cardDetailBack,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: card.stepsBn.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.cardDetailNoSteps,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: card.stepsBn.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _StepTile(
                index: i + 1,
                text: card.stepsBn[i],
                accent: card.color,
              ),
            ),
    );
  }

  static QuickCard _findCard(String id, AppLocalizations l10n) {
    for (final c in kQuickCards) {
      if (c.id == id) return c;
    }
    // Unknown id — render an empty fallback so callers never crash on
    // a stale route arg.
    return QuickCard(
      id: '__missing__',
      titleBn: l10n.cardDetailNotFound,
      icon: Icons.help_outline_rounded,
      color: Colors.grey,
      stepsBn: [],
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final String text;
  final Color accent;
  const _StepTile({
    required this.index,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShongjogTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        border: Border.all(color: ShongjogTheme.hairline(context)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 1, right: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                banglaNumber(index),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: ShongjogTheme.body(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
