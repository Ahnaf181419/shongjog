import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'family_profile.dart';
import 'form_widgets.dart';
import 'kit_service.dart';

/// AI Emergency Kit Generator screen (Module B).
///
/// Collects family information inline (no bounce to the Planner) and
/// generates a customized supply list with quantities using the
/// on-device Gemma model.
class KitScreen extends StatefulWidget {
  const KitScreen({super.key});

  @override
  State<KitScreen> createState() => _KitScreenState();
}

class _KitScreenState extends State<KitScreen> {
  final _svc = const KitService();

  FamilyProfile? _profile;
  String? _kit;
  bool _loading = false;
  bool _initing = true;
  bool _editing = false;

  // ── Form controllers (ephemeral, pre-populated from profile) ──
  final _familySizeCtrl = TextEditingController(text: '0');
  final _childrenCtrl = TextEditingController(text: '0');
  final _elderlyCtrl = TextEditingController(text: '0');
  final _medicalCtrl = TextEditingController();
  bool _pets = false;
  bool _river = false;
  bool _coast = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _familySizeCtrl.dispose();
    _childrenCtrl.dispose();
    _elderlyCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final p = await FamilyProfile.load();
    if (!mounted) return;
    _syncControllersFromProfile(p);
    setState(() {
      _profile = p;
      _initing = false;
      // Show the form immediately if there's no profile yet.
      _editing = p.isEmpty;
    });
  }

  void _syncControllersFromProfile(FamilyProfile p) {
    _familySizeCtrl.text = '${p.familySize}';
    _childrenCtrl.text = '${p.childrenCount}';
    _elderlyCtrl.text = '${p.elderlyCount}';
    _medicalCtrl.text = p.medicalConditions.join(', ');
    _pets = p.hasPets;
    _river = p.nearbyRiver;
    _coast = p.nearbyCoast;
  }

  /// Build a profile from the current form state, persist it, and
  /// generate the kit. Used by the inline form's generate button.
  Future<void> _saveAndGenerate() async {
    final size = int.tryParse(_familySizeCtrl.text) ?? 0;
    if (size == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).kitFamilySizeHint)),
      );
      return;
    }

    final profile = FamilyProfile(
      familySize: size,
      childrenCount: int.tryParse(_childrenCtrl.text) ?? 0,
      elderlyCount: int.tryParse(_elderlyCtrl.text) ?? 0,
      hasPets: _pets,
      medicalConditions: _medicalCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      nearbyRiver: _river,
      nearbyCoast: _coast,
    );

    setState(() {
      _loading = true;
      _editing = false;
    });

    await FamilyProfile.save(profile);

    final kit = await _svc.generateKit(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _kit = kit;
      _loading = false;
    });
  }

  /// Generate directly from an existing saved profile (summary view).
  Future<void> _generateFromProfile() async {
    if (_profile == null || _profile!.isEmpty) return;
    setState(() => _loading = true);
    final kit = await _svc.generateKit(_profile!);
    if (!mounted) return;
    setState(() {
      _kit = kit;
      _loading = false;
    });
  }

  void _toggleEdit() {
    // Restore form values from the saved profile when canceling.
    if (_editing && _profile != null && !_profile!.isEmpty) {
      _syncControllersFromProfile(_profile!);
    }
    setState(() => _editing = !_editing);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canCancelEdit =
        _editing && _profile != null && !_profile!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kitTitle),
        actions: canCancelEdit
            ? [
                IconButton(
                  onPressed: _toggleEdit,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.kitEditFamily,
                ),
              ]
            : null,
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_initing || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_kit != null) {
      return _ResultView(
        kit: _kit!,
        onReset: () => setState(() => _kit = null),
      );
    }
    if (_editing) {
      return _buildForm(l10n);
    }
    return _buildSummary(l10n);
  }

  // ── Inline family form ──────────────────────────────────────────

  Widget _buildForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.plannerFamilyInfo),
          StepperRow(
              label: l10n.plannerTotalMembers,
              controller: _familySizeCtrl,
              max: 20),
          StepperRow(
              label: l10n.plannerChildren, controller: _childrenCtrl, max: 15),
          StepperRow(
              label: l10n.plannerElderly, controller: _elderlyCtrl, max: 15),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(l10n.kitMoreOptions),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToggleRow(
                        label: l10n.plannerHasPets,
                        value: _pets,
                        onChanged: (v) => setState(() => _pets = v)),
                    SectionLabel(l10n.plannerMedicalConditions),
                    TextField(
                      controller: _medicalCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.plannerMedicalHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    ToggleRow(
                        label: l10n.plannerNearbyRiver,
                        value: _river,
                        onChanged: (v) => setState(() => _river = v)),
                    ToggleRow(
                        label: l10n.plannerNearCoast,
                        value: _coast,
                        onChanged: (v) => setState(() => _coast = v)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveAndGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(l10n.kitGenerateButton),
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact profile summary + generate ──────────────────────────

  Widget _buildSummary(AppLocalizations l10n) {
    final p = _profile!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.luggage_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SummaryChip(l10n.kitSummaryMembers(p.familySize)),
                if (p.childrenCount > 0)
                  _SummaryChip(l10n.kitSummaryChildren(p.childrenCount)),
                if (p.elderlyCount > 0)
                  _SummaryChip(l10n.kitSummaryElderly(p.elderlyCount)),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _toggleEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.kitEditFamily),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _generateFromProfile,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(l10n.kitGenerateButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary chip ─────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  const _SummaryChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Result view ──────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final String kit;
  final VoidCallback onReset;
  const _ResultView({required this.kit, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.kitAiKit,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(kit, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.kitRetry),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.kitDone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
