import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/safe_beacon/sms_queue.dart';

void main() {
  test('enqueue increases pending', () {
    final q = SmsQueue((b, p) async => true);
    expect(q.pending, 0);
    q.enqueue('hi', '017');
    expect(q.pending, 1);
    q.enqueue('hi2', '018');
    expect(q.pending, 2);
  });

  test('drain happy path sends everything and returns count', () async {
    int calls = 0;
    final q = SmsQueue((b, p) async {
      calls++;
      return true;
    });
    q.enqueue('m1', 'p1');
    q.enqueue('m2', 'p2');
    q.enqueue('m3', 'p3');
    final sent = await q.drain();
    expect(sent, 3);
    expect(calls, 3);
    expect(q.pending, 0);
  });

  test('drain skips failed entries and retries them at the end', () async {
    final q = SmsQueue((b, p) async => b != 'fail');
    q.enqueue('ok1', 'p1');
    q.enqueue('fail', 'p2');
    q.enqueue('ok2', 'p3');
    final sent = await q.drain();
    expect(sent, 2); // ok1 + ok2 succeeded; fail was skipped.
    // 'fail' is re-queued at the head for retry.
    expect(q.pending, 1);
    // Resuming: the failed entry is retried first.
    final sent2 = await q.drain();
    expect(sent2, 0); // still fails
    expect(q.pending, 1); // stays queued
  });

  test('drain empty queue returns 0 without calling sendOne', () async {
    int calls = 0;
    final q = SmsQueue((b, p) async {
      calls++;
      return true;
    });
    final sent = await q.drain();
    expect(sent, 0);
    expect(calls, 0);
  });
}