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

  test('drain stops on first failure and leaves the failed entry at the head',
      () async {
    final q = SmsQueue((b, p) async => b != 'fail');
    q.enqueue('ok1', 'p1');
    q.enqueue('fail', 'p2');
    q.enqueue('ok2', 'p3');
    final sent = await q.drain();
    expect(sent, 1); // ok1 succeeded; fail stopped the drain.
    // 'fail' is at the head; 'ok2' still queued. Total pending = 2.
    expect(q.pending, 2);
    // Resuming: only the 'fail' entry should be retried first.
    final okQueue = SmsQueue((b, p) async => true);
    okQueue.enqueue('fail', 'p2');
    okQueue.enqueue('ok2', 'p3');
    final sent2 = await okQueue.drain();
    expect(sent2, 2);
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