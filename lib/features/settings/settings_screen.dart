import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../../core/theme_controller.dart';
import '../audio/sound_service.dart';
import '../chat/chat_store.dart';

/// Settings screen.
///
/// Sections: Appearance → Voice → Emergency → AI Model → Diagnostics → Data → About.
/// Theme is a 3-way [SegmentedButton] (light/dark/system).
/// Model download with live progress is wired via [modelManager].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoRead = true;
  bool _voiceInput = true;
  bool _soundEnabled = true;
  String _dialect = 'bn-BD';
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
        _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
        _dialect = prefs.getString('pref_dialect') ?? 'bn-BD';
        _kbVersion = prefs.getString('kb_version') ?? 'v1.0';
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
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('শব্দ ইঙ্গিত'),
            subtitle: const Text('AI উত্তর প্রস্তুত হলে চিম বাজবে'),
            value: _soundEnabled,
            onChanged: (v) async {
              setState(() => _soundEnabled = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_sound_enabled', v);
              SoundService.instance.setEnabled(v);
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
          _SectionHeader('AI মডেল'),
          _ModelDownloadCard(),
          const _Divider(),
          _SectionHeader('ডায়াগনস্টিকস'),
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
    if (confirmed == true) {
      await ChatStore().clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('চ্যাট ইতিহাস মুছে ফেলা হয়েছে')),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Model Download Card — reactive to ModelManager state
// ════════════════════════════════════════════════════════════════

class _ModelDownloadCard extends StatefulWidget {
  @override
  State<_ModelDownloadCard> createState() => _ModelDownloadCardState();
}

class _ModelDownloadCardState extends State<_ModelDownloadCard> {
  @override
  void initState() {
    super.initState();
    modelManager.addListener(_onModelChanged);
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final onDisk = await modelManager.isOnDisk();
    if (onDisk && mounted) {
      modelManager.markReadyIfOnDisk();
    }
  }

  void _onModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    modelManager.removeListener(_onModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = modelManager.state;
    final progress = modelManager.downloadProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state == ModelState.ready
                    ? Icons.check_circle
                    : state == ModelState.downloading ||
                            state == ModelState.loading
                        ? Icons.downloading_rounded
                        : state == ModelState.failed
                            ? Icons.error_outline
                            : Icons.download_rounded,
                color: state == ModelState.ready
                    ? ShongjogTheme.success
                    : state == ModelState.failed
                        ? ShongjogTheme.alert
                        : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gemma 4 E2B',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      modelManager.statusLabelBn,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (state == ModelState.notDownloaded ||
                  state == ModelState.failed)
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('ডাউনলোড'),
                )
              else if (state == ModelState.ready)
                const Icon(Icons.check_circle,
                    color: ShongjogTheme.success, size: 28)
              else
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (state == ModelState.downloading && progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}% • ~1.5 GB',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    try {
      await modelManager.ensureModel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ডাউনলোড ব্যর্থ: $e')),
        );
      }
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
    // Bold inline header — not an uppercase/tracked eyebrow (which design.md
    // §2 explicitly bans as AI-grammar). Pairs with the title row inside
    // each section to give a clear rhythm without screaming "kicker".
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
          fontFamily: ShongjogTheme.fontFamily,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    // Hairline divider, full-bleed. Hairline, not bold — keeps the list
    // from looking like a Material "settings drawer" from 2014.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Divider(height: 1, thickness: 0.5),
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
                        height: 1.4,
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
