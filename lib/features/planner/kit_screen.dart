import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'family_profile.dart';
import 'kit_service.dart';

/// AI Emergency Kit Generator screen (Module B).
///
/// Loads the existing FamilyProfile (saved by the Planner) and
/// generates a customized supply list with quantities.
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final p = await FamilyProfile.load();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _initing = false;
    });
  }

  Future<void> _generate() async {
    if (_profile == null || _profile!.isEmpty) return;
    setState(() => _loading = true);
    final kit = await _svc.generateKit(_profile!);
    if (!mounted) return;
    setState(() {
      _kit = kit;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_initing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null || _profile!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.kitTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.luggage_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  l10n.kitEmptyBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.kitGoToPlanner),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kitTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _kit != null
              ? _ResultView(
                  kit: _kit!,
                  onReset: () => setState(() => _kit = null),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.luggage_outlined,
                            size: 72,
                            color: ShongjogTheme.ocean),
                        const SizedBox(height: 16),
                        Text(
                          l10n.kitGenerateForFamily(_profile!.familySize),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(l10n.kitGenerateButton),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

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
              color: ShongjogTheme.ocean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: ShongjogTheme.ocean, size: 20),
                const SizedBox(width: 8),
                Text(l10n.kitAiKit,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ShongjogTheme.ocean)),
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
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.kitRetry),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
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