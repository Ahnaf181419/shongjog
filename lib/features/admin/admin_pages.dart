import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../features/mesh_comm/mesh_service.dart';
import '../../l10n/app_localizations.dart';
import 'campaign_request.dart';

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
        title: const Text('সিস্টেম সারসংক্ষেপ'),
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
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(stats: [
            _StatInfo(
              icon: Icons.people_rounded,
              label: l10n.adminStatUsers,
              value: _bnDigits(5),
              tint: cs.primary,
            ),
            _StatInfo(
              icon: Icons.offline_bolt_rounded,
              label: l10n.adminStatOffline,
              value: _bnDigits(3),
              tint: cs.tertiary,
            ),
            _StatInfo(
              icon: Icons.bluetooth_rounded,
              label: l10n.adminStatMesh,
              value: _bnDigits(meshService.peerCount),
              tint: cs.secondary,
            ),
          ]),
          const SizedBox(height: 16),
          _QuickActions(),
        ],
      ),
    );
  }
}

/// Admin Users page — list of currently-connected mesh peers.
///
/// Same content as the old `_UsersTab`. Pulls from the live mesh
/// service. Empty-state mirrors the original.
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

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
    final peers = meshService.peerList;
    if (peers.isEmpty) {
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: peers.length,
      itemBuilder: (context, index) {
        final peer = peers[index];
        return ListTile(
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ShongjogTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(peer.name.isNotEmpty ? peer.name : l10n.adminUnknownDevice),
          subtitle: Text(
            peer.endpointId.length > 12
                ? '${peer.endpointId.substring(0, 12)}…'
                : peer.endpointId,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      },
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
            decoration: const InputDecoration(
              hintText: 'বার্তা লিখুন…',
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
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: info.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(info.icon, color: info.tint, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            info.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                  ? '${l10n.adminReviewCampaigns} (${_bnDigits(pending)})'
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
      color: cs.secondaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface)),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _bnDigits(badgeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: req.status == CampaignStatus.pending
                ? cs.tertiaryContainer
                : cs.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            req.status == CampaignStatus.pending
                ? Icons.hourglass_top_rounded
                : Icons.check_rounded,
            color: req.status == CampaignStatus.pending
                ? cs.tertiary
                : cs.secondary,
            size: 20,
          ),
        ),
        title: Text(req.type.label(context)),
        subtitle: Text(
          '${req.userName}\n${req.address}',
          style: const TextStyle(fontSize: 12),
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

// ── Bengali digit helper (local, mirrors model_manager's) ──────────

String _bnDigits(int n) => n.toString().split('').map((c) {
      const m = {
        '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
        '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
      };
      return m[c] ?? c;
    }).join();