import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';

/// Home tab — the informative main menu.
///
/// Layout: status strip → hero AI card → 2×2 bento grid → contextual tip.
/// One bold primary surface (the hero); everything else is soft-elevation
/// tinted-surface cards per design.md §11.
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
          const SizedBox(height: 12),
          Row(
            children: [
              _ProsnoKorunCard(
                onTap: () => onNavigateToTab?.call(1),
              ),
              const SizedBox(width: 10),
              const _WeatherForecastCard(),
            ],
          ),
          const SizedBox(height: 16),
          _BentoGrid(onNavigateToTab: onNavigateToTab),
          const SizedBox(height: 16),
          const _TipCard(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Status strip
// ════════════════════════════════════════════════════════════════

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      ),
      child: Row(
        children: [
          _StatusPill(
            icon: Icons.cloud_off_rounded,
            label: 'অফলাইনে চলে',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _StatusPill(
            icon: Icons.check_circle_rounded,
            label: 'তথ্য প্রস্তুত',
            color: ShongjogTheme.success,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: ShongjogTheme.fontFamily,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Top row — compact AI prompt + weather forecast
// ════════════════════════════════════════════════════════════════

class _ProsnoKorunCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProsnoKorunCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: cs.primary,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'প্রশ্ন করুন',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: ShongjogTheme.fontFamily,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'বাংলায় অফলাইনে উত্তর',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: ShongjogTheme.fontFamily,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherForecastCard extends StatelessWidget {
  const _WeatherForecastCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_rounded,
              color: cs.primary,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'আবহাওয়া',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: ShongjogTheme.fontFamily,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '৩২°C বৃষ্টি সম্ভাবনা',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: ShongjogTheme.fontFamily,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Bento grid — 2×2 soft-elevation tiles
// ════════════════════════════════════════════════════════════════

class _BentoGrid extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;
  const _BentoGrid({this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _BentoTile(
                icon: Icons.style_rounded,
                titleBn: 'জরুরি কার্ড',
                subtitleBn: 'ORS, সাপ, পানি — দ্রুত নির্দেশিকা',
                onTap: () => onNavigateToTab?.call(2),
              ),
              const SizedBox(height: 12),
              _BentoTile(
                icon: Icons.emergency_rounded,
                titleBn: 'জরুরি কল',
                subtitleBn: '৯৯৯, পরিচিতি — এক ট্যাপে',
                onTap: () => pushNamedSafe(
                    context, AppRoutes.emergencyContacts),
                isEmergency: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _BentoTile(
                icon: Icons.shield_rounded,
                titleBn: 'নিকটস্থ আশ্রয়',
                subtitleBn: 'জিপিএস থেকে সাইক্লোন শেল্টার',
                onTap: () => onNavigateToTab?.call(3),
              ),
              const SizedBox(height: 12),
              _BentoTile(
                icon: Icons.settings_rounded,
                titleBn: 'সেটিংস',
                subtitleBn: 'থিম, ভয়েস, তথ্যসূত্র',
                onTap: () => pushNamedSafe(context, AppRoutes.settings),
              ),
              const SizedBox(height: 12),
              _BentoTile(
                icon: Icons.radar,
                titleBn: 'অফলাইন রাডার',
                subtitleBn: 'আশেপাশের ডিভাইসে যোগাযোগ',
                onTap: () => pushNamedSafe(context, AppRoutes.meshRadar),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  final IconData icon;
  final String titleBn;
  final String subtitleBn;
  final VoidCallback onTap;
  final bool isEmergency;

  const _BentoTile({
    required this.icon,
    required this.titleBn,
    required this.subtitleBn,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isEmergency
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: ShongjogTheme.cardDecoration(context).copyWith(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: ShongjogTheme.iconBadge(context, tint: accent),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                titleBn,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: ShongjogTheme.fontFamily,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitleBn,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontFamily: ShongjogTheme.fontFamily,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'আজকের পরামর্শ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: ShongjogTheme.fontFamily,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'বন্যা মৌসুমে পানি অন্তত ১ মিনিট ফুটিয়ে পান। পানিবাহিত রোগ প্রতিরোধে ORS মজুত রাখুন।',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontFamily: ShongjogTheme.fontFamily,
                    color: Theme.of(context).colorScheme.onSurface,
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
