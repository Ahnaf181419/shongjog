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
  });
}
