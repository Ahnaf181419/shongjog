import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/connectivity_provider.dart';
import '../../core/haptics.dart';
import '../quick_cards/cards_data.dart';
import '../weather/weather_card.dart';

/// Home tab — context-first dashboard.
///
/// Layout: status strip → weather card (today + 3-day strip) → AI hero
/// (28 sp CTA on the drenched panel) → 2-up emergency triad (cards /
/// shelter; 999 lives in the AppBar now) → mesh tile → tip.
///
/// Per AGENTS.md, the 999 entry point is always reachable via the
/// persistent AppBar pill, even when the body content scrolls past.
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
          const _EmergencyCallPill(),
          const SizedBox(width: 4),
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
          const SizedBox(height: 10),
          // ── Weather card sits at the top: today's weather + 3-day strip.
          //   Optional network feature — degrades to a tap-to-load affordance.
          const WeatherCard(),
          const SizedBox(height: 16),
          // ── Hero: voice-first AI entry. Smaller (28 sp) than before; the
          //   weather card now leads, so the hero is "one of several" CTAs.
          _HeroAskCard(onTap: () => onNavigateToTab?.call(1)),
          const SizedBox(height: 16),
          // ── 2 emergency tiles (cards / shelter). The 999 entry point
          //   lives in the AppBar pill — always reachable while scrolling.
          _EmergencyTriad(),
          const SizedBox(height: 12),
          _OfflineMessageTile(),
          const SizedBox(height: 12),
          // ── Contextual tip ──
          const _TipCard(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar pill — persistent 999 shortcut
// ════════════════════════════════════════════════════════════════

/// Compact red pill that sits in the AppBar left of the settings icon.
/// Routes to [AppRoutes.emergencyContacts] (not a direct dial — the
/// contacts screen surfaces 999, 16163, and named personal contacts).
class _EmergencyCallPill extends StatelessWidget {
  const _EmergencyCallPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => pushNamedSafe(context, AppRoutes.emergencyContacts),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: ShongjogTheme.emergencyPill(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_in_talk_rounded,
                  size: 16,
                  color: cs.onError,
                ),
                const SizedBox(width: 6),
                Text(
                  'জরুরি কল',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onError,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Status strip — chip row
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
//  Hero — voice-first entry to AI (28 sp CTA)
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
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Recessed mic well — contained object, not a glow source.
                  Container(
                    width: 56,
                    height: 56,
                    decoration: ShongjogTheme.micWell(context),
                    child: Icon(
                      Icons.mic_rounded,
                      color: cs.onPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Middle: Bangla heading + caption.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'প্রশ্ন করুন',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                            height: 1.15,
                            letterSpacing: -0.01,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                      const SizedBox(height: 6),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: ShongjogTheme.numeralChip(context),
                        child: Text(
                          '১',
                          style: TextStyle(
                            fontSize: 15,
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
//  Emergency triad — 2-up tiles (999 moved to AppBar pill)
// ════════════════════════════════════════════════════════════════

class _EmergencyTriad extends StatelessWidget {
  String _bnNum(int n) {
    const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final countBn = _bnNum(kQuickCards.length);
    return Row(
      children: [
        Expanded(
          child: _TriadTile(
            icon: Icons.style_rounded,
            titleBn: 'জরুরি কার্ড',
            subtitleBn: '$countBnটি দ্রুত নির্দেশিকা',
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
