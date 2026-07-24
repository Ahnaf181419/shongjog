import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// About / sources page. Lists the corpus sources, building trust by
/// showing guidance is attributable (docs/design.md §7.7).
///
/// Theme-aware: every color is derived from [ColorScheme] or the
/// [ShongjogTheme] helpers so the page reads correctly in light AND dark
/// mode (the previous version used hardcoded hex + deprecated aliases
/// and lost contrast in dark).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _sources = <_Source>[
    _Source(
        name: 'World Health Organization', bn: 'বিশ্ব স্বাস্থ্য সংস্থা (WHO)'),
    _Source(
        name: 'Bangladesh Red Crescent Society',
        bn: 'বাংলাদেশ রেড ক্রিসেন্ট সোসাইটি (BDRCS)'),
    _Source(
        name: 'Ministry of Disaster Management',
        bn: 'দুর্যোগ ব্যবস্থাপনা মন্ত্রণালয় (MoDMR)'),
    _Source(
        name: 'Bangladesh Meteorological Dept',
        bn: 'আবহাওয়া অধিদপ্তর (BMD)'),
    _Source(name: 'CDC', bn: 'সিডিসি'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Brand header — primary-tinted card. White text on the brand
          // surface in both modes (ocean in light, oceanBright in dark —
          // both offer ≥5:1 with white).
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context).aboutBrand,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).aboutTagline,
                  style: TextStyle(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).aboutDescription,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: ShongjogTheme.bodySecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          ..._sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ShongjogTheme.cardSurface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ShongjogTheme.hairline(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.verified_outlined,
                            color: cs.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: ShongjogTheme.body(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.bn,
                              style: TextStyle(
                                fontSize: 13,
                                color: ShongjogTheme.bodySecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          // 999 footer — emergency call-out, theme-adaptive error color.
          // In light mode: red-600 surface (light variant). In dark mode:
          // red-400 surface (brighter for dark contrast).
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_in_talk, color: cs.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).aboutEmergencyNote,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: cs.onSurface,
                    ),
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

class _Source {
  final String name;
  final String bn;
  const _Source({required this.name, required this.bn});
}
