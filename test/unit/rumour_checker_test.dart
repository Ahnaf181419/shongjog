import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/rumour_checker.dart';
import 'package:shongjog/rag/types.dart';

void main() {
  group('isRumourQuery', () {
    test('"গুজব:" prefix → true', () {
      expect(isRumourQuery('গুজব: সাপে কামড়ালে কেটে ফেলা উচিত'), isTrue);
    });

    test('"কেউ বললো" prefix → true', () {
      expect(isRumourQuery('কেউ বললো পানি না খেলে ডায়রিয়া সারে'), isTrue);
    });

    test('"শুনেছি" prefix → true', () {
      expect(isRumourQuery('শুনেছি বরফ দিলে জ্বর কমে'), isTrue);
    });

    test('normal query → false', () {
      expect(isRumourQuery('আমার বাচ্চার ডায়রিয়া হয়েছে'), isFalse);
    });

    test('leading whitespace handled', () {
      expect(isRumourQuery('  গুজব: এটা কি সত্য?'), isTrue);
    });
  });

  group('buildRumourCheckPrompt', () {
    test('contains verdict structure', () {
      final prompt = buildRumourCheckPrompt(
        query: 'গুজব: সাপে কামড়ালে কেটে ফেলা উচিত',
        hits: const [],
      );
      expect(prompt, contains('রায়'));
      expect(prompt, contains('ভুল'));
      expect(prompt, contains('৯৯৯'));
    });

    test('strips rumour prefix for the claim', () {
      final prompt = buildRumourCheckPrompt(
        query: 'গুজব: সাপে কামড়ালে কেটে ফেলা উচিত',
        hits: const [],
      );
      expect(prompt, contains('সাপে কামড়ালে কেটে ফেলা উচিত'));
      expect(prompt, contains('দাবি'));
    });

    test('includes retrieved context when hits provided', () {
      final hits = [
        RetrievalHit(
          Chunk(
            id: 'snake-1',
            topic: 'snakebite',
            source: 'WHO',
            text: 'সাপে কামড়ালে কাটবেন না, চুষবেন না।',
            keywordsBn: ['সাপ', 'কামড়'],
          ),
          1.0,
        ),
      ];
      final prompt = buildRumourCheckPrompt(
        query: 'গুজব: সাপে কামড়ালে কেটে ফেলা উচিত',
        hits: hits,
      );
      expect(prompt, contains('WHO'));
      expect(prompt, contains('সাপে কামড়ালে কাটবেন না'));
    });

    test('empty context still produces a valid prompt', () {
      final prompt = buildRumourCheckPrompt(
        query: 'কেউ বললো এটা সত্য',
        hits: const [],
      );
      expect(prompt, contains('নিশ্চিত নই'));
      expect(prompt, contains('দাবি'));
    });
  });
}
