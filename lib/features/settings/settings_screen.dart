import 'dart:io';

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
  String? _kbVersion;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_dialect');
    if (mounted) {
      setState(() {
        _autoRead = prefs.getBool('pref_auto_read') ?? true;
        _voiceInput = prefs.getBool('pref_voice_input') ?? true;
        _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
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
    final scheme = Theme.of(context).colorScheme;

    final spec = _stateSpec(context, state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StateAvatar(icon: spec.icon, tint: spec.tint, state: state),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Gemma 4 E2B',
                            style: TextStyle(
                              fontFamily: ShongjogTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: spec.pillLabel, tint: spec.tint),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      style: TextStyle(
                        fontFamily: ShongjogTheme.fontFamily,
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: state == ModelState.downloading
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _DownloadProgress(progress: progress ?? 0),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _Actions(
              state: state,
              onDownload: _startDownload,
              onPrime: _primeModel,
              onDelete: _deleteModel,
            ),
          ),
        ],
      ),
    );
  }

  _StateSpec _stateSpec(BuildContext context, ModelState state) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ocean = isLight ? ShongjogTheme.ocean : ShongjogTheme.oceanBright;
    final success =
        isLight ? ShongjogTheme.success : ShongjogTheme.successBright;
    final alert = isLight ? ShongjogTheme.alert : ShongjogTheme.alertBright;

    switch (state) {
      case ModelState.ready:
        return _StateSpec(
          icon: Icons.check_circle_rounded,
          tint: success,
          pillLabel: 'প্রস্তুত',
          subtitle: 'ডিস্কে প্রস্তুত আছে — চ্যাটে ব্যবহার করুন',
        );
      case ModelState.downloading:
        return _StateSpec(
          icon: Icons.downloading_rounded,
          tint: ocean,
          pillLabel: 'ডাউনলোড হচ্ছে',
          subtitle: 'int4 · ~১.৮৭ GB — সংযোগ রাখুন',
        );
      case ModelState.loading:
        return _StateSpec(
          icon: Icons.memory_rounded,
          tint: ocean,
          pillLabel: 'প্রস্তুত হচ্ছে…',
          subtitle: 'মডেল RAM-এ লোড হচ্ছে',
        );
      case ModelState.failed:
        return _StateSpec(
          icon: Icons.error_outline_rounded,
          tint: alert,
          pillLabel: 'ব্যর্থ',
          subtitle: 'পুনরায় চেষ্টা করতে নিচের বোতাম চাপুন',
        );
      case ModelState.notDownloaded:
        return _StateSpec(
          icon: Icons.psychology_rounded,
          tint: ocean,
          pillLabel: 'প্রস্তুত নয়',
          subtitle: 'int4 · ~১.৮৭ GB — চ্যাটের জন্য ডাউনলোড প্রয়োজন',
        );
    }
  }

  Future<void> _startDownload() async {
    try {
      await modelManager.ensureModel();
    } catch (e) {
      _toast('ডাউনলোড ব্যর্থ: $e');
    }
  }

  Future<void> _primeModel() async {
    try {
      await modelManager.initialize();
    } catch (e) {
      _toast('মডেল লোড ব্যর্থ: $e');
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('মডেল মুছে ফেলবেন?'),
        content: const Text(
          'ডাউনলোড করা মডেল ফাইল (~১.৮৭ GB) মুছে যাবে। পরে আবার ডাউনলোড করতে হবে।',
        ),
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
    if (confirmed != true) return;

    try {
      final path = await modelManager.modelPath();
      final f = File(path);
      if (await f.exists()) await f.delete();
      modelManager.reset();
      _toast('মডেল মুছে ফেলা হয়েছে');
    } catch (e) {
      _toast('মুছতে সমস্যা: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _StateSpec {
  final IconData icon;
  final Color tint;
  final String pillLabel;
  final String subtitle;

  const _StateSpec({
    required this.icon,
    required this.tint,
    required this.pillLabel,
    required this.subtitle,
  });
}

class _StateAvatar extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final ModelState state;

  const _StateAvatar({
    required this.icon,
    required this.tint,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isLight ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
      ),
      alignment: Alignment.center,
      child: state == ModelState.downloading || state == ModelState.loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(tint),
              ),
            )
          : Icon(icon, color: tint, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color tint;

  const _StatusPill({required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isLight ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ShongjogTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tint,
          height: 1.1,
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  const _DownloadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pct%',
              style: TextStyle(
                fontFamily: ShongjogTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            Text(
              '~১.৮৭ GB',
              style: TextStyle(
                fontFamily: ShongjogTheme.fontFamily,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final ModelState state;
  final VoidCallback onDownload;
  final VoidCallback onPrime;
  final VoidCallback onDelete;

  const _Actions({
    required this.state,
    required this.onDownload,
    required this.onPrime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (state) {
      case ModelState.notDownloaded:
      case ModelState.failed:
        content = SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('ডাউনলোড'),
          ),
        );
        break;
      case ModelState.downloading:
      case ModelState.loading:
        content = const SizedBox(width: double.infinity, height: 0);
        break;
      case ModelState.ready:
        content = Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('মুছে ফেলুন'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShongjogTheme.bodySecondary(context),
                  side: BorderSide(color: ShongjogTheme.hairline(context)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPrime,
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: const Text('AI চালু করুন'),
              ),
            ),
          ],
        );
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: state == ModelState.ready ? 14 : 12),
      child: content,
    );
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
