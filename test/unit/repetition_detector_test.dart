import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/repetition_detector.dart';

/// Tests for the streaming repetition detector.
///
/// These are the patterns the user reported seeing in the offline
/// chat — "long random same texts". Each test feeds a realistic
/// token stream and asserts the detector fires at the right point.
void main() {
  group('RepetitionDetector', () {
    test('does NOT fire on a clean, varied Bangla answer', () {
      final d = RepetitionDetector();
      const clean =
          'ভূমিকম্পের সময় নিরাপদ স্থানে থাকুন। টেবিলের নিচে লুকান এবং মাথা '
          'রক্ষা করুন। কাঁচের জিনিস থেকে দূরে থাকুন। প্রয়োজনে ৯৯৯ এ কল করুন।';
      d.feed(clean);
      expect(d.shouldStop, isFalse,
          reason: 'A legitimate, varied emergency answer must not trip the detector.');
    });

    test('fires on immediate single-token stall (আমি আমি আমি …)', () {
      final d = RepetitionDetector(stallLimit: 4);
      d.feed('ভূমিকম্পের সময় নিরাপদ স্থানে থাকুন। '); // legit prefix
      expect(d.shouldStop, isFalse);
      // Now stall on a single short token.
      d.feed('আমি আমি আমি আমি ');
      expect(d.shouldStop, isTrue,
          reason: 'Stall heuristic: "আমি" repeated as a short token must fire.');
    });

    test('fires on character-run stall (। । । …)', () {
      final d = RepetitionDetector(stallLimit: 5);
      d.feed('উত্তর দিচ্ছি ');
      d.feed('। । । । । । ');
      expect(d.shouldStop, isTrue,
          reason: 'The danda (।) is a 1-char token; 5+ in a row is a stall.');
    });

    test('fires on 3-token n-gram repeat (foo bar baz foo bar baz)', () {
      final d = RepetitionDetector();
      d.feed('প্রাথমিক চিকিৎসা প্রাথমিক চিকিৎসা প্রাথমিক চিকিৎসা ');
      expect(d.shouldStop, isTrue,
          reason: 'n-gram heuristic: 3-token phrase repeated twice must fire.');
    });

    test('does NOT fire on legitimate emphasis (হ্যাঁ হ্যাঁ)', () {
      final d = RepetitionDetector();
      d.feed('হ্যাঁ হ্যাঁ, আমি শুনতে পাচ্ছি। বলুন কী সাহায্য দরকার। ');
      expect(d.shouldStop, isFalse,
          reason: 'A 2-token repeat once is normal emphasis, not a loop.');
    });

    test('fires on vocabulary collapse (cycles through tiny vocabulary)', () {
      final d = RepetitionDetector(minDistinctRatio: 0.40);
      // Same handful of tokens cycling — the "long random same texts"
      // symptom where no single token stalls but the vocabulary is tiny.
      d.feed('যাও এসো যাও এসো যাও এসো যাও এসো যাও এসো যাও এসো ');
      expect(d.shouldStop, isTrue,
          reason: 'Vocabulary-collapse heuristic must catch cycling output.');
    });

    test('trimmed() strips the trailing partial-repetition tail', () {
      final d = RepetitionDetector(stallLimit: 4);
      d.feed('নিরাপদ স্থানে যান। ');
      d.feed('আমি আমি আমি আমি আমি ');
      expect(d.shouldStop, isTrue);
      final out = d.trimmed();
      expect(out, contains('নিরাপদ স্থানে যান।'));
      expect(out.contains('আমি আমি আমি'), isFalse,
          reason: 'The repeated tail must be stripped.');
    });

    test('feed after shouldStop is a no-op (sticky stop)', () {
      final d = RepetitionDetector(stallLimit: 3, minTokensBeforeCheck: 1);
      // Enough prefix + 4 standalone dandas so the trailing-run walk
      // crosses stallLimit=3.
      d.feed('প্রশ্ন উত্তর । । । । ');
      expect(d.shouldStop, isTrue);
      final lenAfterStop = d.buffer.length;
      d.feed('এই টেক্সট বাফারে যোগ হবে না');
      expect(d.buffer.length, lenAfterStop,
          reason: 'Once stopped, further feed() calls must be ignored.');
    });

    test('does not fire before minTokensBeforeCheck', () {
      final d = RepetitionDetector(minTokensBeforeCheck: 50);
      d.feed('আমি আমি ');
      expect(d.shouldStop, isFalse,
          reason: 'Short prefix must not be inspected to avoid false positives.');
    });

    // ─── Full-text feed (non-streaming) contract ───────────────────
    // The detector must also work when the entire model response is
    // fed in one call (post-process mode, as used by the safe trim in
    // ModelManager._safeTrimRepetition).

    test('detects repetition when full degenerate text is fed at once', () {
      final d = RepetitionDetector();
      const degenerate = 'নিরাপদ স্থানে যান। আমি আমি আমি আমি আমি আমি আমি আমি';
      d.feed(degenerate);
      expect(d.shouldStop, isTrue);
    });

    test('does NOT fire when fed a long clean answer in one chunk', () {
      final d = RepetitionDetector();
      const clean = 'ভূমিকম্পের সময় নিরাপদ স্থানে থাকুন। টেবিলের নিচে লুকান '
          'এবং মাথা রক্ষা করুন। কাঁচের জিনিস থেকে দূরে থাকুন। প্রয়োজনে '
          '৯৯৯ এ কল করুন। অগ্নিকাণ্ড হলে দ্রুত বেরিয়ে আসুন।';
      d.feed(clean);
      expect(d.shouldStop, isFalse);
    });
  });

  group('_safeTrimRepetition contract (never empty)', () {
    // Reproduces ModelManager._safeTrimRepetition's logic inline so the
    // test doesn't need a device-loaded model. The contract: if the
    // raw text has repetition, trim; if the trim would be empty, return
    // the raw text unchanged. Blank chat bubble is a WORSE failure than
    // a degenerate answer.
    String safeTrim(String raw) {
      if (raw.trim().isEmpty) return raw;
      final d = RepetitionDetector();
      d.feed(raw);
      if (!d.shouldStop) return raw;
      final t = d.trimmed();
      return t.trim().isEmpty ? raw : t;
    }

    test('returns raw text when no repetition detected', () {
      const clean = 'নিরাপদ স্থানে থাকুন। প্রয়োজনে ৯৯৯ এ কল করুন।';
      expect(safeTrim(clean), equals(clean));
    });

    test('trims the repetition loop and keeps the clean prefix', () {
      const raw = 'নিরাপদ স্থানে যান। আমি আমি আমি আমি আমি আমি আমি আমি';
      final out = safeTrim(raw);
      expect(out, isNot(equals(raw)),
          reason: 'Repetitive tail must be trimmed.');
      expect(out, contains('নিরাপদ স্থানে'));
      // trimmed() may keep a single trailing token; what matters is
      // that the multi-token loop is gone.
      expect(out.length, lessThan(raw.length));
    });

    test('NEVER returns empty even on all-repetition input', () {
      const allRepeat = 'আমি আমি আমি আমি আমি আমি আমি আমি আমি আমি';
      final out = safeTrim(allRepeat);
      expect(out.trim().isNotEmpty, isTrue,
          reason: 'The golden rule: blank bubble is always worse than a degenerate answer.');
    });
  });
}
