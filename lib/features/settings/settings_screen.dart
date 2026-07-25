
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/locale_controller.dart';
import '../../core/model_manager.dart';
import '../../core/theme_controller.dart';
import '../../l10n/app_localizations.dart';
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Profile row ──
          _ProfileRow(profile: _profile, onChanged: _loadPrefs),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionAppearance),
          _ThemeSegmentedRow(controller: tc),
          _LanguageSegmentedRow(controller: localeController),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionVoice),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(AppLocalizations.of(context).autoRead),
            subtitle: Text(AppLocalizations.of(context).autoReadDesc),
            value: _autoRead,
            onChanged: (v) async {
              setState(() => _autoRead = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_auto_read', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic_rounded),
            title: Text(AppLocalizations.of(context).voiceInput),
            subtitle: Text(AppLocalizations.of(context).voiceInputDesc),
            value: _voiceInput,
            onChanged: (v) async {
              setState(() => _voiceInput = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_voice_input', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(AppLocalizations.of(context).soundHint),
            subtitle: Text(AppLocalizations.of(context).soundHintDesc),
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
            title: Text(AppLocalizations.of(context).prepTips),
            subtitle: Text(AppLocalizations.of(context).prepTipsDesc),
            value: _showInsights,
            onChanged: (v) async {
              setState(() => _showInsights = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_show_insights', v);
            },
          ),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionEmergency),
          ListTile(
            leading: const Icon(Icons.contacts_rounded),
            title: Text(AppLocalizations.of(context).emergencyContacts),
            subtitle: Text(AppLocalizations.of(context).emergencyContactsDesc),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                pushNamedSafe(context, AppRoutes.emergencyContacts),
          ),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionCampaign),
          ListTile(
            leading: const Icon(Icons.campaign_rounded),
            title: Text(AppLocalizations.of(context).campaignRequest),
            subtitle: Text(AppLocalizations.of(context).campaignRequestDesc),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showCampaignRequestDialog,
          ),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionAiModel),
          const ModelPickerSection(),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionDiagnostics),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(AppLocalizations.of(context).kbVersion),
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
                title: Text(AppLocalizations.of(context).offlineAiFailed),
                subtitle: Text(
                  err,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(AppLocalizations.of(context).offlineAiError),
                    content: SelectableText(err),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(AppLocalizations.of(context).close),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const _Divider(),
          _SectionHeader(AppLocalizations.of(context).sectionInfo),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: Text(AppLocalizations.of(context).clearCache),
            subtitle: Text(AppLocalizations.of(context).clearCacheDesc),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: Text(AppLocalizations.of(context).aboutApp),
            subtitle: Text(AppLocalizations.of(context).aboutAppDesc),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pushNamedSafe(context, AppRoutes.about),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_rounded),
            title: Text(AppLocalizations.of(context).adminLogin),
            subtitle: Text(AppLocalizations.of(context).adminLoginDesc),
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
        title: Text(AppLocalizations.of(context).clearCacheConfirmTitle),
        content: Text(AppLocalizations.of(context).clearCacheConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ChatStore().clear();
      await adminBroadcastService.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cacheCleared)),
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
          title: Text(AppLocalizations.of(context).campaignDialogTitle),
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
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).campaignTypeLabel,
                        prefixIcon: const Icon(Icons.category_rounded),
                      ),
                      items: CampaignType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label(context)),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                      validator: (v) => v == null ? AppLocalizations.of(context).campaignTypeValidator : null,
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
                                          ? AppLocalizations.of(context).campaignLocationSelected
                                          : AppLocalizations.of(context).campaignLocationPrompt,
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
                                          : AppLocalizations.of(context).campaignLocationTap,
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
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).campaignAddress,
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        hintText: AppLocalizations.of(context).campaignAddressHint,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? AppLocalizations.of(context).campaignAddressValidator : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: landmarkController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).campaignLandmark,
                        prefixIcon: const Icon(Icons.place_rounded),
                        hintText: AppLocalizations.of(context).campaignLandmarkHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).campaignDescLabel,
                        prefixIcon: const Icon(Icons.description_rounded),
                        hintText: AppLocalizations.of(context).campaignDescHint,
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
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).campaignLocationRequired),
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
                    SnackBar(content: Text(AppLocalizations.of(context).campaignSubmitted)),
                  );
                }
              },
              child: Text(AppLocalizations.of(context).campaignSubmit),
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
                      profile.name.isNotEmpty ? profile.name : AppLocalizations.of(context).profileSet,
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
                    Text(AppLocalizations.of(context).themeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).themeDesc,
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
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_rounded),
                  label: Text(AppLocalizations.of(context).themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_rounded),
                  label: Text(AppLocalizations.of(context).themeDark),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_rounded),
                  label: Text(AppLocalizations.of(context).themeSystem),
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

class _LanguageSegmentedRow extends StatelessWidget {
  final LocaleController controller;
  const _LanguageSegmentedRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).languageLabel,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).languageDesc,
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
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'bn',
                  label: Text(AppLocalizations.of(context).langBn),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text(AppLocalizations.of(context).langEn),
                ),
              ],
              selected: {controller.languageCode},
              onSelectionChanged: (s) {
                final locale = switch (s.first) {
                  'en' => const Locale('en'),
                  _ => const Locale('bn'),
                };
                controller.setLocale(locale);
              },
            ),
          ),
        ],
      ),
    );
  }
}
