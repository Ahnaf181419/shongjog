import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../core/device_registry_service.dart';
import '../../features/mesh_comm/mesh_service.dart';
import '../../features/safe_beacon/safety_status_service.dart';
import '../../l10n/app_localizations.dart';
import 'admin_widgets.dart';
import 'campaign_request.dart';
import '../../core/bangla_numerals.dart';

/// Admin Dashboard page — live system overview.
///
/// Reads mesh peer count + pending campaign requests. Renders a 3-card
/// stat grid (users, offline sessions, mesh peers) and a recent-activity
/// strip. Pure read-only; no actions.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).adminSystemSummary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppLocalizations.of(context).adminPageBackTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDashboardTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.adminDashboardSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Live safety-status stat row — reflects incoming mesh
          // reports from users pressing Safe / Danger.
          ListenableBuilder(
            listenable: safetyStatusService,
            builder: (context, _) {
              return _StatRow(stats: [
                _StatInfo(
                  icon: Icons.people_rounded,
                  label: l10n.adminSafetyTotal,
                  value: banglaNumber(safetyStatusService.totalUsers),
                  tint: cs.primary,
                ),
                _StatInfo(
                  icon: Icons.check_circle_rounded,
                  label: l10n.adminSafetySafe,
                  value: banglaNumber(safetyStatusService.safeCount),
                  tint: ShongjogTheme.success,
                ),
                _StatInfo(
                  icon: Icons.warning_rounded,
                  label: l10n.adminSafetyDanger,
                  value: banglaNumber(safetyStatusService.dangerCount),
                  tint: cs.error,
                ),
              ]);
            },
          ),
          const SizedBox(height: 16),
          _QuickActions(),
        ],
      ),
    );
  }
}

/// Admin Users page — every device running Shongjog, not just the ones in
/// Bluetooth range.
///
/// This used to list `meshService.peerList` alone, which meant an admin saw
/// only the handful of phones within mesh radius of their own — the page was
/// empty in the normal case where users are spread across a city. It now
/// leads with the Firestore `users/{uid}` roster every device heartbeats
/// into (see [DeviceRegistryService]) and folds mesh in as an extra signal:
/// a device that is also a live mesh peer gets a "nearby" marker.
///
/// Mesh peers with no registry row are still listed at the end — that's a
/// device on an older build, or one that has never had a network connection,
/// and dropping it would lose the one channel that still reaches it.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  @override
  void initState() {
    super.initState();
    deviceRegistryService.addListener(_onChange);
  }

  @override
  void dispose() {
    deviceRegistryService.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).adminTabUsers),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppLocalizations.of(context).adminPageBackTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final devices = deviceRegistryService.devices;
    final peers = meshService.peerList;

    // A mesh peer is matched to a registry row by name — the mesh advertises
    // the user's profile name, and that's the only field the two sources
    // share (mesh endpointIds are per-session, Firestore uids are per-install).
    // Imperfect for duplicate names, but it only decorates a row with a
    // "nearby" marker; nothing depends on it being exact.
    final meshNames = {
      for (final p in peers)
        if (p.name.isNotEmpty) p.name,
    };
    final registeredNames = {
      for (final d in devices)
        if (d.name.isNotEmpty) d.name,
    };
    final meshOnly =
        peers.where((p) => !registeredNames.contains(p.name)).toList();

    if (devices.isEmpty && meshOnly.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_rounded, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              l10n.adminNoDevices,
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Card-wrapped rows — bare ListTiles here were the one screen in the
    // admin section that didn't carry the app's card language, making it
    // read noticeably rawer than Campaigns/Danger List right next to it.
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: devices.length + meshOnly.length,
      itemBuilder: (context, index) {
        if (index < devices.length) {
          final d = devices[index];
          return _DeviceTile(
            name: d.name.isNotEmpty ? d.name : l10n.adminUnknownDevice,
            detail: _lastSeenLabel(l10n, d.lastSeen),
            isOnline: d.isOnline,
            isAdmin: d.isAdmin,
            isNearby: d.name.isNotEmpty && meshNames.contains(d.name),
          );
        }
        final peer = meshOnly[index - devices.length];
        return _DeviceTile(
          name: peer.name.isNotEmpty ? peer.name : l10n.adminUnknownDevice,
          detail: peer.endpointId.length > 12
              ? '${peer.endpointId.substring(0, 12)}…'
              : peer.endpointId,
          detailIsMonospace: true,
          // A live mesh peer is by definition reachable right now, even
          // though it has no Firestore heartbeat to prove it.
          isOnline: true,
          isNearby: true,
        );
      },
    );
  }

  String _lastSeenLabel(AppLocalizations l10n, DateTime? lastSeen) {
    if (lastSeen == null) return l10n.adminDeviceNeverSeen;
    final d = DateTime.now().toUtc().difference(lastSeen);
    if (d.inMinutes < 1) return l10n.adminTimeJustNow;
    if (d.inHours < 1) return l10n.adminTimeMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l10n.adminTimeHoursAgo(d.inHours);
    return l10n.adminTimeDaysAgo(d.inDays);
  }
}

