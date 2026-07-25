import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'risk_prompt_builder.dart';
import 'risk_service.dart';

/// AI Risk Assessment screen (Module C).
class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
  final _svc = const RiskService();

  HomeMaterial _material = HomeMaterial.tinShed;
  FloodHistory _floods = FloodHistory.none;
  Elevation _elevation = Elevation.mid;
  bool _river = false;
  bool _coast = false;
  bool _elderly = false;
  bool _infants = false;

  RiskResult? _result;
  bool _loading = false;

  RiskInputs get _inputs => RiskInputs(
        homeMaterial: _material,
        previousFloods: _floods,
        elevation: _elevation,
        nearRiver: _river,
        nearCoast: _coast,
        hasElderly: _elderly,
        hasInfants: _infants,
      );

  Future<void> _assess() async {
    setState(() => _loading = true);
    final r = await _svc.assess(_inputs);
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI ঝুঁকি মূল্যায়ন')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _ResultView(
                  result: _result!,
                  onReset: () => setState(() => _result = null),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('ঘরের ধরন'),
          Wrap(
            spacing: 8,
            children: HomeMaterial.values
                .map((m) => ChoiceChip(
                      label: Text(m.labelBn),
                      selected: _material == m,
                      onSelected: (_) => setState(() => _material = m),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _SectionLabel('পূর্ববর্তী বন্যার ইতিহাস'),
          Wrap(
            spacing: 8,
            children: FloodHistory.values
                .map((f) => ChoiceChip(
                      label: Text(f.labelBn),
                      selected: _floods == f,
                      onSelected: (_) => setState(() => _floods = f),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _SectionLabel('এলাকার উচ্চতা'),
          Wrap(
            spacing: 8,
            children: Elevation.values
                .map((e) => ChoiceChip(
                      label: Text(e.labelBn),
                      selected: _elevation == e,
                      onSelected: (_) => setState(() => _elevation = e),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _SectionLabel('অন্যান্য'),
          SwitchListTile(
            title: const Text('নিকটবর্তী নদী'),
            value: _river,
            onChanged: (v) => setState(() => _river = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('সমুদ্রতীরের কাছে'),
            value: _coast,
            onChanged: (v) => setState(() => _coast = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('পরিবারে প্রবীণ আছে'),
            value: _elderly,
            onChanged: (v) => setState(() => _elderly = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('পরিবারে শিশু আছে'),
            value: _infants,
            onChanged: (v) => setState(() => _infants = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _assess,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ঝুঁকি মূল্যায়ন করুন'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final RiskResult result;
  final VoidCallback onReset;
  const _ResultView({required this.result, required this.onReset});

  Color _color() {
    if (result.score >= 7) return Colors.red;
    if (result.score >= 4) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final scoreBn = result.score.toString().split('').map((c) {
      const m = {
        '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
        '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
      };
      return m[c] ?? c;
    }).join();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color().withValues(alpha: 0.15),
                    border: Border.all(color: _color(), width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(scoreBn,
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _color())),
                      Text('/ ১০',
                          style: TextStyle(
                              fontSize: 14, color: _color())),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('ঝুঁকি স্কোর',
                    style: TextStyle(
                        color: ShongjogTheme.inkSecondary,
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(result.summary,
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ),
          const SizedBox(height: 16),
          Text(result.improvements,
              style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('পুনরায়'),
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