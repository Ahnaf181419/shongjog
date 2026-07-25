import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/triage/decision_tree.dart';
import 'package:shongjog/features/triage/triage_state.dart';

void main() {
  group('TriageState', () {
    test('startedAt is captured at construction', () {
      final before = DateTime.now();
      final state = TriageState();
      final after = DateTime.now();
      expect(state.startedAt.isAfter(before) ||
              state.startedAt.isAtSameMomentAs(before),
          isTrue);
      expect(state.startedAt.isBefore(after) ||
              state.startedAt.isAtSameMomentAs(after),
          isTrue);
    });

    test('addAnswer records questionId, bool, and elapsed time', () {
      final state = TriageState();
      state.addAnswer('conscious', true);
      expect(state.answers, hasLength(1));
      expect(state.answers.first.questionId, 'conscious');
      expect(state.answers.first.answer, isTrue);
      expect(state.answers.first.elapsed, isA<Duration>());
    });

    test('addAnswer appends in order', () {
      final state = TriageState();
      state.addAnswer('conscious', true);
      state.addAnswer('breathing', false);
      expect(state.answers.map((a) => a.questionId).toList(),
          ['conscious', 'breathing']);
    });

    test('reset clears all answers and bumps startedAt', () async {
      final state = TriageState();
      state.addAnswer('conscious', true);
      final beforeReset = state.startedAt;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state.reset();
      expect(state.answers, isEmpty);
      expect(state.startedAt.isAfter(beforeReset), isTrue);
    });

    test('route setter is recorded exactly once per terminal', () {
      final state = TriageState();
      state.route = TriageRoute.cpr;
      state.route = TriageRoute.bleeding;
      expect(state.route, TriageRoute.bleeding,
          reason: 'last set wins');
    });

    test('answerCount matches answers.length', () {
      final state = TriageState();
      expect(state.answerCount, 0);
      state.addAnswer('a', true);
      state.addAnswer('b', false);
      expect(state.answerCount, 2);
    });

    test('shareableSosText emits a 3-line Bangla recap', () {
      final state = TriageState();
      state.addAnswer('conscious', false);
      state.addAnswer('breathing', false);
      state.route = TriageRoute.cpr;
      final text = state.shareableSosText();
      expect(text, contains('সিপিআর'));
      expect(text.split('\n').length, 3);
    });

    test('summaryBn uses Bengali numerals for elapsed time', () {
      final state = TriageState();
      state.addAnswer('conscious', true);
      state.addAnswer('breathing', true);
      state.route = TriageRoute.bleeding;
      final summary = state.summaryBn();
      expect(summary, contains('রক্তপাত'));
    });

    test('elapsedBn renders the elapsed time in ঘ:মি:সে format', () {
      final state = TriageState();
      state.addAnswer('conscious', true);
      final elapsed = state.elapsedBn();
      expect(elapsed, matches(RegExp(r'^[০-৯]+:[০-৯]+:[০-৯]+$')));
    });
  });
}
