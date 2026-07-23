
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/model_manager.dart';
import '../../core/theme_controller.dart';
import '../admin/map_picker_screen.dart';
import '../audio/sound_service.dart';
import '../chat/chat_store.dart';
import '../profile/profile_screen.dart';
import 'model_picker_section.dart';
import '../../core/admin_broadcast_service.dart';
import '../../features/admin/campaign_request.dart';

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
  bool _showInsights = true;
  String? _kbVersion;
  UserProfileData _profile = UserProfileData.empty;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_dialect');
    final profile = await UserProfileData.load();
    if (mounted) {
      setState(() {
        _autoRead = prefs.getBool('pref_auto_read') ?? false;
        _voiceInput = prefs.getBool('pref_voice_input') ?? true;
        _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
        _showInsights = prefs.getBool('pref_show_insights') ?? true;
        _kbVersion = prefs.getString('kb_version') ?? 'v1.0';
        _profile = profile;
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
          // ── Profile row ──
          _ProfileRow(profile: _profile, onChanged: _loadPrefs),
          const _Divider(),
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
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_rounded),
            title: const Text('প্রস্তুতি পরামর্শ'),
            subtitle: const Text('চ্যাট ইতিহাস অনুযায়ী হোম স্ক্রিনে পরামর্শ কার্ড'),
            value: _showInsights,
            onChanged: (v) async {
              setState(() => _showInsights = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_show_insights', v);
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
          _SectionHeader('অভিযান অনুরোধ'),
          ListTile(
            leading: const Icon(Icons.campaign_rounded),
            title: const Text('দান/উদ্ধার অভিযান অনুরোধ করুন'),
            subtitle: const Text('অ্যাডমিন অনুমোদনে মানচিত্রে দেখাবে'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showCampaignRequestDialog,
          ),
          const _Divider(),
          _SectionHeader('AI মডেল'),
          const ModelPickerSection(),
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
          // Only shown once the on-device model has actually failed to load.
          // Without it, a broken Tier 2 looks identical to a working one:
          // the chat just quietly answers from the corpus.
          ListenableBuilder(
            listenable: modelManager,
            builder: (context, _) {
              final err = modelManager.lastInitError;
              if (err == null) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('অফলাইন AI চালু হয়নি'),
                subtitle: Text(
                  err,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('অফলাইন AI ত্রুটি'),
                    content: SelectableText(err),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('বন্ধ করুন'),
                      ),
                    ],
                  ),
                ),
              );
            },
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
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_rounded),
            title: const Text('অ্যাডমিন লগইন'),
            subtitle: const Text('বার্তা ব্রডকাস্ট এবং ব্যবস্থাপনা'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pushNamedSafe(context, AppRoutes.adminLogin),
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
      await adminBroadcastService.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ক্যাশ মুছে ফেলা হয়েছে')),
        );
      }
    }
  }

  Future<void> _showCampaignRequestDialog() async {
    final addressController = TextEditingController();
    final landmarkController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    CampaignType selectedType = CampaignType.foodDonation;
    LatLng? selectedLocation;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('অভিযান অনুরোধ জমা দিন'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<CampaignType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'অভিযানের ধরন',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: CampaignType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.labelBn),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                      validator: (v) => v == null ? 'ধরন বেছে নিন' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Map picker button ──
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push<LatLng>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapPickerScreen(
                                initialLocation: selectedLocation,
                              ),
                            ),
                          );
                          if (result != null) {
                            setDialogState(() => selectedLocation = result);
                          }
                        },
                        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedLocation != null
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.06)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(ShongjogTheme.radius),
                            border: Border.all(
                              color: selectedLocation != null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selectedLocation != null
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  selectedLocation != null
                                      ? Icons.check_circle_rounded
                                      : Icons.map_rounded,
                                  color: selectedLocation != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedLocation != null
                                          ? 'অবস্থান নির্বাচিত'
                                          : 'মানচিত্র থেকে অবস্থান নির্বাচন করুন',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedLocation != null
                                          ? '${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}'
                                          : 'ট্যাপ করে মানচিত্রে পিন দিন',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'ঠিকানা/স্থান',
                        prefixIcon: Icon(Icons.location_on_rounded),
                        hintText: 'যেমন: ঢাকা মেডিকেল কলেজ হাসপাতাল',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'ঠিকানা লিখুন' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: landmarkController,
                      decoration: const InputDecoration(
                        labelText: 'স্পষ্ট ঠিকানা/ল্যান্ডমার্ক',
                        prefixIcon: Icon(Icons.place_rounded),
                        hintText: 'যেমন: মসজিদের পাশে, দোকান নম্বর ১২',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'বিবরণ (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.description_rounded),
                        hintText: 'অভিযানের লক্ষ্য, সময়, যোগাযোগ নম্বর ইত্যাদি',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('মানচিত্র থেকে অবস্থান নির্বাচন করুন'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final request = CampaignRequest(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  userId: 'local_user',
                  userName: 'ব্যবহারকারী',
                  userPhone: '',
                  type: selectedType,
                  latitude: selectedLocation!.latitude,
                  longitude: selectedLocation!.longitude,
                  address: addressController.text.trim(),
                  landmark: landmarkController.text.trim(),
                  description: descController.text.trim(),
                  timestamp: DateTime.now(),
                );

                await campaignRequestService.submitRequest(request);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('অভিযান অনুরোধ জমা দেওয়া হয়েছে')),
                  );
                }
              },
              child: const Text('জমা দিন'),
            ),
          ],
        ),
      ),
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

class _ProfileRow extends StatelessWidget {
  final UserProfileData profile;
  final VoidCallback? onChanged;
  const _ProfileRow({required this.profile, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPhoto = profile.hasPhoto;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, AppRoutes.profile);
          onChanged?.call();
        },
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? Image.file(
                          File(profile.photoPath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: profile.initial.isNotEmpty
                              ? Text(
                                  profile.initial,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 24,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isNotEmpty ? profile.name : 'প্রোফাইল সেট করুন',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: ShongjogTheme.fontFamily,
                        color: profile.name.isNotEmpty
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    if (profile.district != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.district!,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: ShongjogTheme.fontFamily,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
