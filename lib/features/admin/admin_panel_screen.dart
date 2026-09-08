import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/bangla_numerals.dart';
import '../../core/device_registry_service.dart';
import '../../core/firebase_auth_service.dart';
import '../../features/admin/campaign_request.dart';
import '../../features/mesh_comm/mesh_service.dart';
import '../safe_beacon/safety_status_service.dart';
import 'admin_widgets.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  Future<bool> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    return confirmAdminAction(
      context,
      title: l10n.adminLogoutTitle,
      body: l10n.adminLogoutBody,
      confirmLabel: l10n.adminLogoutButton,
    );
  }

  void _logout() {
    // Actually give up the role, don't just navigate away from it. Logging
    // out used to leave `role: 'admin'` on this device's users/{uid} doc
    // permanently, so the phone kept the ability to create broadcasts and
    // approve campaigns for the life of the install — including for whoever
    // picked it up next. Fire-and-forget: releaseAdminRole never throws, and
    // Firestore queues the write if this device is offline.
    unawaited(firebaseAuthService.releaseAdminRole().then((_) {
      // Narrow the live queries back down as soon as the role is gone.
      campaignRequestService.refreshSubscription();
      safetyStatusService.refreshSubscription();
    }));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmLogout();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: campaignRequestService,
        builder: (context, _) {
          final pendingCount = campaignRequestService.pendingCount;
          final l10n = AppLocalizations.of(context);
          return AdminScaffold(
            title: l10n.adminPanelTitle,
            showBack: false,
            // A thin brand-colored rule under the title bar is the only
            // chrome difference between "citizen Shongjog" and "admin
            // Shongjog" — subtle, but persistent for as long as an
            // operator is in a privileged area.
            appBarBottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: Container(height: 3, color: cs.primary),
            ),
            actions: [
              // The pending count used to render three times on this one
              // screen — here, in the hero pill, and on the campaigns tile.
              // Three shapes, one fact. The AppBar copy is the one with no
              // job the other two weren't already doing: the hero pill is
              // the at-a-glance status, the tile badge is the wayfinding.
              Semantics(
                button: true,
                label: l10n.adminLogoutButton,
                child: IconButton(
                  tooltip: l10n.adminLogoutButton,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    final shouldLogout = await _confirmLogout();
                    if (shouldLogout) _logout();
                  },
                ),
              ),
            ],
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow — reinforces "you're in a privileged area" the
                  // moment the panel loads, not just at the login gate.
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.adminPanelTitle,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hero strip — quick admin greeting + system status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.adminDashboardTitle,
                              style: tt.headlineMedium
                                  ?.copyWith(color: cs.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.adminDashboardSubtitle,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PendingBadge(count: pendingCount),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Danger entry — the one place red is used on purpose.
                  // Full-bleed and impossible to miss the moment someone
                  // reports danger; a quiet, still-reachable row otherwise.
                  // Deliberately placed ABOVE the routine-navigation grid
                  // below, not inside it — its position, not just its
                  // color, is what signals "this one is different."
                  ListenableBuilder(
                    listenable: safetyStatusService,
                    builder: (context, _) => DangerListEntry(
                      dangerCount: safetyStatusService.dangerCount,
                      titleActive: l10n.adminSafetyDanger,
                      titleCalm: l10n.adminDangerListTitle,
                      onTap: () =>
                          pushNamedSafe(context, AppRoutes.adminDangerList),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stat row — same data as the dashboard page's stat
                  // cards, surfaced here so the admin can see system
                  // health at a glance.
                  const _AdminStatRow(),
                  const SizedBox(height: 24),
                  // Section title
                  Text(
                    l10n.adminQuickActions,
                    style: tt.labelMedium,
                  ),
                  const SizedBox(height: 12),
                  // 2x2 grid — each tile pushes to its own page. One
                  // accent color throughout (the locked brand hue) —
                  // these are routine navigation, not status; color is
                  // reserved for the danger entry above, not spent here.
                  // Two IntrinsicHeight rows rather than a GridView.
                  //
                  // GridView.count needs a childAspectRatio, and that pins
                  // tile HEIGHT to tile WIDTH — so a tile can never grow to
                  // fit its own content. As soon as a Bangla title wrapped to
                  // a second line (a narrow phone, or the user's OS text
                  // scale) the tiles overflowed by up to 186px, and in a
                  // release build that clips silently rather than striping.
                  //
                  // IntrinsicHeight costs an extra layout pass over four
                  // cheap tiles, and buys tiles that size to their content
                  // while both halves of a row stay equal height.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AdminTile(
                            title: l10n.adminDashboardTitle,
                            icon: Icons.dashboard_rounded,
                            route: AppRoutes.adminDashboard,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminTile(
                            title: l10n.adminTabUsers,
                            icon: Icons.people_rounded,
                            route: AppRoutes.adminUsers,
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
                          child: _AdminTile(
                            title: l10n.adminTabCampaigns,
                            icon: Icons.campaign_rounded,
                            route: AppRoutes.adminCampaigns,
                            badgeCount: pendingCount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminTile(
                            title: l10n.adminTabBroadcast,
                            icon: Icons.podcasts_rounded,
                            route: AppRoutes.adminBroadcast,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Pending-requests hero badge ────────────────────────────

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    if (count <= 0) {
      return Semantics(
        label: l10n.adminNoCampaigns,
        child: Tooltip(
          message: l10n.adminNoCampaigns,
          child: Icon(
            Icons.check_circle_rounded,
            color: ShongjogTheme.toneFill(context, SemanticTone.success),
            size: 24,
          ),
        ),
      );
    }
    return Semantics(
      label: '${l10n.adminTabCampaigns} ${numberForLocale(count, lang)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active_rounded,
                size: 16, color: cs.onError),
            const SizedBox(width: 4),
            Text(
              numberForLocale(count, lang),
              style: tt.labelMedium?.copyWith(
                color: cs.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live stat row (read-only dashboard preview on the entry page) ──

class _AdminStatRow extends StatelessWidget {
  const _AdminStatRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    // Users and offline-sessions were hardcoded literals (5 and 3) until the
    // device registry existed — the panel showed the same two numbers on a
    // fresh install as on a live deployment. They now come from the
    // `users/{uid}` roster every device heartbeats into.
    return ListenableBuilder(
      listenable: deviceRegistryService,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: AdminStatCard(
              compact: true,
              icon: Icons.people_rounded,
              label: l10n.adminStatUsers,
              value: numberForLocale(deviceRegistryService.totalDevices, lang),
              tint: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AdminStatCard(
              compact: true,
              icon: Icons.offline_bolt_rounded,
              label: l10n.adminStatOffline,
              value: numberForLocale(deviceRegistryService.offlineCount, lang),
              tint: ShongjogTheme.toneFill(context, SemanticTone.success),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AdminStatCard(
              compact: true,
              // NOT a Bluetooth icon. The mesh is `nearby_connections`
              // P2P_CLUSTER, whose transport is Wi-Fi Direct — Bluetooth is
              // used only to advertise and scan. The old
              // `Icons.bluetooth_rounded` taught operators (and anyone they
              // demo to) the wrong mental model of how the app reaches
              // phones when the network is down.
              icon: Icons.hub_rounded,
              label: l10n.adminStatMesh,
              value: numberForLocale(meshService.peerCount, lang),
              tint: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin tile — pushes to a separate page via the route ──────

class _AdminTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final int? badgeCount;
  const _AdminTile({
    required this.title,
    required this.icon,
    required this.route,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final isLight = cs.brightness == Brightness.light;
    final badged = badgeCount != null && badgeCount! > 0;
    return Semantics(
      button: true,
      label: badged
          ? '$title ${numberForLocale(badgeCount!, lang)}'
          : title,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? const Color(0xFF000000).withValues(alpha: 0.05)
                  : const Color(0xFF000000).withValues(alpha: 0.30),
              offset: const Offset(0, 2),
              blurRadius: 12,
            ),
          ],
        ),
        // No `shape:` override — the tile used a hand-rolled 14dp radius,
        // a value §5.4 never names, on a card sitting next to 12dp badges.
        // Inheriting `cardTheme` puts it on the same corner as every other
        // card in the app, and keeps it there if the token ever moves.
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, route),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: ShongjogTheme.iconBadge(context),
                        child: Icon(icon, color: cs.primary, size: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        // Two lines is enough for every current label even at
                        // the 1.5x ceiling; past that, ellipsis beats a tile
                        // that keeps growing and pushes the grid off-screen.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.adminTileOpen,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (badged)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius:
                            BorderRadius.circular(ShongjogTheme.radiusSm),
                      ),
                      child: Text(
                        numberForLocale(badgeCount!, lang),
                        style: tt.labelMedium?.copyWith(
                          color: cs.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
