import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../weather/weather_tile.dart';

/// Home tab — the informative main menu.
///
/// Layout: status strip → hero AI card (the moment) → 3 emergency tiles
/// (cards / shelter / 999) → live weather tile → contextual tip.
///
/// Per design.md §7.6, the home is 3-4 tiles max. Mesh-radar + settings
/// surface from the AppBar / About so the critical path stays uncluttered.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onNavigateToTab});

  /// Lets Home switch the bottom-nav tab (e.g. hero → AI tab).
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ'),
        actions: [
          IconButton(
            tooltip: 'সেটিংস',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => pushNamedSafe(context, AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _StatusStrip(),
          const SizedBox(height: 14),
          // ── Hero card: the moment. Voice-first AI entry point. ──
          _HeroAskCard(onTap: () => onNavigateToTab?.call(1)),
          const SizedBox(height: 18),
          // ── 3 emergency tiles: cards / shelter / 999 ──
          _EmergencyTriad(),
          const SizedBox(height: 14),
          // ── Live weather (real data via Open-Meteo, neutral on error) ──
          const WeatherTile(),
          const SizedBox(height: 14),
          // ── Contextual tip ──
          const _TipCard(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Status strip — single grounded line
// ════════════════════════════════════════════════════════════════

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Calm offline dot with breathing pulse (design.md §11.6)
        _OfflineDot(color: cs.primary),
        const SizedBox(width: 8),
        Text(
          'অফলাইনে চলে',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.check_circle_rounded,
            size: 16, color: ShongjogTheme.success),
        const SizedBox(width: 6),
        Text(
          'তথ্য প্রস্তুত',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _OfflineDot extends StatefulWidget {
  final Color color;
  const _OfflineDot({required this.color});

  @override
  State<_OfflineDot> createState() => _OfflineDotState();
}

class _OfflineDotState extends State<_OfflineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Hero — voice-first entry to AI
// ════════════════════════════════════════════════════════════════

class _HeroAskCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroAskCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: cs.primary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  // Theme-aware scrim on the brand surface: white-tinted in
                  // light mode, slate-tinted in dark mode (so it reads on
                  // sky-400).
                  color: cs.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: cs.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'প্রশ্ন করুন',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'বাংলায় ভয়েসে জিজ্ঞাসা করুন — অফলাইনেই উত্তর',
                      style: TextStyle(
                        fontSize: 14,
                        // Same-onPrimary at 85% opacity — readable on both
                        // ocean (light, white text) and oceanBright (dark,
                        // slate-900 text).
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: cs.onPrimary.withValues(alpha: 0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Emergency triad — 3 tiles per design.md §7.6
// ════════════════════════════════════════════════════════════════

class _EmergencyTriad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TriadTile(
                icon: Icons.style_rounded,
                titleBn: 'জরুরি কার্ড',
                subtitleBn: '৮টি দ্রুত নির্দেশিকা',
                onTap: () => MainShellRoute.goTo(context, 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TriadTile(
                icon: Icons.shield_rounded,
                titleBn: 'নিকটস্থ আশ্রয়',
                subtitleBn: 'GPS থেকে শেল্টার',
                onTap: () => MainShellRoute.goTo(context, 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EmergencyHeroTile(
          onTap: () => pushNamedSafe(context, AppRoutes.emergencyContacts),
        ),
      ],
    );
  }
}

class _TriadTile extends StatelessWidget {
  final IconData icon;
  final String titleBn;
  final String subtitleBn;
  final VoidCallback onTap;

  const _TriadTile({
    required this.icon,
    required this.titleBn,
    required this.subtitleBn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                titleBn,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleBn,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyHeroTile extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyHeroTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      // cs.error adapts: red-600 in light, red-400 in dark. Both offer
      // ≥AAA contrast vs. `cs.onPrimary` (white in light, slate-900 in dark).
      color: cs.error,
      borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.onError.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_in_talk_rounded,
                    color: cs.onError, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'জরুরি কল',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: cs.onError,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '৯৯৯ · ১৬১৬৩ · জরুরি যোগাযোগ',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onError.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: cs.onError, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Tip card — contextual guidance
// ════════════════════════════════════════════════════════════════

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lightbulb_rounded,
                color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'আজকের পরামর্শ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'বন্যা মৌসুমে পানি অন্তত ১ মিনিট ফুটিয়ে পান। পানিবাহিত রোগ প্রতিরোধে ORS মজুত রাখুন।',
                  style: TextStyle(
                    fontSize: ShongjogTheme.bodyFloor,
                    height: 1.5,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny helper: re-export the [MainShell] tab-jump API under a stable
/// name so feature screens don't have to import the shell widget directly.
abstract class MainShellRoute {
  static void goTo(BuildContext context, int tab) =>
      MainShell.goToTab(context, tab);
}
