import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/device_registry_service.dart';
import '../../features/mesh_comm/mesh_service.dart';
import '../../features/admin/campaign_request.dart';
import '../safe_beacon/safety_status_service.dart';
import 'admin_widgets.dart';
import '../../core/bangla_numerals.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.adminLogoutTitle),
          content: Text(l10n.adminLogoutBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.adminLogoutButton),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _logout() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          return Scaffold(
            appBar: AppBar(
              // A thin brand-colored rule under the title bar is the only
              // chrome difference between "citizen Shongjog" and "admin
              // Shongjog" — subtle, but persistent for as long as an
              // operator is in a privileged area.
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: Container(height: 3, color: cs.primary),
              ),
              title: Text(l10n.adminPanelTitle),
              actions: [
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                        ),
                        child: Text(
                          banglaNumber(pendingCount),
                          style: TextStyle(
                            // Sits on cs.error, which is a LIGHT red in dark
                            // mode — white here measured 2.77:1 there.
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: l10n.adminLogoutButton,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    final shouldLogout = await _confirmLogout();
                    if (shouldLogout) _logout();
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow — reinforces "you're in a privileged area" the
                  // moment the panel loads, not just at the login gate.
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        l10n.adminPanelTitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Hero strip — quick admin greeting + system status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.adminDashboardTitle,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.adminDashboardSubtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          Navigator.pushNamed(context, AppRoutes.adminDangerList),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stat row — same data as the dashboard page's stat
                  // cards, surfaced here so the admin can see system
                  // health at a glance.
                  _AdminStatRow(),
                  const SizedBox(height: 20),
                  // Section title
                  Text(
                    l10n.adminQuickActions,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 2x2 grid — each tile pushes to its own page. One
                  // accent color throughout (the locked brand hue) —
                  // these are routine navigation, not status; color is
                  // reserved for the danger entry above, not spent here.
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _AdminTile(
                        title: l10n.adminDashboardTitle,
                        icon: Icons.dashboard_rounded,
                        route: AppRoutes.adminDashboard,
                      ),
                      _AdminTile(
                        title: l10n.adminTabUsers,
                        icon: Icons.people_rounded,
                        route: AppRoutes.adminUsers,
                      ),
                      _AdminTile(
                        title: l10n.adminTabCampaigns,
                        icon: Icons.campaign_rounded,
                        route: AppRoutes.adminCampaigns,
                        badgeCount: pendingCount,
                      ),
                      _AdminTile(
                        title: l10n.adminTabBroadcast,
                        icon: Icons.podcasts_rounded,
                        route: AppRoutes.adminBroadcast,
                      ),
                    ],
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

// ── Bengali numeral helper ──────────────────────────────────


// ── Pending-requests AppBar badge ──────────────────────────

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    if (count <= 0) {
      return Tooltip(
        message: l10n.adminNoCampaigns,
        child: Icon(Icons.check_circle_rounded, color: ShongjogTheme.success, size: 24),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_rounded, size: 14, color: cs.onError),
          const SizedBox(width: 4),
          Text(
            banglaNumber(count),
            style: TextStyle(
              color: cs.onError,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live stat row (read-only dashboard preview on the entry page) ──

class _AdminStatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // Users and offline-sessions were hardcoded literals (5 and 3) until the
    // device registry existed — the panel showed the same two numbers on a
    // fresh install as on a live deployment. They now come from the
    // `users/{uid}` roster every device heartbeats into.
    return ListenableBuilder(
      listenable: deviceRegistryService,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: _MiniStat(
              icon: Icons.people_rounded,
              label: l10n.adminStatUsers,
              value: banglaNumber(deviceRegistryService.totalDevices),
              tint: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              icon: Icons.offline_bolt_rounded,
              label: l10n.adminStatOffline,
              value: banglaNumber(deviceRegistryService.offlineCount),
              tint: ShongjogTheme.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              icon: Icons.bluetooth_rounded,
              label: l10n.adminStatMesh,
              value: banglaNumber(meshService.peerCount),
              tint: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: ShongjogTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ShongjogTheme.iconBadge(context, tint: tint),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(height: 10),
          AnimatedStatValue(
            value: value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
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
                      width: 44,
                      height: 44,
                      decoration: ShongjogTheme.iconBadge(context),
                      child: Icon(icon, color: cs.primary, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'বিস্তারিত',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                    ),
                    child: Text(
                      banglaNumber(badgeCount!),
                      style: TextStyle(
                        color: cs.onError,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
