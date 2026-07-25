import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'directory_loader.dart';

/// Offline-first list of national, division, and district
/// emergency phone numbers. Bundled JSON in
/// `assets/emergency/directory.json`. Tap-to-call via
/// [url_launcher] `tel:` URI.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, this.initialDivision});
  final String? initialDivision;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  static Map<String, String> _divisions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <String, String>{
      'all': l10n.allDivisions,
      'dhaka': l10n.emergencyDirDhaka,
      'chattogram': l10n.emergencyDirChattogram,
      'rajshahi': l10n.emergencyDirRajshahi,
      'khulna': l10n.emergencyDirKhulna,
      'barisal': l10n.emergencyDirBarishal,
      'sylhet': l10n.emergencyDirSylhet,
      'rangpur': l10n.emergencyDirRangpur,
      'mymensingh': l10n.emergencyDirMymensingh,
    };
  }

  String _division = 'all';
  List<EmergencyEntry>? _entries;
  bool _loading = true;

  /// Convert Latin digits to Bengali numerals (AGENTS.md).
  String _bn(String s) {
    const map = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }

  @override
  void initState() {
    super.initState();
    _division = widget.initialDivision ?? 'all';
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final entries = await DirectoryLoader.forDivision(_division);
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'police': return Icons.local_police_rounded;
      case 'fire': return Icons.local_fire_department_rounded;
      case 'hospital': return Icons.local_hospital_rounded;
      case 'health': return Icons.medical_services_rounded;
      case 'disaster': return Icons.flood_rounded;
      case 'redcross': return Icons.health_and_safety_rounded;
      case 'helpline': return Icons.support_agent_rounded;
      case 'poison': return Icons.warning_amber_rounded;
      case 'coastguard': return Icons.directions_boat_rounded;
      default: return Icons.phone_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).emergencyNumbers),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cs.surfaceContainerLow,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in _divisions(context).entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.value),
                        selected: _division == entry.key,
                        onSelected: (sel) {
                          if (!sel) return;
                          setState(() => _division = entry.key);
                          _refresh();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_entries == null || _entries!.isEmpty)
                    ? Center(
                        child: Text(AppLocalizations.of(context).noNumbersInDivision),
                      )
                    : ListView.separated(
                        itemCount: _entries!.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = _entries![i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              foregroundColor: cs.onPrimaryContainer,
                              child: Icon(_iconFor(e.type)),
                            ),
                            title: Text(e.nameBn),
                            subtitle: Text(_bn(e.phone)),
                            trailing: IconButton(
                              tooltip: AppLocalizations.of(context).callTooltip,
                              icon: const Icon(Icons.call_rounded),
                              onPressed: () => _call(e.phone),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}