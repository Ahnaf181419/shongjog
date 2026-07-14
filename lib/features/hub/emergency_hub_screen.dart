import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../emergency/emergency_sheet.dart';

/// Home screen — the navigation hub. Three primary tiles + about link.
/// Every tile is one tap to its destination. No dead ends.
///
/// Per design.md §7.6: calmTeal tiles, alertRed for emergency, chevrons.
class EmergencyHubScreen extends StatelessWidget {
  const EmergencyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সংযোগ'),
        actions: [
          IconButton(
            tooltip: 'তথ্যসূত্র',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.pushNamed(context, '/about'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShongjogTheme.calmTeal,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'জরুরি সহায়তা সঙ্গে আছে',
                  style: TextStyle(
                    color: ShongjogTheme.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'অফলাইনে কাজ করে • বাংলায় কথা বলে',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _HubTile(
            icon: Icons.chat_bubble_outline,
            titleBn: 'AI সহায়ক',
            subtitleBn: 'প্রশ্ন করুন — বাংলায় উত্তর পাবেন',
            onTap: () => Navigator.pushNamed(context, '/chat'),
            color: ShongjogTheme.calmTeal,
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.style_outlined,
            titleBn: 'জরুরি কার্ড',
            subtitleBn: 'ORS, পানি, সাপের কামড় — দ্রুত নির্দেশিকা',
            onTap: () => Navigator.pushNamed(context, '/cards'),
            color: ShongjogTheme.calmTeal,
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.shield_outlined,
            titleBn: 'নিকটস্থ আশ্রয়কেন্দ্র',
            subtitleBn: 'জিপিএস থেকে নিকটস্থ সাইক্লোন শেল্টার',
            onTap: () => Navigator.pushNamed(context, '/shelter'),
            color: ShongjogTheme.calmTeal,
          ),
          const SizedBox(height: 12),
          _HubTile(
            icon: Icons.call,
            titleBn: 'জরুরি কল (৯৯৯)',
            subtitleBn: 'এক ট্যাপে জরুরি সেবায় কল',
            onTap: () => EmergencySheet.show(context),
            color: ShongjogTheme.alertRed,
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String titleBn;
  final String subtitleBn;
  final VoidCallback onTap;
  final Color color;

  const _HubTile({
    required this.icon,
    required this.titleBn,
    required this.subtitleBn,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: ShongjogTheme.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleBn,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ShongjogTheme.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleBn,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}