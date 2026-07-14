import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/connectivity_provider.dart';
import '../../core/haptics.dart';
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
          const SizedBox(height: 16),
          // ── 3 emergency tiles: cards / shelter / 999 ──
          _EmergencyTriad(),
          const SizedBox(height: 12),
          _OfflineMessageTile(),
          const SizedBox(height: 12),
          const WeatherTile(),
          const SizedBox(height: 12),
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

class _StatusStrip extends StatefulWidget {
  const _StatusStrip();

  @override
  State<_StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<_StatusStrip> {
  @override
  void initState() {
    super.initState();
    connectivityProvider.addListener(_onChange);
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOnline = connectivityProvider.isOnline;
    return Row(
      children: [
        _StatusChip(
          leading: isOnline
              ? _LiveDot(color: cs.primary)
              : _OfflineDot(color: cs.primary),
          label: isOnline ? 'অনলাইনে চলছে' : 'অফলাইনে চলে',
        ),
        const SizedBox(width: 8),
        _StatusChip(
          leading: Icon(Icons.check_circle_rounded,
              size: 14, color: ShongjogTheme.success),
          label: 'তথ্য প্রস্তুত',
        ),
      ],
    );
  }
}

/// Static dot used when the device is online — solid, no pulse. Keeps the
/// strip calm when nothing is wrong.
class _LiveDot extends StatelessWidget {
  final Color color;
  const _LiveDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Widget leading;
  final String label;
  const _StatusChip({required this.leading, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShongjogTheme.statusChip(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
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
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      // Respect the system reduced-motion preference. The dot still renders
      // at full alpha when motion is disabled — only the breathing stops.
      if (!MediaQuery.of(context).disableAnimations) {
        _c.repeat(reverse: true);
      }
      _started = true;
    }
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

class _HeroAskCard extends StatefulWidget {
  final VoidCallback onTap;
  const _HeroAskCard({required this.onTap});

  @override
  State<_HeroAskCard> createState() => _HeroAskCardState();
}

class _HeroAskCardState extends State<_HeroAskCard> {
  // Tracks the InkWell highlight so we can run a press-scale animation
  // alongside the default ripple. Both are required: ripple alone is
  // subtle on a saturated gradient panel.
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Honour reduced-motion: skip the 0.98 press-scale when the user has
    // asked the OS to reduce motion. The InkWell ripple still fires either
    // way, so press feedback survives — only the lift animation is gated.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedScale(
      scale: (!reduceMotion && _pressed) ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) {
            setState(() => _pressed = pressed);
          },
          child: Ink(
            decoration: ShongjogTheme.heroPanel(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Recessed mic well — contained object, not a glow source.
                  Container(
                    width: 64,
                    height: 64,
                    decoration: ShongjogTheme.micWell(context),
                    child: Icon(
                      Icons.mic_rounded,
                      color: cs.onPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  // Middle: oversized Bangla display + caption.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'প্রশ্ন করুন',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                            height: 1.10,
                            letterSpacing: -0.01,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'অফলাইনে বাংলায় ভয়েসে উত্তর',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onPrimary.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right: quiet secondary status + Bangla numeral chip.
                  // Breaks the SaaS "icon-left, copy-left, arrow-right"
                  // pattern; anchors the panel in real product state.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(
                          '২৪/৭ সক্রিয়',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onPrimary.withValues(alpha: 0.85),
                            height: 1.1,
                            letterSpacing: 0.02,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: ShongjogTheme.numeralChip(context),
                        child: Text(
                          '১',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: Container(
          decoration: ShongjogTheme.cardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShongjogTheme.iconBadge(context),
                child: Icon(icon, color: cs.primary, size: 22),
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
//  Offline message tile — Bluetooth mesh P2P
// ════════════════════════════════════════════════════════════════

class _OfflineMessageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.lightTap();
          pushNamedSafe(context, AppRoutes.meshRadar);
        },
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: Container(
          decoration: ShongjogTheme.cardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShongjogTheme.iconBadge(context),
                child: Icon(Icons.bluetooth_audio_rounded,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'অফলাইন মেসেজ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ব্লুটুথ দিয়ে কাছের মানুষদের সাথে কথা বলুন',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: cs.onSurfaceVariant, size: 22),
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
