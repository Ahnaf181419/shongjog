import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'situation_summary_service.dart';

/// AI Situation Summary screen (Module E in docs/AI-FIRST-FEATURES.md).
///
/// Aggregates a small static sample of recent reports and renders the
/// AI-generated summary. In a fuller iteration this would feed from
/// the chat history store + the SOS dispatcher.
class SituationSummaryScreen extends StatefulWidget {
  const SituationSummaryScreen({super.key});

  @override
  State<SituationSummaryScreen> createState() => _SituationSummaryScreenState();
}

class _SituationSummaryScreenState extends State<SituationSummaryScreen> {
  String? _summary;
  bool _loading = false;

  // Sample reports (a richer build would pull from chat history + SOS
  // log). The summary still works on a single report.
  final List<SituationReport> _reports = [
    SituationReport.now(query: 'নিকটস্থ সাইক্লোন শেল্টার', source: 'chat'),
    SituationReport.now(query: 'বন্যার পানি কতদিন থাকবে?', source: 'chat'),
    SituationReport.now(query: 'SOS: আটকা পড়েছি', source: 'sos'),
  ];

  Future<void> _generate() async {
    setState(() => _loading = true);
    final s = await generateSituationSummary(_reports);
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI পরিস্থিতি সারাংশ')),
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
            Text(
              '${_reports.length} টি সাম্প্রতিক প্রতিবেদনের ভিত্তিতে পরিস্থিতির সারাংশ তৈরি করুন।',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('সারাংশ তৈরি করুন'),
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
                Text('AI সারাংশ',
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
                  label: const Text('পুনরায়'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
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