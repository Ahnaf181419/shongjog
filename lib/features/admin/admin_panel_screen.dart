import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../features/mesh_comm/mesh_service.dart';

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
        title: const Text('লগআট করবেন?'),
        content: const Text('আপনি কি অ্যাডমিন প্যানেল থেকে বের হতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('লগআট'),
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
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('অ্যাডমিন প্যানেল'),
            actions: [
              IconButton(
                tooltip: 'লগআট',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () async {
                  final shouldLogout = await _confirmLogout();
                  if (shouldLogout) _logout();
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'ড্যাশবোর্ড'),
                Tab(text: 'ব্যবহারকারী'),
                Tab(text: 'বার্তা ব্রডকাস্ট'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _DashboardTab(),
              _UsersTab(),
              _BroadcastTab(),
            ],
          ),
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
