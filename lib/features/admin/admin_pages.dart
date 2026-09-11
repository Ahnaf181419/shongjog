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

/// "3 hours ago", in the caller's language and numeral system.
///
/// The danger list used to hardcode its own Bangla copy — `'এইমাত্র'`,
/// `'... মিনিট আগে'` — the only unlocalised user-facing strings left in the
/// admin section, and byte-identical to the `adminTime*` entries already in
/// `app_bn.arb`. In English the danger list rendered Bangla.
String _relativeTime(AppLocalizations l10n, String lang, Duration d) {
  if (d.inMinutes < 1) return l10n.adminTimeJustNow;
  if (d.inHours < 1) {
    return l10n.adminTimeMinutesAgo(numberForLocale(d.inMinutes, lang));
  }
  if (d.inDays < 1) {
    return l10n.adminTimeHoursAgo(numberForLocale(d.inHours, lang));
  }
  return l10n.adminTimeDaysAgo(numberForLocale(d.inDays, lang));
}

/// Admin Dashboard page — live system overview.
///
/// Reads mesh peer count + pending campaign requests. Renders a 3-card
/// stat grid (users, offline sessions, mesh peers) and a recent-activity
/// strip. Pure read-only; no actions.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: AppLocalizations.of(context).adminSystemSummary,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDashboardTitle,
            style: tt.titleLarge?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.adminDashboardSubtitle,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                  value:
                      numberForLocale(safetyStatusService.totalUsers, lang),
                  tint: cs.primary,
                ),
                _StatInfo(
                  icon: Icons.check_circle_rounded,
                  label: l10n.adminSafetySafe,
                  value: numberForLocale(safetyStatusService.safeCount, lang),
                  tint: ShongjogTheme.toneFill(context, SemanticTone.success),
                ),
                _StatInfo(
                  icon: Icons.warning_rounded,
                  label: l10n.adminSafetyDanger,
                  value:
                      numberForLocale(safetyStatusService.dangerCount, lang),
                  tint: cs.error,
                ),
              ]);
            },
          ),
          const SizedBox(height: 24),
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
    return AdminScaffold(
      title: AppLocalizations.of(context).adminTabUsers,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
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
      return AdminEmptyState(
        icon: Icons.devices_rounded,
        message: l10n.adminNoDevices,
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
            detail: _lastSeenLabel(l10n, lang, d.lastSeen),
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

  String _lastSeenLabel(
      AppLocalizations l10n, String lang, DateTime? lastSeen) {
    if (lastSeen == null) return l10n.adminDeviceNeverSeen;
    return _relativeTime(l10n, lang, DateTime.now().toUtc().difference(lastSeen));
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
              const SizedBox(width: 8),
              _Chip(label: l10n.adminDeviceAdmin, tint: cs.primary),
            ],
            if (isNearby) ...[
              const SizedBox(width: 8),
              _Chip(label: l10n.adminDeviceNearby, tint: cs.tertiary),
            ],
          ],
        ),
        subtitle: Text(
          detail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: detailIsMonospace ? 'monospace' : null,
                color: cs.onSurfaceVariant,
              ),
        ),
        trailing: Text(
          isOnline ? l10n.adminDeviceOnline : l10n.adminDeviceOffline,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tint),
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
    return AdminScaffold(
      title: AppLocalizations.of(context).adminTabCampaigns,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = campaignRequestService.pendingRequests;
    final reviewed = campaignRequestService.reviewedRequests;
    final all = [...pending, ...reviewed];

    if (all.isEmpty) {
      return AdminEmptyState(
        icon: Icons.campaign_rounded,
        message: l10n.adminNoCampaigns,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: all.length,
      itemBuilder: (context, i) => _CampaignRequestTile(req: all[i]),
    );
  }
}