class _DeviceTile extends StatelessWidget {
  final String name;
  final String detail;
  final bool detailIsMonospace;
  final bool isOnline;
  final bool isAdmin;
  final bool isNearby;

  const _DeviceTile({
    required this.name,
    required this.detail,
    this.detailIsMonospace = false,
    required this.isOnline,
    this.isAdmin = false,
    this.isNearby = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = cs.brightness == Brightness.dark;
    final dot = isOnline
        ? (isDark ? ShongjogTheme.successBright : ShongjogTheme.success)
        : cs.outline;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: ShongjogTheme.iconBadge(context, tint: dot),
          alignment: Alignment.center,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              _Chip(label: l10n.adminDeviceAdmin, tint: cs.primary),
            ],
            if (isNearby) ...[
              const SizedBox(width: 6),
              _Chip(label: l10n.adminDeviceNearby, tint: cs.tertiary),
            ],
          ],
        ),
        subtitle: Text(
          detail,
          style: TextStyle(
            fontSize: 14,
            fontFamily: detailIsMonospace ? 'monospace' : null,
            color: cs.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          isOnline ? l10n.adminDeviceOnline : l10n.adminDeviceOffline,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isOnline ? dot : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color tint;
  const _Chip({required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tint,
        ),
      ),
    );
  }
}

/// Admin Campaigns page — list of pending + reviewed campaign requests.
///
/// Live-updates via the existing `campaignRequestService` listener.
/// Each row has Approve / Reject actions for pending items.
class AdminCampaignsPage extends StatefulWidget {
  const AdminCampaignsPage({super.key});

  @override
  State<AdminCampaignsPage> createState() => _AdminCampaignsPageState();
}

class _AdminCampaignsPageState extends State<AdminCampaignsPage> {
  @override
  void initState() {
    super.initState();
    campaignRequestService.addListener(_onChange);
  }

  @override
  void dispose() {
    campaignRequestService.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).adminTabCampaigns),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppLocalizations.of(context).adminPageBackTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = campaignRequestService.pendingRequests;
    final reviewed = campaignRequestService.approvedRequests;
    final all = [...pending, ...reviewed];

    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(l10n.adminNoCampaigns,
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: all.length,
      itemBuilder: (context, i) => _CampaignRequestTile(req: all[i]),
    );
  }
}

/// Admin Broadcast page — send a global broadcast message to all users.
class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await adminBroadcastService.addMessage(text);
    _controller.clear();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminBroadcastSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).adminTabBroadcast),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppLocalizations.of(context).adminPageBackTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminBroadcastSection,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminBroadcastSubtitle,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.adminWriteMessage,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(l10n.adminBroadcastSend),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ──────────────────────────────────────────────

class _StatInfo {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _StatInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });
}

