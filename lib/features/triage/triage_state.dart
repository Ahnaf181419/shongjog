import '../../l10n/app_localizations.dart';
import 'decision_tree.dart';

/// A single yes/no answer captured during the triage walk.
class TriageAnswer {
  final String questionId;
  final bool answer;
  final Duration elapsed;

  const TriageAnswer({
    required this.questionId,
    required this.answer,
    required this.elapsed,
  });
}

/// Tracks the live state of a triage walk: the wall-clock start, the
/// [TriageAnswer] history, and the final [TriageRoute] once reached.
///
/// Pure Dart — no plugin imports, no IO. Lives next to [TriageTree]
/// in `lib/features/triage/` so the dependency rule (no plugin
/// imports in core/triage/knowledge) stays intact (AGENTS.md).
class TriageState {
  DateTime startedAt;
  final List<TriageAnswer> answers;
  TriageRoute? route;

  TriageState()
      : startedAt = DateTime.now(),
        answers = <TriageAnswer>[],
        route = null;

  /// Append a yes/no answer for the current question.
  void addAnswer(String questionId, bool answer) {
    answers.add(TriageAnswer(
      questionId: questionId,
      answer: answer,
      elapsed: DateTime.now().difference(startedAt),
    ));
  }

  /// Drop the answer history and reset the wall-clock — the wizard
  /// uses this when the user taps "Start over".
  void reset() {
    answers.clear();
    route = null;
    startedAt = DateTime.now();
  }

  int get answerCount => answers.length;

  Duration get elapsedDuration => DateTime.now().difference(startedAt);

  /// Wall-clock elapsed in Bangla h:mm:ss format with Bengali numerals.
  /// Minutes and seconds are zero-padded so the string width is stable
  /// as it ticks — prevents layout shift in the app-bar and recap chips.
  String elapsedBn() {
    final d = elapsedDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String p(int n) => _bn(n).padLeft(2, '০');
    return '${_bn(h)}:${p(m)}:${p(s)}';
  }

  /// One-line human-readable summary of the answer trail + final route.
  /// Used in the terminal screen recap and in the SOS handoff body.
  /// All numbers use Bengali numerals (AGENTS.md).
  String summaryBn([AppLocalizations? l10n]) {
    final yes = answers.where((a) => a.answer).length;
    final no = answers.length - yes;
    final since = elapsedBn();
    if (l10n == null) {
      final routeText = route == null ? 'চলমান' : _routeNameBn(route!);
      return 'প্রশ্ন: ${_bn(answers.length)} '
          '(হ্যাঁ ${_bn(yes)} / না ${_bn(no)}) | '
          'সময়: $since | অবস্থা: $routeText';
    }
    final routeText = route == null
        ? l10n.triageStateOngoing
        : _routeNameBnL10n(route!, l10n);
    return '${l10n.triageSummaryPrefix} '
        '${l10n.triageSummaryQuestions} ${_bn(answers.length)} '
        '(${l10n.triageSummaryYes} ${_bn(yes)} / ${l10n.triageSummaryNo} ${_bn(no)}) | '
        '${l10n.triageSummaryTime} $since | '
        '${l10n.triageSummaryStatus} $routeText';
  }

  /// 3-line body suitable for the SOS Composer `initialBody` field.
  /// Format: condition / time / taps (so the 999 operator sees it
  /// at a glance). All numbers use Bengali numerals.
  String shareableSosText([AppLocalizations? l10n]) {
    final since = elapsedBn();
    final yes = answers.where((a) => a.answer).length;
    final no = answers.length - yes;
    if (l10n == null) {
      final routeText = route == null ? 'অজানা' : _routeNameBn(route!);
      return 'ট্রায়াজ: $routeText\n'
          'সময়: $since\n'
          'প্রশ্ন: ${_bn(answers.length)} '
          '(হ্যাঁ ${_bn(yes)} / না ${_bn(no)})';
    }
    final routeText = route == null
        ? l10n.triageStateUnknown
        : _routeNameBnL10n(route!, l10n);
    return l10n.triageSummarySos(
      routeText,
      since,
      answers.length,
      yes,
      no,
    );
  }

  String _routeNameBnL10n(TriageRoute route, AppLocalizations l10n) {
    switch (route) {
      case TriageRoute.cpr:
        return l10n.triageRouteNameCpr;
      case TriageRoute.bleeding:
        return l10n.triageRouteNameBleeding;
      case TriageRoute.drowning:
        return l10n.triageRouteNameDrowning;
      case TriageRoute.snakebite:
        return l10n.triageRouteNameSnakebite;
      case TriageRoute.unconsciousBreathing:
        return l10n.triageRouteNameRecovery;
      case TriageRoute.burn:
        return l10n.triageRouteNameBurn;
      case TriageRoute.choking:
        return l10n.triageRouteNameChoking;
      case TriageRoute.escalation999:
        return l10n.triageRouteNameEscalation;
    }
  }

  static String _routeNameBn(TriageRoute route) {
    switch (route) {
      case TriageRoute.cpr:
        return 'সিপিআর';
      case TriageRoute.bleeding:
        return 'রক্তপাত';
      case TriageRoute.drowning:
        return 'ডুবে যাওয়া';
      case TriageRoute.snakebite:
        return 'সাপে কামড়';
      case TriageRoute.unconsciousBreathing:
        return 'রিকভারি পজিশন';
      case TriageRoute.burn:
        return 'গুরুতর পোড়া';
      case TriageRoute.choking:
        return 'শ্বাসরোধ';
      case TriageRoute.escalation999:
        return 'সাধারণ জরুরি';
    }
  }

  static String _bn(int n) {
    const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }
}