/// Admin Broadcast page — writes to every install at once.
///
/// This is the highest-consequence control in the app. `firestore.rules`
/// says so in its own header: admin grants `broadcasts` create, which wires
/// straight into [LocalNotificationService], making it "a misinformation
/// channel, not merely a settings panel."
///
/// The screen used to have less friction than deleting a contact — one tap
/// on Send and the text was on every phone, with no confirmation, no idea
/// how many people that was, and no record of what had already gone out.
/// It now asks once, shows the message in the shape it will actually
/// arrive in, and keeps the log visible underneath.
class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  /// An Android tray notification truncates well before this; past it the
  /// tail is written but never read.
  static const int _maxChars = 280;

  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Drives the live counter and the Send button's enabled state.
    _controller.addListener(_onTextChanged);
    adminBroadcastService.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    adminBroadcastService.removeListener(_onTextChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BroadcastConfirmDialog(
        message: text,
        recipients: deviceRegistryService.totalDevices,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    await adminBroadcastService.addMessage(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _sending = false);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminBroadcastSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: AppLocalizations.of(context).adminTabBroadcast,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final used = _controller.text.characters.length;
    final over = used > _maxChars;
    final sent = adminBroadcastService.messages;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.adminBroadcastSection, style: tt.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.adminBroadcastSubtitle,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 4,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: l10n.adminWriteMessage,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        // Counter, not a hard `maxLength`. Silently refusing the next
        // keystroke mid-sentence is worse than showing the writer they are
        // past the length a phone will actually display.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            l10n.adminBroadcastCounter(
              numberForLocale(used, lang),
              numberForLocale(_maxChars, lang),
            ),
            style: tt.bodySmall?.copyWith(
              color: over
                  ? ShongjogTheme.toneInk(context, SemanticTone.danger)
                  : cs.onSurfaceVariant,
              fontWeight: over ? FontWeight.w600 : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending || used == 0 ? null : _send,
          icon: _sending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(l10n.adminBroadcastSend),
        ),
        const SizedBox(height: 32),
        Text(l10n.adminBroadcastRecent, style: tt.labelMedium),
        const SizedBox(height: 12),
        if (sent.isEmpty)
          Text(
            l10n.adminBroadcastNoneSent,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          for (final m in sent.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: ShongjogTheme.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text, style: tt.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(l10n, lang,
                          DateTime.now().difference(m.timestamp)),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Shows the message the way the recipient will meet it, then asks.
///
/// A plain "Are you sure?" tests only whether the admin meant to press the
/// button. Rendering the actual tray notification — the same title Android
/// will show, the same body — tests the thing that is actually at risk:
/// whether what they wrote says what they meant, to 40,000 strangers who
/// cannot ask a follow-up question.
class _BroadcastConfirmDialog extends StatelessWidget {
  final String message;
  final int recipients;

  const _BroadcastConfirmDialog({
    required this.message,
    required this.recipients,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return AlertDialog(
      title: Text(l10n.adminBroadcastConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The preview. Deliberately not styled like the rest of the
          // dialog: it is a picture of another surface, so it keeps the
          // notification's own shape — app icon, tray title, body.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
              border: Border.all(color: ShongjogTheme.hairline(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: ShongjogTheme.iconBadge(context),
                  child: Icon(Icons.campaign_rounded,
                      size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AdminBroadcastService.notificationTitle,
                        style: tt.labelMedium?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(message, style: tt.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.groups_rounded, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.adminBroadcastConfirmBody(
                      numberForLocale(recipients, lang)),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          style: ShongjogTheme.dialogAction(),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        // Red, and in-lock. §12 reserves red for emergency, and this
        // channel's Android tray title is literally "জরুরি ঘোষণা" —
        // emergency announcement. The confirm button is the same colour as
        // the thing it is about to set off.
        FilledButton(
          style: ShongjogTheme.dialogAction().merge(
            FilledButton.styleFrom(
              backgroundColor:
                  ShongjogTheme.toneFill(context, SemanticTone.danger),
              foregroundColor:
                  ShongjogTheme.onToneFill(context, SemanticTone.danger),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.adminBroadcastConfirmAction),
        ),
      ],
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
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _StatCard(info: stats[i])),
        ],
      ],
    );
  }
}

/// Thin adapter onto [AdminStatCard]. The card itself lives in
/// `admin_widgets.dart` so this page and the panel's entry row cannot drift
/// apart again; `_StatInfo` stays here because it is only ever a local way
/// to describe a row declaratively.
class _StatCard extends StatelessWidget {
  final _StatInfo info;
  const _StatCard({required this.info});

  @override
  Widget build(BuildContext context) => AdminStatCard(
        icon: info.icon,
        label: info.label,
        value: info.value,
        tint: info.tint,
      );
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = campaignRequestService.pendingCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminQuickActions,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickChip(
              icon: Icons.campaign_rounded,
              label: l10n.adminReviewCampaigns,
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
                  ? l10n.adminSafetyDanger
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
    final tt = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    return Semantics(
      button: true,
      label: badgeCount > 0
          ? '$label ${numberForLocale(badgeCount, lang)}'
          : label,
      child: Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
        onTap: () => pushNamedSafe(context, route),
        child: Container(
          // §6 puts the floor for a tap target at 48dp. These chips were
          // 8dp of padding around a 16px icon — about 32dp tall, and the
          // only interactive element in the admin section under the floor.
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              // Flexible, not a bare Text: a Wrap hands each child the full
              // row width as its maximum, and `mainAxisSize.min` then sizes
              // this Row to its content — so a label longer than the screen
              // overflows instead of wrapping. Bangla sets wider than the
              // English these chips were sized against, and "প্রচারণা
              // পর্যালোচনা (৩)" already overflowed by 72px at 320dp.
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500, color: cs.onSurface)),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  ),
                  child: Text(
                    numberForLocale(badgeCount, lang),
                    style: tt.labelMedium?.copyWith(
                      color: cs.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
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

  /// Both decisions are other people's map, so both ask first.
  ///
  /// Approving used to be a single unguarded tap that put a pin in front of
  /// every nearby user; rejecting was not offered at all, even though the
  /// model, the service and the `campaignStatusRejected` string all already
  /// supported it — an admin could only ever say yes.
  Future<void> _decide(
    BuildContext context,
    CampaignStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final approving = status == CampaignStatus.approved;
    final ok = await confirmAdminAction(
      context,
      title: approving
          ? l10n.adminConfirmApproveTitle
          : l10n.adminConfirmRejectTitle,
      body: approving
          ? l10n.adminConfirmApproveBody
          : l10n.adminConfirmRejectBody,
      confirmLabel: approving ? l10n.adminApprove : l10n.adminReject,
      tone: approving ? SemanticTone.success : SemanticTone.danger,
    );
    if (!ok) return;
    await campaignRequestService.updateRequestStatus(req.id, status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approving
              ? l10n.adminRequestApproved(req.type.label(context))
              : l10n.adminRequestRejected(req.type.label(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    // Pending = neutral, still-in-progress (brand colour); approved = a
    // genuinely positive state (success); rejected = closed, not alarming,
    // so it takes the muted outline rather than red — red in this app means
    // emergency, and a declined campaign is not one.
    final (tint, statusIcon) = switch (req.status) {
      CampaignStatus.pending => (cs.primary, Icons.hourglass_top_rounded),
      CampaignStatus.approved => (
          ShongjogTheme.toneFill(context, SemanticTone.success),
          Icons.check_rounded
        ),
      CampaignStatus.rejected => (cs.outline, Icons.block_rounded),
    };
    final pending = req.status == CampaignStatus.pending;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: ShongjogTheme.iconBadge(context, tint: tint),
                  child: Icon(statusIcon, color: tint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.type.label(context), style: tt.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${req.userName}\n${req.address}',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Actions sit on their own row rather than in a ListTile
            // trailing slot: two buttons could not fit there, and a Bangla
            // label in a cramped trailing widget was already ellipsising.
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        _decide(context, CampaignStatus.rejected),
                    child: Text(l10n.adminReject),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () =>
                        _decide(context, CampaignStatus.approved),
                    child: Text(l10n.adminApprove),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    return AdminScaffold(
      title: l10n.adminDangerListTitle,
      body: ListenableBuilder(
        listenable: safetyStatusService,
        builder: (context, _) {
          final reports = safetyStatusService.dangerReports;
          if (reports.isEmpty) {
            // Nobody in danger is the best news this screen can carry, so
            // it gets the success tone rather than the neutral grey the
            // other two empty states use.
            return AdminEmptyState(
              icon: Icons.check_circle_rounded,
              message: l10n.adminDangerListEmpty,
              tone: SemanticTone.success,
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
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final timeStr =
        _relativeTime(l10n, lang, DateTime.now().difference(report.timestamp));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
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
                    report.userName?.isNotEmpty == true
                        ? report.userName!
                        : AppLocalizations.of(context).beaconAnonymousReporter,
                    style: tt.titleMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration:
                      ShongjogTheme.toneChip(context, SemanticTone.danger),
                  child: Text(
                    report.dangerType?.label(l10n) ?? '',
                    style: tt.labelMedium?.copyWith(
                      color: ShongjogTheme.toneInk(context, SemanticTone.danger),
                    ),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final uri = Uri.parse(report.mapsLink!);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(l10n.adminDangerOpenMap),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
