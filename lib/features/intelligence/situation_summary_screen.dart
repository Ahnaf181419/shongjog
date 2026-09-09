import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/bangla_numerals.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_store.dart';
import '../safe_beacon/safety_status_service.dart';
import 'situation_summary_service.dart';

/// AI Situation Summary screen (Module E in docs/AI-FIRST-FEATURES.md).
///
/// Aggregates reports from the live chat history + the safety status
/// service. (Audit F4, 2026-09-08 — used to summarize 3 hardcoded
/// sample queries, which made a demo look real but was fiction; this
/// is now the real path. The samples are kept as an empty-state seed
/// only, when there is genuinely nothing to summarize.)
/// In a fuller iteration this would feed from
/// the chat history store + the SOS dispatcher.
class SituationSummaryScreen extends StatefulWidget {
  const SituationSummaryScreen({super.key});

  @override
  State<SituationSummaryScreen> createState() => _SituationSummaryScreenState();
}

class _SituationSummaryScreenState extends State<SituationSummaryScreen> {
  String? _summary;
  bool _loading = false;

  /// Cached count future so build() doesn't allocate a fresh Future
  /// every frame (independent-review suggestion 1, 2026-09-09). The
  /// State lives for the lifetime of the screen; _collectReports is
  /// pure-Dart aside from SharedPreferences + safetyStatusService
  /// reads, both of which are deterministic within a single session.
  late final Future<int> _reportCountFuture;

  /// Aggregate the live data sources into a single report list for the
  /// summarizer. Empty in a fresh install; filled when there is chat
  /// history or a safety report. Three placeholder reports are returned
  /// only when the list would otherwise be empty, so a brand-new user
  /// still sees a meaningful demo summary rather than a blank screen —
  /// those samples are clearly marked [demo seed] in the prompt so the
  /// model output stays grounded in real, not fictional, content.
  Future<List<SituationReport>> _collectReports() async {
    final out = <SituationReport>[];

    // 1. Safety reports: my own + every report seen this session.
    for (final r in safetyStatusService.all) {
      out.add(SituationReport(
        query: r.status == SafetyReport.dangerStatus
            ? 'জরুরি: ${r.note.isNotEmpty ? r.note : r.userName}'
            : 'নিরাপদ: ${r.userName}',
        source: 'safety',
        when: r.timestamp,
      ));
    }

    // 2. Recent chat history (user queries only — model answers would
    // just duplicate the user query).
    try {
      final messages = await ChatStore().load();
      for (final m in messages.reversed.take(10)) {
        if (m.isUser) {
          out.add(SituationReport(
            query: m.text,
            source: 'chat',
            when: DateTime.now(),
          ));
        }
      }
    } catch (_) {
      // ChatStore failure (no FS, corrupt file, etc.) — keep the safety
      // reports. Don't fail the whole summary for a chat-history glitch.
    }

    if (out.isNotEmpty) return out;

    // Empty-state demo seed (audit F4) — only when nothing real exists.
    return [
      SituationReport.now(
        query: 'ডেমো: নিকটস্থ সাইক্লোন শেল্টার',
        source: 'demo seed',
      ),
      SituationReport.now(
        query: 'ডেমো: বন্যার পানি কতদিন থাকবে?',
        source: 'demo seed',
      ),
      SituationReport.now(
        query: 'ডেমো: SOS — আটকা পড়েছি',
        source: 'demo seed',
      ),
    ];
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final reports = await _collectReports();
    final s = await generateSituationSummary(reports);
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _reportCountFuture = _collectReports().then((r) => r.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).situationTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary != null
              ? _ResultView(
                  summary: _summary!,
                  onReset: () => setState(() => _summary = null),
                )
              : _buildIntro(),
    );
  }

  FutureBuilder<int> _buildCountFuture() =>
      FutureBuilder<int>(
        future: _reportCountFuture,
        builder: (ctx, snap) {
          final n = snap.data;
          if (n == null) return const SizedBox.shrink();
          return Text(
            AppLocalizations.of(context)
                .situationIntro(banglaNumber(n)),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          );
        },
      );

  Widget _buildIntro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.summarize_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            _buildCountFuture(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(AppLocalizations.of(context).situationGenerate),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final String summary;
  final VoidCallback onReset;
  const _ResultView({required this.summary, required this.onReset});

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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).situationResultHeading,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(summary, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppLocalizations.of(context).situationRetry),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(AppLocalizations.of(context).situationDone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}