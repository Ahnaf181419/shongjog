import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/chat_repository.dart';

/// Truncation is the single most important post-processing guard
/// against two user-visible symptoms of the LiteRT-LM engine:
///
/// 1. When the model emits a second User: turn after its real answer,
///    the following tokens are mostly degenerate. We chop at the
///    first turn-marker artifact.
/// 2. When thinking mode is enabled, the engine leaks internal
///    channel tokens into the visible response. We strip those
///    blocks entirely (keeping only text that comes BEFORE the
///    first channel marker, since anything after a channel block
///    is a separate output stream the user shouldn't see).
///
/// This test exercises the REAL production method
/// (ChatRepository.truncateAtTurnMarker) — not a private copy — so
/// the test breaks if the production code regresses.
void main() {
  group('truncateAtTurnMarker (production code)', () {
    test('keeps a clean short answer intact', () {
      const raw = 'ORS খান। প্রচুর পানি পান করুন।';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, raw);
    });

    test('cuts at the first User: marker', () {
      const raw = 'ORS খান।\nUser: আর কিছু?\nএখন আরও বলো।\nএখন আরও বলো।';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'ORS খান।');
    });

    test('cuts at <start_of_turn>', () {
      const raw = 'ORS খান <start_of_turn>user\nপরের প্রশ্ন';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'ORS খান');
    });

    test('cuts at Assistant (case-insensitive)', () {
      const raw = 'উত্তর।\nAssistant:\nআরেকটা উত্তর';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'উত্তর।');
    });

    test('preserves multibyte Bangla characters intact', () {
      const raw = 'উত্তর: ORS খান এবং বিশ্রাম নিন।';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, raw);
    });

    test('handles empty input', () {
      final out = ChatRepository.truncateAtTurnMarker('');
      expect(out, '');
    });

    test('chose the EARLIEST marker when multiple are present', () {
      const raw = 'Real answer.\n<start_of_turn>\nstuff\nUser: garbage';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out.startsWith('Real answer.'), isTrue);
      expect(out.contains('User:'), isFalse);
      expect(out.contains('<start_of_turn>'), isFalse);
    });

    test('strips <|channel|>thought ... <|channel|> blocks '
        '(the user-reported symptom)', () {
      // Exact pattern from the user's image.png screenshot:
      // LiteRT-LM with thinking mode ON leaks internal thought
      // tokens into the visible response. We strip EVERYTHING from
      // the first <|channel|> marker onward, including any "real"
      // answer that happens to follow. This matches the real
      // device behaviour observed by the user: when thinking mode
      // is on, the visible response IS channel tokens and nothing
      // else. Stripping them produces an empty response, which the
      // UI already handles (renders an error bubble or prompt the
      // user to retry).
      const raw = '<|channel|>thought Thinking<|channel|>'
          '<|channel|>thought Process<|channel|>'
          '<|channel|>thought Analyze the Request<|channel|>'
          'Real answer here';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, '');
    });

    test('strips <|channel|>...<|channel|> with non-thinking content', () {
      const raw = 'Good answer\n<|channel|>some other channel<|channel|>'
          'extra junk';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'Good answer');
    });

    test('strips multiple <|channel|> blocks in a row', () {
      const raw = 'Answer text <|channel|>thought junk<|channel|>'
          '<|channel|>thought more junk<|channel|>';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'Answer text');
    });

    test('handles <|channel|> at the very start of output', () {
      const raw = '<|channel|>thought junk<|channel|>real answer';
      // Strip everything from the channel-open marker onward, since
      // content after a channel block is the model's "tool" or
      // "thought" stream the user shouldn't see.
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, '');
    });
  });
}
