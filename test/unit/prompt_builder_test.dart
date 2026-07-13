import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/prompt_builder.dart';
import 'package:shongjog/rag/types.dart';

void main() {
  group('buildPrompt', () {
    test('assembles system + context + query, always includes 999 reminder', () {
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

      // System prompt present.
      expect(prompt, contains('তুমি শঙ্গ্যোগ, একজন বাংলা ভাষায়'));
      // Retrieved context present, with source bracket.
      expect(prompt, contains('[WHO] ORS রেসিপি'));
      // User query echoed.
      expect(prompt, contains('বাচ্চার ডায়রিয়া'));
      // The 999 escalation cue must ALWAYS be in the assembled prompt.
      expect(prompt, contains('999'));
    });

    test('empty hits still assembles a valid prompt', () {
      final prompt = buildPrompt(query: 'অজানা প্রশ্ন', hits: const []);
      expect(prompt, contains('অজানা প্রশ্ন'));
      expect(prompt, contains('999'));
      // The system prompt's no-context fallback line should appear.
      expect(prompt, contains('কোনো প্রসঙ্গ'));
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
  });
}