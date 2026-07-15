import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/prompt_builder.dart';
import 'package:shongjog/rag/types.dart';

void main() {
  group('buildPrompt', () {
    test('assembles persona + rules + context + query for emergency topic', () {
      final hits = [
        RetrievalHit(
          const Chunk(
            id: 'ors1',
            topic: 'ors',
            source: 'WHO',
            text: 'ORS রেসিপি...',
            keywordsBn: ['ORS'],
          ),
          0.82,
        ),
      ];
      final prompt = buildPrompt(query: 'বাচ্চার ডায়রিয়া', hits: hits);

      // Persona present.
      expect(prompt, contains('You are Shongjog'));
      // Language matching rule present.
      expect(prompt, contains('same language'));
      // Retrieved context present, with source bracket.
      expect(prompt, contains('[WHO] ORS রেসিপি'));
      // User query echoed.
      expect(prompt, contains('বাচ্চার ডায়রিয়া'));
      // 999 escalation present for emergency query (Bengali numerals).
      expect(prompt, contains('৯৯৯'));
    });

    test('empty hits omits context section entirely', () {
      final prompt = buildPrompt(query: 'তোমার নাম কি', hits: const []);
      expect(prompt, contains('তোমার নাম কি'));
      // No context section when hits are empty.
      expect(prompt, isNot(contains('Verified context')));
      expect(prompt, isNot(contains('প্রসঙ্গ')));
      // No 999 for non-emergency query.
      expect(prompt, isNot(contains('৯৯৯')));
    });

    test('999 only appended for emergency queries', () {
      final prompt =
          buildPrompt(query: 'বাচ্চার জ্বর কমাতে কি করবো', hits: const []);
      expect(prompt, contains('৯৯৯'));
    });

    test('multiple hits are joined with source brackets', () {
      final hits = [
        RetrievalHit(
          const Chunk(
              id: 'a', topic: 'ors', source: 'WHO', text: 'AAA', keywordsBn: []),
          0.9,
        ),
        RetrievalHit(
          const Chunk(
              id: 'b',
              topic: 'water',
              source: 'CDC',
              text: 'BBB',
              keywordsBn: []),
          0.7,
        ),
      ];
      final prompt = buildPrompt(query: 'q', hits: hits);
      expect(prompt, contains('[WHO] AAA'));
      expect(prompt, contains('[CDC] BBB'));
    });

    test('isEmergencyQuery detects Bangla and English keywords', () {
      expect(isEmergencyQuery('জরুরি সাহায্য দরকার'), isTrue);
      expect(isEmergencyQuery('I have chest pain'), isTrue);
      expect(isEmergencyQuery('what is the weather'), isFalse);
    });
  });
}
