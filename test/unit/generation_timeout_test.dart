import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/model_manager.dart';

/// The spinner-forever failure has two halves, and fixing only the first
/// leaves the symptom intact:
///
///   1. `getResponse()` had no timeout, so a stalled engine hung the chat.
///   2. `close()` in the `finally` can itself block until the still-running
///      native inference finishes — so an unbounded await there converts the
///      new timeout straight back into an indefinite wait.
///
/// These tests pin the timing contract rather than the plugin, which cannot
/// be instantiated in a unit test.
void main() {
  test('the generation budget is finite and generous', () {
    // Finite is the whole point. Generous because a healthy E4B run on a
    // low-end phone can legitimately take 30-40s, and timing out a working
    // answer would be its own bug.
    expect(ModelManager.kGenerationTimeout, greaterThan(const Duration(seconds: 60)));
    expect(ModelManager.kGenerationTimeout, lessThan(const Duration(minutes: 5)));
  });

  group('the timeout+cleanup composition cannot exceed its budget', () {
    // Models the production shape: a generation that never completes, a
    // close() that also never completes, and the bounds placed on both.
    Future<String> generateLike({
      required Duration genBudget,
      required Duration closeBudget,
    }) async {
      final never = Completer<String>();
      final neverCloses = Completer<void>();
      try {
        return await never.future.timeout(genBudget,
            onTimeout: () => throw TimeoutException('gen'));
      } finally {
        try {
          await neverCloses.future.timeout(closeBudget);
        } catch (_) {
          // Swallowed, exactly as _closeQuietly does.
        }
      }
    }

    test('a hung generation AND a hung close still surface an error', () async {
      final sw = Stopwatch()..start();
      await expectLater(
        generateLike(
          genBudget: const Duration(milliseconds: 120),
          closeBudget: const Duration(milliseconds: 80),
        ),
        throwsA(isA<TimeoutException>()),
      );
      sw.stop();
      // It must return at all — and within gen + close, not never.
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('an unbounded close would hang forever — the bug being guarded',
        () async {
      final never = Completer<String>();
      final neverCloses = Completer<void>();
      Future<String> bad() async {
        try {
          return await never.future.timeout(const Duration(milliseconds: 50),
              onTimeout: () => throw TimeoutException('gen'));
        } finally {
          await neverCloses.future; // unbounded — the original mistake
        }
      }

      var settled = false;
      unawaited(bad().then((_) => settled = true, onError: (_) => settled = true));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(settled, isFalse,
          reason: 'an unbounded close in the finally swallows the timeout, '
              'which is why _closeQuietly bounds it');
    });
  });
}
