import 'decision_tree.dart';
import '../../l10n/app_localizations.dart';
import '../../core/bangla_numerals.dart';

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

  /// Locale-aware timer — Latin digits in en mode, Bengali in bn mode.
  /// Width is kept stable (zero-padded) to avoid layout shift either way.
  String elapsedFor(String localeCode) {
    final isBangla = localeCode.toLowerCase().startsWith('bn');
    final d = elapsedDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (isBangla) return elapsedBn();
    String p(int n) => n.toString().padLeft(2, '0');
    return '$h:${p(m)}:${p(s)}';
  }

  /// One-line human-readable summary of the answer trail + final route.
  /// Used in the terminal screen recap and in the SOS handoff body.
  /// All numbers use Bengali numerals in bn mode, Latin in en mode.
  String summaryBn([AppLocalizations? l10n]) {
    final yes = answers.where((a) => a.answer).length;
    final no = answers.length - yes;
    final localeName = l10n?.localeName ?? 'bn';
    final since = elapsedFor(localeName);
    if (l10n == null) {
      final routeText = route == null
          ? _ongoingLabel(l10n)
          : _routeNameBnL10n(route!, _fallbackL10n());
      return 'প্রশ্ন: ${_bn(answers.length)} '
          '(হ্যাঁ ${_bn(yes)} / না ${_bn(no)}) | '
          'সময়: $since | অবস্থা: $routeText';
    }
    final routeText = route == null
        ? l10n.triageStateOngoing
        : _routeNameBnL10n(route!, l10n);
    final countStr = numberForLocale(answers.length, localeName);
    final yesStr = numberForLocale(yes, localeName);
    final noStr = numberForLocale(no, localeName);
    return '${l10n.triageSummaryPrefix} '
        '${l10n.triageSummaryQuestions} $countStr '
        '(${l10n.triageSummaryYes} $yesStr / ${l10n.triageSummaryNo} $noStr) | '
        '${l10n.triageSummaryTime} $since | '
        '${l10n.triageSummaryStatus} $routeText';
  }

  /// 3-line body suitable for the SOS Composer `initialBody` field.
  /// Format: condition / time / taps (so the 999 operator sees it
  /// at a glance).
  String shareableSosText([AppLocalizations? l10n]) {
    final localeName = l10n?.localeName ?? 'bn';
    final since = elapsedFor(localeName);
    final yes = answers.where((a) => a.answer).length;
    final no = answers.length - yes;
    if (l10n == null) {
      final routeText = route == null
          ? _unknownLabel(l10n)
          : _routeNameBnL10n(route!, _fallbackL10n());
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
      numberForLocale(answers.length, localeName),
      numberForLocale(yes, localeName),
      numberForLocale(no, localeName),
    );
  }

  String _routeNameBnL10n(TriageRoute route, AppLocalizations? l10n) {
    if (l10n == null) return _routeNameBn(route);
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

  String _ongoingLabel(AppLocalizations? l10n) =>
      l10n?.triageStateOngoing ?? 'চলমান';

  String _unknownLabel(AppLocalizations? l10n) =>
      l10n?.triageStateUnknown ?? 'অজানা';

  AppLocalizations? _fallbackL10n() => null;
