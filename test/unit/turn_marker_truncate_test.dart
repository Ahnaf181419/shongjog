import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/chat_repository.dart';

/// Truncation is the single most important post-processing guard
/// against the "long random same texts" symptom — when the model
/// emits a second User: turn after its real answer, the following
/// tokens are mostly degenerate. We chop at the first turn-marker
/// artifact.
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

    test('cuts at the first \\nUser: marker', () {
      const raw = 'ORS খান।\nUser: আর কিছু?\nএখন আরও বলো।\nএখন আরও বলো।';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'ORS খান।');
    });

    test('cuts at <start_of_turn>', () {
      const raw = 'ORS খান <start_of_turn>user\nপরের প্রশ্ন';
      final out = ChatRepository.truncateAtTurnMarker(raw);
      expect(out, 'ORS খান');
    });

    test('cuts at \\nAssistant (case-insensitive)', () {
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
      // <start_of_turn> appears before User: in the input — we
      // should cut at the earliest marker to keep the real answer.
      expect(out.startsWith('Real answer.'), isTrue);
      expect(out.contains('User:'), isFalse);
      expect(out.contains('<start_of_turn>'), isFalse);
    });
  });
}