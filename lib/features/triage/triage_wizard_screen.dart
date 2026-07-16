import 'package:flutter/material.dart';

import 'decision_tree.dart';

/// Convert Latin digits to Bengali numerals for UI strings.
/// AGENTS.md: Bangla numerals (০-৯) in user-facing strings.
String _bn(int n) {
  const map = {
    '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
    '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
  };
  return n.toString().split('').map((c) => map[c] ?? c).join();
}

/// Full-screen, no-typing triage wizard. Two giant buttons (হ্যাঁ /
/// না) walk the user through a fixed yes/no decision tree. Each
/// terminal node maps to a [TriageRoute] which surfaces a "go to
/// the matching quick card" CTA and a 999 fallback.
///
/// No model is involved. The decision tree is pure-Dart and lives
/// in `decision_tree.dart`. The content is constrained to the
/// WHO/BDRCS/MoDMR/BMD/CDC/IFRC first-aid whitelist; this screen
/// cannot hallucinate steps.
class TriageWizardScreen extends StatefulWidget {
  const TriageWizardScreen({super.key});

  @override
  State<TriageWizardScreen> createState() => _TriageWizardScreenState();
}

class _TriageWizardScreenState extends State<TriageWizardScreen> {
  final List<bool> _answers = [];

  /// Returns the current question, or null if the user has
  /// answered enough to land on a terminal route.
  TriageQuestion? get _currentQuestion {
    if (_answers.length >= TriageTree.questions.length) return null;
    String? nextId = TriageTree.questions.first.id;
    int i = 0;
    while (nextId != null) {
      final q = TriageTree.questions.firstWhere((q) => q.id == nextId);
      if (i >= _answers.length) return q;
      final branch = _answers[i] ? q.yesBranch : q.noBranch;
      i++;
      if (branch.route != null) return null;
      nextId = branch.nextQuestionId;
    }
    return null;
  }

  /// The terminal route reached so far, or null if the user is
  /// still answering questions.
  TriageRoute? get _route {
    String? nextId = TriageTree.questions.first.id;
    int i = 0;
    while (nextId != null) {
      if (i >= _answers.length) return null;
      final q = TriageTree.questions.firstWhere((q) => q.id == nextId);
      final branch = _answers[i] ? q.yesBranch : q.noBranch;
      i++;
      if (branch.route != null) return branch.route;
      nextId = branch.nextQuestionId;
    }
    return null;
  }

  void _answer(bool yes) {
    setState(() => _answers.add(yes));
  }

  void _reset() {
    setState(_answers.clear);
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ট্রায়াজ উইজার্ড'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        actions: [
          if (_answers.isNotEmpty)
            IconButton(
              tooltip: 'পুনরায় শুরু',
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: route == null ? _buildQuestion(context) : _buildRoute(context, route),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final q = _currentQuestion!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_answers.length + 1) / TriageTree.questions.length,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 32),
          Text(
            'প্রশ্ন ${_bn(_answers.length + 1)} / ${_bn(TriageTree.questions.length)}',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            q.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _BigAnswerButton(
                  label: 'হ্যাঁ',
                  color: cs.primary,
                  onPressed: () => _answer(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BigAnswerButton(
                  label: 'না',
                  color: cs.error,
                  onPressed: () => _answer(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoute(BuildContext context, TriageRoute route) {
    final cs = Theme.of(context).colorScheme;
    final title = _titleFor(route);
    final subtitle = _subtitleFor(route);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.medical_services_outlined,
            size: 96,
            color: cs.error,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('কার্ড দেখুন'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: cs.primary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _call999(context),
            icon: const Icon(Icons.phone),
            label: const Text('৯৯৯ কল করুন'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: cs.error,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('পুনরায় শুরু'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }

  void _call999(BuildContext context) {
    // The dialer lives in the emergency feature; we just show a
    // snackbar hint. Linking the actual dialer would require a
    // shared callback wired from the route — defer to the host
    // navigation stack.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('৯৯৯ কল করুন — ফোন অ্যাপে ডায়াল করুন'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  static String _titleFor(TriageRoute route) {
    switch (route) {
      case TriageRoute.cpr:
        return 'সিপিআর শুরু করুন';
      case TriageRoute.bleeding:
        return 'রক্তপাত বন্ধ করুন';
      case TriageRoute.drowning:
        return 'ডুবে যাওয়া — নিষ্কাশন ও সিপিআর';
      case TriageRoute.snakebite:
        return 'সাপে কামড় — চিকিৎসা সহায়তা নিন';
      case TriageRoute.escalation999:
        return 'জরুরি সহায়তা প্রয়োজন';
    }
  }

  static String _subtitleFor(TriageRoute route) {
    switch (route) {
      case TriageRoute.cpr:
        return 'বুকে ১১০ বার/মিনিট হারে চাপ দিন। ৩০:২ অনুপাত।';
      case TriageRoute.bleeding:
        return 'চাপ দিয়ে রক্তপাত বন্ধ করুন। পরিষ্কার কাপড় দিয়ে চাপ।';
      case TriageRoute.drowning:
        return 'শ্বাস নিচ্ছে কিনা দেখুন। প্রয়োজনে সিপিআর।';
      case TriageRoute.snakebite:
        return 'শান্ত রাখুন, কাটা বা চুষবেন না। দ্রুত হাসপাতালে।';
      case TriageRoute.escalation999:
        return '৯৯৯ কল করুন বা পরিবার/প্রতিবেশীদের সাহায্য নিন।';
    }
  }
}

class _BigAnswerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _BigAnswerButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}