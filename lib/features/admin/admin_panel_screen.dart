import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../features/intelligence/proximity_notification_service.dart';
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
      builder: (ctx) => AlertDialog(
        title: const Text('লগআউট করবেন?'),
        content: const Text('আপনি কি অ্যাডমিন প্যানেল থেকে বের হতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('লগআউট'),
          ),
        ],
      ),
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('অ্যাডমিন প্যানেল'),
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
                    tooltip: 'লগআউট',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () async {
                      final shouldLogout = await _confirmLogout();
                      if (shouldLogout) _logout();
                    },
                  ),
                ],
              ),
              body: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildGridCard(
                    context,
                    title: 'ড্যাশবোর্ড',
                    icon: Icons.dashboard_rounded,
                    content: const _DashboardTab(),
                  ),
                  _buildGridCard(
                    context,
                    title: 'ব্যবহারকারী',
                    icon: Icons.people_rounded,
                    content: const _UsersTab(),
                  ),
                  _buildGridCard(
                    context,
                    title: 'অভিযান অনুরোধ',
                    icon: Icons.campaign_rounded,
                    badgeCount: pendingCount,
                    content: _CampaignRequestsTab(pendingCount: pendingCount),
                  ),
                  _buildGridCard(
                    context,
                    title: 'বার্তা ব্রডকাস্ট',
                    icon: Icons.podcasts_rounded,
                    content: const _BroadcastTab(),
                  ),
                ],
              ),
          );
        },
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, {required String title, required IconData icon, required Widget content, int? badgeCount}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: content,
              ),
            ),
          );
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _bnNum(badgeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

// ── Bengali numeral helper ──────────────────────────────────

String _bnNum(int n) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return n.toString().split('').map((d) => digits[int.parse(d)]).join();
}

// ── Dashboard Tab ───────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          icon: Icons.people_rounded,
          label: 'মোট ব্যবহারকারী',
          value: '৫',
          tint: cs.primary,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.offline_bolt_rounded,
          label: 'অফলাইন সেশন',
          value: '৩',
          tint: cs.tertiary,
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.bluetooth_rounded,
          label: 'মেশ পিয়ার',
          value: _bnNum(meshService.peerCount),
          tint: cs.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ShongjogTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShongjogTheme.iconBadge(context, tint: tint),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
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

