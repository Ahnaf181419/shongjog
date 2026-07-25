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
      // Retrieved context present, with source attribution.
      expect(prompt, contains('[Source: WHO] ORS রেসিপি'));
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
      expect(prompt, contains('[Source: WHO] AAA'));
      expect(prompt, contains('[Source: CDC] BBB'));
    });

    test('isEmergencyQuery detects Bangla and English keywords', () async {
      expect(isEmergencyQuery('জরুরি সাহায্য দরকার'), isTrue);
      expect(isEmergencyQuery('I have chest pain'), isTrue);
      expect(isEmergencyQuery('what is the weather'), isFalse);
    });

    test('history turns appear between context and current query', () {
      final history = [
        ChatTurn(text: 'তোমার নাম কি', isUser: true),
        ChatTurn(text: 'আমার নাম শঞ্জোগ', isUser: false),
      ];
      final prompt = buildPrompt(
        query: 'আবার বলো',
        hits: const [],
        history: history,
      );
      expect(prompt, contains('User: তোমার নাম কি'));
      expect(prompt, contains('Assistant: আমার নাম শঞ্জোগ'));
      final historyIdx = prompt.indexOf('User: তোমার নাম কি');
      final queryIdx = prompt.indexOf('User: আবার বলো');
      expect(historyIdx, lessThan(queryIdx));
    });

    test('empty history produces same prompt as before', () {
      final without = buildPrompt(query: 'হাই', hits: const []);
      final withEmpty =
          buildPrompt(query: 'হাই', hits: const [], history: const []);
      expect(without, equals(withEmpty));
    });

    test('history is capped at 4 turns', () {
      final history = List.generate(
          10, (i) => ChatTurn(text: 'turn $i', isUser: i.isEven));
      final prompt = buildPrompt(
        query: 'latest',
        hits: const [],
        history: history,
      );
      expect(prompt, isNot(contains('User: turn 0')));
      expect(prompt, isNot(contains('User: turn 1')));
      expect(prompt, contains('User: turn 8'));
      expect(prompt, contains('Assistant: turn 9'));
    });
  });
}
