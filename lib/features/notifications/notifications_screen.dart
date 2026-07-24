import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/admin_broadcast_service.dart';
import '../../l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _hasMarkedRead = false;

  @override
  void initState() {
    super.initState();
    adminBroadcastService.addListener(_onChange);
    if (!_hasMarkedRead) {
      _hasMarkedRead = true;
      adminBroadcastService.markAllAsRead();
    }
  }

  @override
  void dispose() {
    adminBroadcastService.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String _formatTimestamp(BuildContext context, DateTime ts) {
    const bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String bn(int n) => n.toString().split('').map((d) => bnDigits[int.parse(d)]).join();
    final now = DateTime.now();
    final diff = now.difference(ts);
    final l10n = AppLocalizations.of(context);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(bn(diff.inMinutes));
    if (diff.inHours < 24) return l10n.hoursAgo(bn(diff.inHours));
    return '${bn(ts.day)}/${bn(ts.month)}/${bn(ts.year)}';
  }

  @override
  Widget build(BuildContext context) {
    final messages = adminBroadcastService.messages;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).notificationsTitle)),
      body: messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).noNewMessages,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _NotificationTile(
                  message: msg,
                  timestamp: _formatTimestamp(context, msg.timestamp),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AdminMessage message;
  final String timestamp;

  const _NotificationTile({
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: message.isRead
          ? ShongjogTheme.cardDecoration(context)
          : BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(ShongjogTheme.radius),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 12),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: message.isRead ? FontWeight.w400 : FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
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
