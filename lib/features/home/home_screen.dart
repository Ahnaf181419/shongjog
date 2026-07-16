import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/main_shell.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../core/connectivity_provider.dart';
import '../../core/device_capability.dart';
import '../../core/haptics.dart';
import '../../core/model_manager.dart';
import '../../main.dart';
import '../intelligence/intelligence_engine.dart';
import '../intelligence/notification_service.dart';
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
          const _NotificationBell(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'সেটিংস',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => pushNamedSafe(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          const _ModelDownloadBanner(),
          const _DownloadCompletionListener(),
          Expanded(
            child: ListView(
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
                const _InsightsList(),
              ],
            ),
          ),
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
//  AppBar notification bell — unread badge
// ════════════════════════════════════════════════════════════════

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  @override
  void initState() {
    super.initState();
    adminBroadcastService.addListener(_onChange);
  }

  @override
  void dispose() {
    adminBroadcastService.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _bnNum(int n) =>
      n.toString().split('').map((d) => _bnDigits[int.parse(d)]).join();

  @override
  Widget build(BuildContext context) {
    final count = adminBroadcastService.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'বিজ্ঞপ্তি',
          icon: const Icon(Icons.notifications_rounded),
          onPressed: () => pushNamedSafe(context, AppRoutes.notifications),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _bnNum(count),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onError,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
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
    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 12),
        _TriageTile(
          onTap: () => pushNamedSafe(context, AppRoutes.triage),
        ),
        const SizedBox(height: 12),
        _SafeBeaconTile(
          onTap: () => pushNamedSafe(context, AppRoutes.safeBeacon),
        ),
        const SizedBox(height: 12),
        _DirectoryTile(
          onTap: () => pushNamedSafe(context, AppRoutes.directory),
        ),
      ],
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DirectoryTile({required this.onTap});

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
          child: Row(
            children: [
              Icon(Icons.contact_phone_rounded, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'জরুরি নম্বর',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'অফলাইন ডিরেক্টরি — জাতীয় ও বিভাগীয় হটলাইন',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafeBeaconTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SafeBeaconTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: Container(
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            border: Border.all(color: cs.tertiary, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: cs.tertiary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'আমি নিরাপদ আছি',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'পরিবারকে মেশ ও এসএমএস দিয়ে জানান',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onTertiaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriageTile extends StatelessWidget {
  final VoidCallback onTap;
  const _TriageTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        child: Container(
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            border: Border.all(color: cs.error, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.medical_services_rounded, color: cs.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ট্রায়াজ উইজার্ড',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'এলএলএম ছাড়াই প্রাথমিক চিকিৎসা — প্রশ্নের উত্তর দিন',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onErrorContainer),
            ],
          ),
        ),
      ),
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

class _InsightsList extends StatefulWidget {
  const _InsightsList();

  @override
  State<_InsightsList> createState() => _InsightsListState();
}

class _InsightsListState extends State<_InsightsList> {
  /// Insight cards read local chat history — like auto-read TTS, unsolicited
  /// behavior stays behind a pref. Default is on; Settings exposes a toggle.
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    intelligenceEngine.addListener(_onChange);
    _loadPrefAndAnalyze();
  }

  Future<void> _loadPrefAndAnalyze() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('pref_show_insights') ?? true;
      if (mounted && enabled != _enabled) setState(() => _enabled = enabled);
      if (!enabled) return;
    } catch (_) {
      // Prefs unavailable (tests) — keep the default.
    }
    intelligenceEngine.analyzeBehavior();
  }

  @override
  void dispose() {
    intelligenceEngine.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    final insights = NotificationService.generateInsights(intelligenceEngine.profile);
    if (insights.isEmpty) return const SizedBox.shrink();

    // Just show the top 2 insights to avoid clutter
    final displayInsights = insights.take(2).toList();

    return Column(
      children: displayInsights.map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _InsightCard(insight: insight),
      )).toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final ProactiveInsight insight;
  const _InsightCard({required this.insight});

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
                  insight.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.message,
                  style: TextStyle(
                    fontSize: ShongjogTheme.bodyFloor,
                    height: 1.5,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (insight.route != '/')
            IconButton(
              icon: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary),
              onPressed: () {
                if (insight.route == '/shelter') MainShellRoute.goTo(context, 3);
                if (insight.route == '/cards') MainShellRoute.goTo(context, 2);
              },
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

// ════════════════════════════════════════════════════════════════
//  Model download banner — thin strip under the AppBar
// ════════════════════════════════════════════════════════════════

/// Visible only while [modelManager] reports a variant downloading.
/// Shows a [LinearProgressIndicator] + Bangla percentage label so the
/// user can track the ~1.87 GB download after leaving Settings.
class _ModelDownloadBanner extends StatelessWidget {
  const _ModelDownloadBanner();

  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  String _bnPct(double? progress) {
    if (progress == null) return '';
    final pct = (progress * 100).round();
    return '${pct.toString().split('').map((d) => _bnDigits[int.parse(d)]).join()}%';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: modelManager,
      builder: (context, _) {
        if (!modelManager.isAnyVariantDownloading) {
          return const SizedBox.shrink();
        }
        final progress = modelManager.activeDownloadProgress;
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.primary.withValues(alpha: 0.08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress, minHeight: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'মডেল ডাউনলোড ${_bnPct(progress)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'পটভূমিতে চলছে',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Download completion listener — fires snackbar on transition
// ════════════════════════════════════════════════════════════════

/// Invisible widget that watches [modelManager] for the
/// `downloading → not-downloading` transition and fires a snackbar via
/// the global [scaffoldMessengerKey]. Lives in the Home tree so it's
/// mounted whenever the user is on the Home tab.
class _DownloadCompletionListener extends StatefulWidget {
  const _DownloadCompletionListener();

  @override
  State<_DownloadCompletionListener> createState() =>
      _DownloadCompletionListenerState();
}

class _DownloadCompletionListenerState
    extends State<_DownloadCompletionListener> {
  bool _wasDownloading = false;

  @override
  void initState() {
    super.initState();
    modelManager.addListener(_onChange);
    _wasDownloading = modelManager.isAnyVariantDownloading;
  }

  @override
  void dispose() {
    modelManager.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final isDownloading = modelManager.isAnyVariantDownloading;
    if (_wasDownloading && !isDownloading) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger != null) {
        final anyReady = ModelVariant.values.any(
          (v) => modelManager.getState(v) == ModelState.ready,
        );
        if (anyReady) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('মডেল প্রস্তুত — এখন অফলাইন এআই চালু।'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('ডাউনলোড ব্যর্থ — সেটিংস থেকে আবার চেষ্টা করুন।'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
    _wasDownloading = isDownloading;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