// ── Users Tab ───────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final peers = meshService.peerList;

    if (peers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_rounded, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              'কোনো সংযুক্ত ডিভাইস নেই',
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
          title: Text(peer.name.isNotEmpty ? peer.name : 'অজ্ঞাত ডিভাইস'),
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

// ── Campaign Requests Tab ───────────────────────────────────

class _CampaignRequestsTab extends StatefulWidget {
  final int pendingCount;
  const _CampaignRequestsTab({required this.pendingCount});

  @override
  State<_CampaignRequestsTab> createState() => _CampaignRequestsTabState();
}

class _CampaignRequestsTabState extends State<_CampaignRequestsTab> {
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

  String _formatTimestamp(DateTime ts) {
    const bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String bn(int n) => n.toString().split('').map((d) => bnDigits[int.parse(d)]).join();
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'এইমাত্র';
    if (diff.inMinutes < 60) return '${bn(diff.inMinutes)} মিনিট আগে';
    if (diff.inHours < 24) return '${bn(diff.inHours)} ঘণ্টা আগে';
    return '${bn(ts.day)}/${bn(ts.month)}/${bn(ts.year)}';
  }

  Color _statusColor(BuildContext context, CampaignStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case CampaignStatus.pending:
        return cs.tertiary;
      case CampaignStatus.approved:
        return ShongjogTheme.success;
      case CampaignStatus.rejected:
        return ShongjogTheme.alert;
    }
  }

  String _statusLabel(CampaignStatus status) {
    return status.labelBn;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final requests = campaignRequestService.requests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              'কোনো অভিযান অনুরোধ নেই',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _CampaignRequestTile(
          request: request,
          timestamp: _formatTimestamp(request.timestamp),
          statusColor: _statusColor(context, request.status),
          statusLabel: _statusLabel(request.status),
          onTap: () => _showDetailDialog(context, request),
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, CampaignRequest request) {
    final cs = Theme.of(context).colorScheme;
    final campaignLoc = LatLng(request.latitude, request.longitude);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor(context, request.status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          request.type == CampaignType.rescueOperation
                              ? Icons.search_rounded
                              : Icons.volunteer_activism_rounded,
                          color: _statusColor(context, request.status),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.type.labelBn,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(context, request.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _statusLabel(request.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(context, request.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Mini map ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      child: IgnorePointer(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: campaignLoc,
                            initialZoom: 14,
                            interactionOptions:
                                const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.shongjog.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: campaignLoc,
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cs.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.25),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 20,
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

                // ── Details ──
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('ব্যবহারকারী', request.userName),
                      _detailRow('ফোন',
                          request.userPhone.isEmpty ? '—' : request.userPhone),
                      _detailRow('ঠিকানা', request.address),
                      if (request.landmark.isNotEmpty)
                        _detailRow('ল্যান্ডমার্ক', request.landmark),
                      _detailRow('স্থানাঙ্ক',
                          '${request.latitude.toStringAsFixed(4)}, ${request.longitude.toStringAsFixed(4)}'),
                      _detailRow('সময়', _formatTimestamp(request.timestamp)),
                      if (request.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('বিবরণ',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(request.description,
                            style: TextStyle(
                                fontSize: 14, color: cs.onSurface)),
                      ],
                      if (request.adminNotes != null &&
                          request.adminNotes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('অ্যাডমিন নোট',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(request.adminNotes!,
                            style: TextStyle(
                                fontSize: 14, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),

                // ── Action buttons ──
                if (request.status == CampaignStatus.pending)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final notes = await _showNotesDialog(
                                  context, 'প্রত্যাখ্যাত');
                              if (notes != null && context.mounted) {
                                await campaignRequestService.updateRequestStatus(
                                  request.id,
                                  CampaignStatus.rejected,
                                  adminNotes: notes,
                                );
                              }
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('প্রত্যাখ্যাত'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                              side: BorderSide(color: cs.error),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await campaignRequestService.updateRequestStatus(
                                request.id,
                                CampaignStatus.approved,
                                adminNotes: null,
                              );
                              // Trigger proximity check for nearby users
                              _fireProximityNotification(request);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${request.type.labelBn} অনুমোদিত — মানচিত্রে যোগ করা হয়েছে'),
                                    backgroundColor: ShongjogTheme.success,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('অনুমোদন'),
                            style: FilledButton.styleFrom(
                              backgroundColor: ShongjogTheme.success,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const.fromLTRB(20, 0, 20, 20),
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('বন্ধ করুন'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _fireProximityNotification(CampaignRequest request) async {
    try {
      final pos = await ProximityNotificationService.checkProximity(
        userPosition: await _getPosition(),
        approvedCampaigns: [request],
        radiusKm: 999, // Always fire on approval
      );
      if (pos.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'নিকটস্থ ব্যবহারকারীদের বিজ্ঞপ্তি পাঠানো হয়েছে'),
            backgroundColor: ShongjogTheme.success,
          ),
        );
      }
    } catch (_) {
      // Proximity check is best-effort
    }
  }

  Future<Position> _getPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return Position(
        latitude: 23.8103,
        longitude: 90.4125,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  Future<String?> _showNotesDialog(BuildContext context, String action) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action নোট (ঐচ্ছিক)'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'নোট লিখুন...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _CampaignRequestTile extends StatelessWidget {
  final CampaignRequest request;
  final String timestamp;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;

  const _CampaignRequestTile({
    required this.request,
    required this.timestamp,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = request.status == CampaignStatus.pending;

    // Build summary snippet from available data
    final List<String> summaryParts = [];
    summaryParts.add(request.address);
    if (request.landmark.isNotEmpty) summaryParts.add(request.landmark);
    final summary = summaryParts.join(' — ');

    // Description snippet (first 60 chars)
    final descSnippet = request.description.isNotEmpty
        ? (request.description.length > 60
            ? '${request.description.substring(0, 60)}…'
            : request.description)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isPending
            ? cs.primary.withValues(alpha: 0.06)
            : ShongjogTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
          top: BorderSide(
            color: isPending
                ? cs.primary.withValues(alpha: 0.2)
                : ShongjogTheme.hairline(context),
          ),
          right: BorderSide(
            color: isPending
                ? cs.primary.withValues(alpha: 0.2)
                : ShongjogTheme.hairline(context),
          ),
          bottom: BorderSide(
            color: isPending
                ? cs.primary.withValues(alpha: 0.2)
                : ShongjogTheme.hairline(context),
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Leading icon ──
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: request.type == CampaignType.rescueOperation
                      ? ShongjogTheme.alert.withValues(alpha: 0.1)
                      : cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.type == CampaignType.rescueOperation
                      ? Icons.search_rounded
                      : Icons.volunteer_activism_rounded,
                  color: request.type == CampaignType.rescueOperation
                      ? ShongjogTheme.alert
                      : cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Row 1: Type + status chip ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.type.labelBn,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // ── Row 2: Location summary ──
                    Row(
                      children: [
                        Icon(Icons.place_rounded,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // ── Row 3: Description snippet (if present) ──
                    if (descSnippet != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.description_rounded,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              descSnippet,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    // ── Row 4: Timestamp ──
                    Text(
                      timestamp,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Trailing arrow ──
              if (isPending)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: cs.onSurfaceVariant)
              else
                Icon(
                  request.status == CampaignStatus.approved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 20,
                  color: statusColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Broadcast Tab ───────────────────────────────────────────

class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
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
    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বার্তা পাঠানো হয়েছে')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'গ্লোবাল ব্রডকাস্ট',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'সব ব্যবহারকারীকে একটি বার্তা পাঠান',
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
            label: const Text('বার্তা পাঠান'),
          ),
        ],
      ),
    );
  }
}