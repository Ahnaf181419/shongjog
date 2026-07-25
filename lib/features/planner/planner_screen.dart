import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'family_profile.dart';
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
  final _medicalCtrl = TextEditingController();
  HomeType _homeType = HomeType.unknown;
  int _floor = 0;
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
      floorNumber: _homeType == HomeType.apartment ? _floor : null,
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
    return Scaffold(
      appBar: AppBar(title: const Text('AI দুর্যোগ পরিকল্পনা')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plan != null
              ? _ResultView(
                  plan: _plan!,
                  onReset: () => setState(() => _plan = null),
                )
              : _buildForm(t),
    );
  }

  Widget _buildForm(ThemeData t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('পরিবারের তথ্য'),
          _StepperRow(
              label: 'মোট সদস্য', controller: _familySizeCtrl, max: 20),
          _StepperRow(
              label: 'শিশু', controller: _childrenCtrl, max: 15),
          _StepperRow(
              label: 'প্রবীণ', controller: _elderlyCtrl, max: 15),
          const SizedBox(height: 16),
          _SectionLabel('ঘরের ধরন'),
          Wrap(
            spacing: 8,
            children: HomeType.values
                .where((t) => t != HomeType.unknown)
                .map((t) => ChoiceChip(
                      label: Text(t.labelBn),
                      selected: _homeType == t,
                      onSelected: (_) => setState(() => _homeType = t),
                    ))
                .toList(),
          ),
          if (_homeType == HomeType.apartment) ...[
            const SizedBox(height: 12),
            _StepperRow(
                label: 'তলা নম্বর', controller: TextEditingController(), max: 30, onChanged: (v) => _floor = v),
          ],
          const SizedBox(height: 16),
          _SectionLabel('চিকিৎসা অবস্থা (কমা দিয়ে আলাদা করুন)'),
          TextField(
            controller: _medicalCtrl,
            decoration: const InputDecoration(
              hintText: 'যেমন: ডায়াবেটিস, হাঁপানি',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel('অন্যান্য'),
          _ToggleRow(
              label: 'পোষা প্রাণী আছে',
              value: _pets,
              onChanged: (v) => setState(() => _pets = v)),
          _ToggleRow(
              label: 'নিকটবর্তী নদী',
              value: _river,
              onChanged: (v) => setState(() => _river = v)),
          _ToggleRow(
              label: 'সমুদ্রতীরের কাছে',
              value: _coast,
              onChanged: (v) => setState(() => _coast = v)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('পরিকল্পনা তৈরি করুন'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: ShongjogTheme.ocean, size: 20),
                const SizedBox(width: 8),
                Text('AI পরিকল্পনা',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ShongjogTheme.ocean)),
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
                  icon: const Icon(Icons.refresh),
                  label: const Text('নতুন পরিকল্পনা'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('সম্পন্ন'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Form helpers ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int max;
  final ValueChanged<int>? onChanged;
  const _StepperRow({
    required this.label,
    required this.controller,
    required this.max,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              final v = (int.tryParse(controller.text) ?? 0) - 1;
              if (v >= 0) {
                controller.text = '$v';
                onChanged?.call(v);
              }
            },
          ),
          SizedBox(
            width: 40,
            child: Text(
              controller.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final v = (int.tryParse(controller.text) ?? 0) + 1;
              if (v <= max) {
                controller.text = '$v';
                onChanged?.call(v);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
