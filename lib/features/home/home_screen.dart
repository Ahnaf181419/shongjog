import 'package:flutter/material.dart';
import 'dart:io';

import '../../app/main_shell.dart';
import '../../l10n/app_localizations.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../core/connectivity_provider.dart';
import '../../core/device_capability.dart';
import '../../core/haptics.dart';
import '../../core/model_manager.dart';
import '../../main.dart';
import '../profile/profile_screen.dart';
import '../quick_cards/cards_data.dart';
import '../weather/weather_card.dart';
import 'air_quality_card.dart';
import 'live_hazards_card.dart';
import 'marine_card.dart';
import '../../core/bangla_numerals.dart';

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
        title: const _ProfileTitle(),
        actions: [
          _EmergencyCallPill(),
          const SizedBox(width: 4),
          const _NotificationBell(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: AppLocalizations.of(context).settingsTitle,
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => pushNamedSafe(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          _ModelDownloadBanner(),
          _DownloadCompletionListener(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _StatusStrip(),
                const SizedBox(height: 10),
                // ── Weather card sits at the top: today's weather + 3-day strip.
                //   Optional network feature — degrades to a tap-to-load affordance.
                const WeatherCard(),
                const SizedBox(height: 8),
                const LiveHazardsCard(),
                const SizedBox(height: 8),
                const AirQualityCard(),
                const SizedBox(height: 8),
                const MarineCard(),
                const SizedBox(height: 8),
                // ── 2 emergency tiles (cards / shelter). The 999 entry point
                //   lives in the AppBar pill — always reachable while scrolling.
                _EmergencyTriad(),
                const SizedBox(height: 12),
                _OfflineMessageTile(),
                const SizedBox(height: 12),
                _TipCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  AppBar title — profile avatar + name, tap to edit
// ════════════════════════════════════════════════════════════════

class _ProfileTitle extends StatefulWidget {
  const _ProfileTitle();

  @override
  State<_ProfileTitle> createState() => _ProfileTitleState();
}

class _ProfileTitleState extends State<_ProfileTitle> {
  UserProfileData _profile = UserProfileData.empty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileData.load();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPhoto = _profile.hasPhoto;

    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, AppRoutes.profile);
        if (mounted) {
          final updated = await UserProfileData.load();
          if (mounted) setState(() => _profile = updated);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? Image.file(
                      File(_profile.photoPath!),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: _profile.initial.isNotEmpty
                          ? Text(
                              _profile.initial,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: cs.primary.withValues(alpha: 0.6),
                            ),
                    ),
            ),
          ),
          if (_profile.name.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _profile.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: ShongjogTheme.fontFamily,
                  fontFamilyFallback: ShongjogTheme.fontFallback,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
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
          borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
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
                    AppLocalizations.of(context).emergencyCall,
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


  @override
  Widget build(BuildContext context) {
    final count = adminBroadcastService.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).notificationsTooltip,
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
                banglaNumber(count),
                style: TextStyle(
                  fontSize: 14,
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
          label: isOnline ? AppLocalizations.of(context).statusOnline : AppLocalizations.of(context).statusOffline,
        ),
        const SizedBox(width: 8),
        _StatusChip(
          leading: Icon(Icons.check_circle_rounded,
              size: 14, color: ShongjogTheme.success),
          label: AppLocalizations.of(context).dataReady,
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
              fontSize: 14,
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
//  Emergency triad — 2-up tiles (999 moved to AppBar pill)
// ════════════════════════════════════════════════════════════════

class _EmergencyTriad extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final countBn = banglaNumber(kQuickCards.length);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TriadTile(
                  icon: Icons.style_rounded,
                  titleBn: AppLocalizations.of(context).emergencyCards,
                  subtitleBn: AppLocalizations.of(context).emergencyCardsCount(countBn),
                  onTap: () => MainShellRoute.goTo(context, 3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TriadTile(
                  icon: Icons.shield_rounded,
                  titleBn: AppLocalizations.of(context).nearbyShelter,
                  subtitleBn: AppLocalizations.of(context).shelterFromGps,
                  onTap: () => MainShellRoute.goTo(context, 4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TriageTile(
                  onTap: () => pushNamedSafe(context, AppRoutes.triage),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SafeBeaconTile(
                  onTap: () => pushNamedSafe(context, AppRoutes.safeBeacon),
                ),
              ),
            ],
          ),
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
                      AppLocalizations.of(context).emergencyNumbers,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).emergencyDirectoryDesc,
                      style: TextStyle(
                        fontSize: 14,
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
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            border: Border.all(color: cs.tertiary, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.shield_rounded,
                  color: cs.onTertiaryContainer, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).imSafe,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).imSafeDesc,
                      style: TextStyle(
                        fontSize: 14,
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

// ══════════════════════════════════════════════════════════════
//  Tip card — daily rotating disaster-preparedness tip
// ══════════════════════════════════════════════════════════════

class _TipCard extends StatelessWidget {
  const _TipCard();

  /// The rotating tips, in the user's own language.
  ///
  /// These were a `static const` list of Bangla literals, rendered under a
  /// *localized* "Today's tip" heading — so an English-locale user got an
  /// English title above a Bangla paragraph, on the most-viewed card of the
  /// most-viewed screen. Reading them from [AppLocalizations] is what makes
  /// the card actually bilingual.
  ///
  /// Built per-call rather than cached: it is 19 string lookups against an
  /// already-loaded table, once per build of one small card.
  static List<String> _tipsFor(AppLocalizations l10n) => [
        l10n.homeTip1, l10n.homeTip2, l10n.homeTip3, l10n.homeTip4,
        l10n.homeTip5, l10n.homeTip6, l10n.homeTip7, l10n.homeTip8,
        l10n.homeTip9, l10n.homeTip10, l10n.homeTip11, l10n.homeTip12,
        l10n.homeTip13, l10n.homeTip14, l10n.homeTip15, l10n.homeTip16,
        l10n.homeTip17, l10n.homeTip18, l10n.homeTip19,
      ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final tips = _tipsFor(l10n);
    final tipIndex = DateTime.now().day % tips.length;
    return Container(
      padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
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
                  l10n.todaysTip,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tips[tipIndex],
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
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(ShongjogTheme.radius),
            border: Border.all(color: cs.error, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.medical_services_rounded,
                  color: cs.onErrorContainer, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).triageWizard,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '১০+ ধরনের জরুরি অবস্থায় প্রাথমিক চিকিৎসা',
                      style: TextStyle(
                        fontSize: 14,
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
                child: Icon(Icons.wifi_tethering_rounded,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context).offlineMessage,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).offlineMessageDesc,
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


  String _bnPct(double? progress) {
    if (progress == null) return '';
    return '${banglaNumber((progress * 100).round())}%';
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
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress ?? 0.0,
                  minHeight: 4,
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context).modelDownloadProgress(_bnPct(progress)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context).modelDownloading,
                      style: TextStyle(
                        fontSize: 14,
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
            SnackBar(
              content: Text(AppLocalizations.of(context).modelReady),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).downloadFailed),
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


