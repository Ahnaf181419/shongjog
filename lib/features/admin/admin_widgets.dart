import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/bangla_numerals.dart';
import '../../l10n/app_localizations.dart';

/// Shared premium primitives for the admin section — kept in one place so
/// the dashboard, panel grid, and sub-pages read as one surface instead of
/// each hand-rolling a slightly different version of the same idea.

/// The admin section's page chrome.
///
/// Every sub-page hand-rolled the same `AppBar` with the same
/// `leading: IconButton(Icons.arrow_back_rounded, tooltip: …)` — four
/// copies of identical code whose only reason to exist was localising the
/// tooltip that Flutter's automatic back button cannot take. One copy now,
/// wrapped in [Semantics] so a screen reader announces it (§6: "`Semantics`
/// on every icon button" — the admin section previously had none at all).
class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final bool showBack;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.appBarBottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: appBarBottom,
        actions: actions,
        leading: showBack
            ? Semantics(
                button: true,
                label: l10n.adminPageBackTooltip,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: l10n.adminPageBackTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
            : null,
      ),
      body: body,
    );
  }
}

/// The admin section's one empty state.
///
/// Users, campaigns and the danger list each rendered their own — a 48px
/// icon with no padding, a 48px icon with 24dp padding, and a 64px icon —
/// so three adjacent screens disagreed about what "nothing here" looks like.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  /// Absence is not always neutral. An empty danger list is *good news* and
  /// gets the success tone; an empty device list is simply information.
  final SemanticTone tone;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.tone = SemanticTone.info,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = tone == SemanticTone.info
        ? cs.outline
        : ShongjogTheme.toneFill(context, tone);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: ShongjogTheme.iconBadge(context, tint: tint),
              child: Icon(icon, size: 36, color: tint),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stat value that briefly scales + fades when it changes.
///
/// Several admin numbers are genuinely live now (Firestore-synced mesh
/// peers, pending campaigns, safety counts) — a value that silently pops
/// to a new digit undersells that. This gives real-time updates a visible
/// "something just happened" moment without being showy about it: a single
/// ~220ms transition, no bounce, no color flash.
class AnimatedStatValue extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const AnimatedStatValue({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}

/// The one deliberate, non-decorative use of alert-red in the admin
/// section. Its visual weight scales with [dangerCount] on purpose:
/// silent when nothing's wrong (a calm, permanently-discoverable row),
/// impossible to miss the moment someone reports danger (a bold banner).
/// Same component, different state — the intensity itself is the signal,
/// not a separate "urgent version" widget maintained in parallel.
class DangerListEntry extends StatelessWidget {
  final int dangerCount;
  final String titleActive;
  final String titleCalm;
  final VoidCallback onTap;
  const DangerListEntry({
    super.key,
    required this.dangerCount,
    required this.titleActive,
    required this.titleCalm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final active = dangerCount > 0;

    if (active) {
      return Semantics(
        button: true,
        label: '$titleActive ${numberForLocale(dangerCount, lang)}',
        child: Material(
          color: cs.error,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.onError.withValues(alpha: 0.18),
                      borderRadius:
                          BorderRadius.circular(ShongjogTheme.radiusSm),
                    ),
                    child:
                        Icon(Icons.warning_rounded, color: cs.onError, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleActive,
                          style: tt.titleMedium?.copyWith(
                            color: cs.onError,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedStatValue(
                          value: numberForLocale(dangerCount, lang),
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onError.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: cs.onError, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Calm state: a quiet, hairline-bordered row — present and reachable,
    // but taking up no more visual weight than the situation warrants.
    return Semantics(
      button: true,
      label: titleCalm,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: cs.error.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: cs.error.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titleCalm,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before an admin action that other people will feel.
///
/// Approving a campaign puts a pin on every nearby user's map; rejecting one
/// takes it away. Both used to be a single unguarded tap. Returns `true`
/// only on explicit confirmation — a dismissed dialog is a "no".
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  SemanticTone tone = SemanticTone.info,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final onTone = tone == SemanticTone.info
          ? null
          : ShongjogTheme.onToneFill(ctx, tone);
      return AlertDialog(
        title: Text(title),
        content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            style: ShongjogTheme.dialogAction(),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: ShongjogTheme.dialogAction().merge(
              tone == SemanticTone.info
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: ShongjogTheme.toneFill(ctx, tone),
                      foregroundColor: onTone,
                    ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// One live number on a card — the admin section's only stat component.
///
/// The panel's entry page and the dashboard page each had their own
/// (`_MiniStat` and `_StatCard`): the same layout, built twice, drifting
/// apart in padding and icon size while sitting one tap from each other.
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  /// The panel's entry-page row carries three cards beside a hero, so it
  /// runs a size down from the dashboard's full-width row.
  final bool compact;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Two sizes, both on the badge scale (32 compact / 40 standard); 36 was
    // a third value used nowhere else in the section.
    final badge = compact ? 32.0 : 40.0;
    // One node, not three — a screen reader should read "Mesh peers, 4",
    // not stop on an unlabelled icon and two loose strings.
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: ShongjogTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badge,
              height: badge,
              decoration: ShongjogTheme.iconBadge(context, tint: tint),
              child: Icon(icon, size: compact ? 18 : 20, color: tint),
            ),
            const SizedBox(height: 12),
            AnimatedStatValue(
              value: value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
