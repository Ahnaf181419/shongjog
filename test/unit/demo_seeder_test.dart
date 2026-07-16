import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/demo_seeder.dart';

void main() {
  group('DemoSeeder.seeds', () {
    test('returns 3 seed Q&A pairs', () {
      final seeds = DemoSeeder.seeds();
      expect(seeds, hasLength(3));
    });

    test('each seed has a non-empty question and answer', () {
      for (final s in DemoSeeder.seeds()) {
        expect(s.question, isNotEmpty);
        expect(s.answer, isNotEmpty);
      }
    });

    test('seeds are idempotent — calling twice returns the same data',
        () {
      final first = DemoSeeder.seeds();
      final second = DemoSeeder.seeds();
      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].question, second[i].question);
        expect(first[i].answer, second[i].answer);
      }
    });
  });
}