class _StatRow extends StatelessWidget {
  final List<_StatInfo> stats;
  const _StatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _StatCard(info: stats[i])),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatInfo info;
  const _StatCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShongjogTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShongjogTheme.iconBadge(context, tint: info.tint),
            child: Icon(info.icon, color: info.tint, size: 20),
          ),
          const SizedBox(height: 10),
          // Genuinely live — this whole row rebuilds via
          // ListenableBuilder(listenable: safetyStatusService), so a
          // Firestore-synced report from another device changing this
          // number deserves a visible moment, not a silent digit-swap.
          AnimatedStatValue(
            value: info.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.label,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final pending = campaignRequestService.pendingCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminQuickActions,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickChip(
              icon: Icons.campaign_rounded,
              label: pending > 0
                  ? '${l10n.adminReviewCampaigns} (${banglaNumber(pending)})'
                  : l10n.adminReviewCampaigns,
              route: AppRoutes.adminCampaigns,
              badgeCount: pending,
            ),
            _QuickChip(
              icon: Icons.people_rounded,
              label: l10n.adminTabUsers,
              route: AppRoutes.adminUsers,
            ),
            _QuickChip(
              icon: Icons.podcasts_rounded,
              label: l10n.adminTabBroadcast,
              route: AppRoutes.adminBroadcast,
            ),
            _QuickChip(
              icon: Icons.warning_rounded,
              label: safetyStatusService.dangerCount > 0
                  ? '${l10n.adminSafetyDanger} (${banglaNumber(safetyStatusService.dangerCount)})'
                  : l10n.adminDangerListTitle,
              route: AppRoutes.adminDangerList,
              badgeCount: safetyStatusService.dangerCount,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final int badgeCount;
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.route,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              // Flexible, not a bare Text: a Wrap hands each child the full
              // row width as its maximum, and `mainAxisSize.min` then sizes
              // this Row to its content — so a label longer than the screen
              // overflows instead of wrapping. Bangla sets wider than the
              // English these chips were sized against, and "প্রচারণা
              // পর্যালোচনা (৩)" already overflowed by 72px at 320dp.
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  ),
                  child: Text(
                    banglaNumber(badgeCount),
                    style: TextStyle(
                      color: cs.onError,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Campaign request tile (extracted from _CampaignRequestsTab) ───

class _CampaignRequestTile extends StatelessWidget {
  final CampaignRequest req;
  const _CampaignRequestTile({required this.req});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // Pending = neutral, still-in-progress (brand color); approved = a
    // genuinely positive state (success green) — semantic, not decorative.
    final tint = req.status == CampaignStatus.pending ? cs.primary : ShongjogTheme.success;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: ShongjogTheme.iconBadge(context, tint: tint),
          child: Icon(
            req.status == CampaignStatus.pending
                ? Icons.hourglass_top_rounded
                : Icons.check_rounded,
            color: tint,
            size: 20,
          ),
        ),
        title: Text(req.type.label(context)),
        subtitle: Text(
          '${req.userName}\n${req.address}',
          style: const TextStyle(fontSize: 14),
        ),
        isThreeLine: true,
        trailing: req.status == CampaignStatus.pending
            ? TextButton(
                onPressed: () async {
                  await campaignRequestService.updateRequestStatus(
                    req.id,
                    CampaignStatus.approved,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${req.type.label(context)} ${l10n.adminApproved}',
                      ),
                    ),
                  );
                },
                child: Text(l10n.adminApprove),
              )
            : null,
      ),
    );
  }
}

// ── Admin Danger List page — users currently in danger with GPS ──

/// Shows every user who reported danger, sorted newest-first.
/// Each card shows: name, phone, danger type, timestamp, and a
/// tap-to-open Google Maps link if GPS was included.
class AdminDangerListPage extends StatelessWidget {
  const AdminDangerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDangerListTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.adminPageBackTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: safetyStatusService,
        builder: (context, _) {
          final reports = safetyStatusService.dangerReports;
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ShongjogTheme.successBright
                        : ShongjogTheme.success,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.adminDangerListEmpty,
                      style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final r = reports[i];
              return _DangerCard(report: r);
            },
          );
        },
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final SafetyReport report;
  const _DangerCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final timeStr = _formatTime(report.timestamp);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: cs.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.userName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.dangerType?.label(l10n) ?? '',
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.error,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (report.userPhone.isNotEmpty)
              _InfoRow(icon: Icons.phone_rounded, text: report.userPhone),
            _InfoRow(icon: Icons.schedule_rounded, text: timeStr),
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.note_rounded, text: report.note),
            ],
            if (report.mapsLink != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final uri = Uri.parse(report.mapsLink!);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(l10n.adminDangerOpenMap,
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'এইমাত্র';
    if (diff.inMinutes < 60) return '${banglaNumber(diff.inMinutes)} মিনিট আগে';
    if (diff.inHours < 24) return '${banglaNumber(diff.inHours)} ঘণ্টা আগে';
    return '${banglaNumber(diff.inDays)} দিন আগে';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
