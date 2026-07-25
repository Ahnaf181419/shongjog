import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../app/router.dart';
import '../../features/mesh_comm/mesh_service.dart';
import '../../features/admin/campaign_request.dart';

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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _bnNum(pendingCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.adminDashboardSubtitle,
                              style: TextStyle(
                                fontSize: 13,
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
                  // 2x2 grid — each tile pushes to its own page
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
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                      _AdminTile(
                        title: l10n.adminTabUsers,
                        icon: Icons.people_rounded,
                        route: AppRoutes.adminUsers,
                        accent: Theme.of(context).colorScheme.tertiary,
                      ),
                      _AdminTile(
                        title: l10n.adminTabCampaigns,
                        icon: Icons.campaign_rounded,
                        route: AppRoutes.adminCampaigns,
                        accent: Theme.of(context).colorScheme.secondary,
                        badgeCount: pendingCount,
                      ),
                      _AdminTile(
                        title: l10n.adminTabBroadcast,
                        icon: Icons.podcasts_rounded,
                        route: AppRoutes.adminBroadcast,
                        accent: Theme.of(context).colorScheme.error,
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


// ── Bengali numeral helper ──────────────────────────────────

String _bnNum(int n) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return n.toString().split('').map((d) => digits[int.parse(d)]).join();
}

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
        child: Icon(Icons.check_circle_rounded, color: cs.tertiary, size: 24),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_rounded, size: 14, color: cs.onError),
          const SizedBox(width: 4),
          Text(
            _bnNum(count),
            style: TextStyle(
              color: cs.onError,
              fontSize: 13,
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
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.people_rounded,
            label: l10n.adminStatUsers,
            value: _bnNum(5),
            tint: cs.primary,
            background: cs.primaryContainer.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.offline_bolt_rounded,
            label: l10n.adminStatOffline,
            value: _bnNum(3),
            tint: cs.tertiary,
            background: cs.tertiaryContainer.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.bluetooth_rounded,
            label: l10n.adminStatMesh,
            value: _bnNum(meshService.peerCount),
            tint: cs.secondary,
            background: cs.secondaryContainer.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color background;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
  final Color accent;
  final int? badgeCount;
  const _AdminTile({
    required this.title,
    required this.icon,
    required this.route,
    required this.accent,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
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
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 24),
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
                          fontSize: 12,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _bnNum(badgeCount!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
