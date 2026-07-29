import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Shared premium primitives for the admin section — kept in one place so
/// the dashboard, panel grid, and sub-pages read as one surface instead of
/// each hand-rolling a slightly different version of the same idea.

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

  static String _bn(int n) {
    const d = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = dangerCount > 0;

    if (active) {
      return Material(
        color: cs.error,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onError.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  ),
                  child: Icon(Icons.warning_rounded, color: cs.onError, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleActive,
                        style: TextStyle(
                          color: cs.onError,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedStatValue(
                        value: _bn(dangerCount),
                        style: TextStyle(
                          color: cs.onError.withValues(alpha: 0.9),
                          fontSize: 14,
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
      );
    }

    // Calm state: a quiet, hairline-bordered row — present and reachable,
    // but taking up no more visual weight than the situation warrants.
    return Material(
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
              Icon(Icons.shield_outlined, color: cs.error.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titleCalm,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
