import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'family_profile.dart';
import 'form_widgets.dart';
import 'planner_service.dart';

/// AI Family Disaster Planner screen (Module A in docs/AI-FIRST-FEATURES.md).
///
/// Two phases:
/// 1. Questionnaire form — collects family data into a FamilyProfile.
/// 2. Generated plan — calls PlannerService, renders the Bangla plan.
///
/// The profile is saved to SharedPreferences on generate so the Kit
/// and Risk modules can reuse it.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _svc = const PlannerService();

  // Form controllers
  final _familySizeCtrl = TextEditingController(text: '0');
  final _childrenCtrl = TextEditingController(text: '0');
  final _elderlyCtrl = TextEditingController(text: '0');
  // Was constructed inline inside _buildForm() (`TextEditingController()`,
  // no initial text) — every setState() in this screen re-ran _buildForm()
  // and silently created a BRAND NEW controller, discarding whatever floor
  // number the user had stepped to and resetting the display to blank
  // (not even "0", since the inline version had no initial text). Hoisted
  // to a persistent field like the other three counters.
  final _floorCtrl = TextEditingController(text: '0');
  final _medicalCtrl = TextEditingController();
  HomeType _homeType = HomeType.unknown;
  bool _pets = false;
  bool _river = false;
  bool _coast = false;

  // State
  bool _loading = false;
  String? _plan;

  @override
  void dispose() {
    _familySizeCtrl.dispose();
    _childrenCtrl.dispose();
    _elderlyCtrl.dispose();
    _floorCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);

    final profile = FamilyProfile(
      familySize: int.tryParse(_familySizeCtrl.text) ?? 0,
      childrenCount: int.tryParse(_childrenCtrl.text) ?? 0,
      elderlyCount: int.tryParse(_elderlyCtrl.text) ?? 0,
      hasPets: _pets,
      homeType: _homeType,
      floorNumber: _homeType == HomeType.apartment
          ? int.tryParse(_floorCtrl.text) ?? 0
          : null,
      medicalConditions: _medicalCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      nearbyRiver: _river,
      nearbyCoast: _coast,
    );

    // Persist for Kit + Risk modules.
    await FamilyProfile.save(profile);

    final plan = await _svc.generatePlan(profile);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plannerTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plan != null
              ? _ResultView(
                  plan: _plan!,
                  onReset: () => setState(() => _plan = null),
                )
              : _buildForm(t, l10n),
    );
  }

  Widget _buildForm(ThemeData t, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.plannerFamilyInfo),
          StepperRow(
              label: l10n.plannerTotalMembers, controller: _familySizeCtrl, max: 20),
          StepperRow(
              label: l10n.plannerChildren, controller: _childrenCtrl, max: 15),
          StepperRow(
              label: l10n.plannerElderly, controller: _elderlyCtrl, max: 15),
          const SizedBox(height: 16),
          SectionLabel(l10n.plannerHomeType),
          Wrap(
            spacing: 8,
            children: HomeType.values
                .where((ht) => ht != HomeType.unknown)
                .map((ht) => ChoiceChip(
                      label: Text(ht.label(l10n)),
                      selected: _homeType == ht,
                      onSelected: (_) => setState(() => _homeType = ht),
                    ))
                .toList(),
          ),
          if (_homeType == HomeType.apartment) ...[
            const SizedBox(height: 12),
            StepperRow(label: l10n.plannerFloorNumber, controller: _floorCtrl, max: 30),
          ],
          const SizedBox(height: 16),
          SectionLabel(l10n.plannerMedicalConditions),
          TextField(
            controller: _medicalCtrl,
            decoration: InputDecoration(
              hintText: l10n.plannerMedicalHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SectionLabel(l10n.plannerOther),
          ToggleRow(
              label: l10n.plannerHasPets,
              value: _pets,
              onChanged: (v) => setState(() => _pets = v)),
          ToggleRow(
              label: l10n.plannerNearbyRiver,
              value: _river,
              onChanged: (v) => setState(() => _river = v)),
          ToggleRow(
              label: l10n.plannerNearCoast,
              value: _coast,
              onChanged: (v) => setState(() => _coast = v)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(l10n.plannerGenerate),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result view ──────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final String plan;
  final VoidCallback onReset;
  const _ResultView({required this.plan, required this.onReset});

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
                Text(l10n.plannerAiPlan,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(plan, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.plannerNewPlan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.plannerDone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
