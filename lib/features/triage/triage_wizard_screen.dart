import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../quick_cards/cards_data.dart';
import 'decision_tree.dart';
import 'triage_state.dart';
import 'triage_tts.dart';
import '../../app/theme.dart';
import '../../core/bangla_numerals.dart';

/// Convert Latin digits to Bengali numerals for UI strings.
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
  /// Optional TTS adapter. When null, the wizard stays silent
  /// (the default — auto-read is opt-in per AGENTS.md).
  final TriageTts? tts;

  const TriageWizardScreen({super.key, this.tts});

  @override
  State<TriageWizardScreen> createState() => _TriageWizardScreenState();
}

class _TriageWizardScreenState extends State<TriageWizardScreen> {
  final TriageState _state = TriageState();
  TriageQuestion? _lastSpokenQuestion;

  /// Tolerates the existing widget tests that look at the underlying
  /// bool answers. Reads from [_state.answers] on demand.
  List<bool> get _answers =>
      _state.answers.map((a) => a.answer).toList(growable: false);

  /// Returns the current question, or null if the user has
  /// answered enough to land on a terminal route.
  TriageQuestion? get _currentQuestion {
    final answers = _answers;
    if (answers.length >= TriageTree.questions.length) return null;
    String? nextId = TriageTree.questions.first.id;
    int i = 0;
    while (nextId != null) {
      final q = TriageTree.questions.firstWhere((q) => q.id == nextId);
      if (i >= answers.length) return q;
      final branch = answers[i] ? q.yesBranch : q.noBranch;
      i++;
      if (branch.route != null) return null;
      nextId = branch.nextQuestionId;
    }
    return null;
  }

  /// The terminal route reached so far, or null if the user is
  /// still answering questions.
  TriageRoute? get _route {
    final answers = _answers;
    String? nextId = TriageTree.questions.first.id;
    int i = 0;
    while (nextId != null) {
      if (i >= answers.length) return null;
      final q = TriageTree.questions.firstWhere((q) => q.id == nextId);
      final branch = answers[i] ? q.yesBranch : q.noBranch;
      i++;
      if (branch.route != null) return branch.route;
      nextId = branch.nextQuestionId;
    }
    return null;
  }

  void _answer(bool yes) {
    final q = _currentQuestion;
    setState(() {
      if (q != null) _state.addAnswer(q.id, yes);
      _state.route = _route;
    });
  }

