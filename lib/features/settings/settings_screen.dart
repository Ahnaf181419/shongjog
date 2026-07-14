import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/theme_controller.dart';
///
/// Sections: Appearance → Voice → Emergency → Diagnostics → Data → About.
/// Theme is a 3-way [SegmentedButton] (light/dark/system).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoRead = true;
  bool _voiceInput = true;
  String _dialect = 'bn-BD';
  String? _modelStatus;
  String? _kbVersion;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoRead = prefs.getBool('pref_auto_read') ?? true;
        _voiceInput = prefs.getBool('pref_voice_input') ?? true;
        _dialect = prefs.getString('pref_dialect') ?? 'bn-BD';
        _kbVersion = prefs.getString('kb_version') ?? 'v1.0';
        _modelStatus = prefs.getBool('model_downloaded') == true
            ? 'প্রস্তুত'
            : 'ডাউনলোড প্রয়োজন';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = themeController;

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('উপস্থিতি'),
          _ThemeSegmentedRow(controller: tc),
          const _Divider(),
          _SectionHeader('ভয়েস'),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: const Text('স্বয়ংক্রিয় পঠন'),
            subtitle: const Text('AI উত্তর স্বয়ংক্রিয়ভাবে পড়ে শোনাবে'),
            value: _autoRead,
            onChanged: (v) async {
              setState(() => _autoRead = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_auto_read', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic_rounded),
            title: const Text('ভয়েস ইনপুট'),
            subtitle: const Text('কথা বলে প্রশ্ন করুন'),
            value: _voiceInput,
            onChanged: (v) async {
              setState(() => _voiceInput = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_voice_input', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: const Text('উপভাষা'),
            trailing: DropdownButton<String>(
              value: _dialect,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'bn-BD', child: Text('বাংলাদেশি')),
                DropdownMenuItem(value: 'bn-IN', child: Text('ভারতীয়')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _dialect = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('pref_dialect', v);
              },
            ),
          ),
          const _Divider(),
          _SectionHeader('জরুরি'),
          ListTile(
            leading: const Icon(Icons.contacts_rounded),
            title: const Text('জরুরি পরিচিতি'),
            subtitle: const Text('জাতীয় নম্বর ও নিজের পরিচিতি'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                pushNamedSafe(context, AppRoutes.emergencyContacts),
          ),
          const _Divider(),
          _SectionHeader('ডায়াগনস্টিকস'),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text('AI মডেল'),
            trailing: Text(
              _modelStatus ?? '—',
              style: TextStyle(
                fontFamily: ShongjogTheme.fontFamily,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('তথ্যকোষ সংস্করণ'),
            trailing: Text(
              _kbVersion ?? '—',
              style: TextStyle(
                fontFamily: ShongjogTheme.fontFamily,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const _Divider(),
          _SectionHeader('তথ্য'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text('ক্যাশ মুছুন'),
            subtitle: const Text('চ্যাট ইতিহাস মুছে ফেলুন'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: const Text('অ্যাপ সম্পর্কে'),
            subtitle: const Text('তথ্যসূত্র, লাইসেন্স, সংস্করণ'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pushNamedSafe(context, AppRoutes.about),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ক্যাশ মুছুন?'),
        content: const Text('সব চ্যাট ইতিহাস মুছে যাবে। এটি পূর্বাবস্থায় ফেরানো যাবে না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চ্যাট ইতিহাস মুছে ফেলা হয়েছে')),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: ShongjogTheme.fontFamily,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Divider(),
    );
  }
}

class _ThemeSegmentedRow extends StatelessWidget {
  final ThemeController controller;
  const _ThemeSegmentedRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('থিম',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      'লাইট, ডার্ক, বা সিস্টেম অনুসরণ',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: ShongjogTheme.fontFamily,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('লাইট'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('ডার্ক'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('সিস্টেম'),
                ),
              ],
              selected: {controller.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