  void _reset() {
    setState(_state.reset);
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final cs = Theme.of(context).colorScheme;
    _maybeSpeak();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).triageTitle),
        actions: [
          if (_state.answers.isNotEmpty) ...[
            if (_state.elapsedBn().isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: ShongjogTheme.statusChip(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          _state.elapsedBn(),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: AppLocalizations.of(context).triageRestart,
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: route == null ? _buildQuestion(context) : _buildRoute(context, route),
      ),
    );
  }

  /// Auto-read the current question (or terminal route) when it
  /// changes. Guarded by [_lastSpokenQuestion] so repeat rebuilds
  /// don't re-speak. Stops TTS when the user lands on a terminal
  /// route so the previous question's audio doesn't bleed past
  /// the act-now moment.
  void _maybeSpeak() {
    final tts = widget.tts;
    if (tts == null) return;
    final route = _route;
    if (route != null) {
      if (_lastSpokenQuestion != null) {
        _lastSpokenQuestion = null;
        tts.stop();
      }
      return;
    }
    final q = _currentQuestion;
    if (q == null) return;
    if (_lastSpokenQuestion?.id != q.id) {
      _lastSpokenQuestion = q;
      tts.speak(q.questionBuilder(context));
    }
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
            AppLocalizations.of(context).triageQuestion(
              banglaNumber(_answers.length + 1),
              banglaNumber(TriageTree.questions.length),
            ),
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            q.questionBuilder(context),
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
                  label: AppLocalizations.of(context).triageYes,
                  color: cs.primary,
                  onPressed: () => _answer(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _BigAnswerButton(
                  label: AppLocalizations.of(context).triageNo,
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
    final l10n = AppLocalizations.of(context);
    final title = _titleFor(route, l10n);
    final subtitle = _subtitleFor(route, l10n);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(
              Icons.medical_services_outlined,
              size: 72,
              color: cs.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _RecapChip(state: _state),
            const SizedBox(height: 16),
            _InlineSteps(cardId: _cardIdFor(route)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openMatchingCard(context, route),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.triageViewCard),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _call999(context),
              icon: const Icon(Icons.phone_rounded),
              label: Text(l10n.triageCall999),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: cs.error,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _handoffTo999(context),
              icon: const Icon(Icons.forward_to_inbox_rounded),
              label: Text(l10n.triageNotify999),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.triageRestart),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _call999(BuildContext context) {
    // The dialer lives in the emergency feature; we just show a
    // snackbar hint. Linking the actual dialer would require a
    // shared callback wired from the route — defer to the host
    // navigation stack.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).triageCalling999),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Maps a [TriageRoute] to a [QuickCard] id and pushes the
  /// full-screen card detail. The mapping is hand-rolled — the
  /// decision tree is a medical/UX artifact, the card catalog is a
  /// content artifact, and the two can drift; the unit test in
  /// `triage_wizard_test.dart` covers every current route.
  void _openMatchingCard(BuildContext context, TriageRoute route) {
    final cardId = _cardIdFor(route);
    Navigator.of(context).pushNamed(
      AppRoutes.quickCardDetail,
      arguments: cardId,
    );
  }

  /// Hand off the triage summary to the SOS composer so the 999
  /// operator sees the casualty state in the SMS body without the
  /// bystander having to re-type it under stress.
  void _handoffTo999(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).pushNamed(
      AppRoutes.sosComposer,
      arguments: _state.shareableSosText(l10n),
    );
  }

  static String _cardIdFor(TriageRoute route) {
    switch (route) {
      case TriageRoute.cpr:
        return 'cpr';
      case TriageRoute.bleeding:
        return 'bleeding';
      case TriageRoute.drowning:
        return 'drowning';
      case TriageRoute.snakebite:
        return 'snakebite';
      case TriageRoute.unconsciousBreathing:
        return 'recovery_position';
      case TriageRoute.burn:
        return 'burn';
      case TriageRoute.choking:
        return 'choking';
      case TriageRoute.escalation999:
        return 'escalation';
    }
  }

  static String _titleFor(TriageRoute route, AppLocalizations l10n) {
    switch (route) {
      case TriageRoute.cpr:
        return l10n.triageRouteCpr;
      case TriageRoute.bleeding:
        return l10n.triageRouteBleeding;
      case TriageRoute.drowning:
        return l10n.triageRouteDrowning;
      case TriageRoute.snakebite:
        return l10n.triageRouteSnakebite;
      case TriageRoute.unconsciousBreathing:
        return l10n.triageRouteRecovery;
      case TriageRoute.burn:
        return l10n.triageRouteBurn;
      case TriageRoute.choking:
        return l10n.triageRouteChoking;
      case TriageRoute.escalation999:
        return l10n.triageRouteEscalation;
    }
  }

  static String _subtitleFor(TriageRoute route, AppLocalizations l10n) {
    switch (route) {
      case TriageRoute.cpr:
        return l10n.triageStepCpr;
      case TriageRoute.bleeding:
        return l10n.triageStepBleeding;
      case TriageRoute.drowning:
        return l10n.triageStepDrowning;
      case TriageRoute.snakebite:
        return l10n.triageStepSnakebite;
      case TriageRoute.unconsciousBreathing:
        return l10n.triageStepRecovery;
      case TriageRoute.burn:
        return l10n.triageStepBurn;
      case TriageRoute.choking:
        return l10n.triageStepChoking;
      case TriageRoute.escalation999:
        return l10n.triageStepEscalation;
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
          borderRadius: BorderRadius.circular(ShongjogTheme.radius),
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

/// Small summary chip on the terminal screen — shows the elapsed
/// time, the answer count, and the current route. Re-renders once
/// per second so the operator sees a live clock.
class _RecapChip extends StatefulWidget {
  final TriageState state;
  const _RecapChip({required this.state});

  @override
  State<_RecapChip> createState() => _RecapChipState();
}

class _RecapChipState extends State<_RecapChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final summary = widget.state.summaryBn(l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        summary,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Compact "act now" list on the terminal screen — renders the first
/// three steps of the matching [QuickCard] inline so the bystander
/// can begin care without navigating away. The full card is still
/// one tap away via the "View Card" CTA.
class _InlineSteps extends StatelessWidget {
  final String cardId;
  const _InlineSteps({required this.cardId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final card = _findCard(cardId, l10n);
    final steps = card.stepsBn.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                l10n.triageDoNow,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${banglaNumber(entry.key + 1)}.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static QuickCard _findCard(String id, AppLocalizations l10n) {
    for (final c in kQuickCards) {
      if (c.id == id) return c;
    }
    return QuickCard(
      id: '__missing__',
      titleBn: l10n.triageCardNotFound,
      icon: Icons.help_outline_rounded,
      color: Colors.grey,
      stepsBn: const [],
    );
  }
}
