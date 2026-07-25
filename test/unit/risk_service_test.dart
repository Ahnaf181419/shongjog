import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/planner/risk_service.dart';

void main() {
  group('RiskService.extractScore', () {
    const svc = RiskService();

    test('extracts a Bangla-numeral score (the actual model output shape)',
        () {
      // The prompt instructs the model to answer using Bangla numerals —
      // this is what a real, prompt-compliant response looks like.
      expect(svc.extractScore('আপনার ঝুঁকি স্কোর: ৭/১০।'), 7);
    });

    test('extracts a bare Bangla-numeral score with no "/১০" suffix', () {
      expect(svc.extractScore('ঝুঁকি স্কোর ৫। বাড়ি টিনের তৈরি।'), 5);
    });

    test('extracts a two-digit Bangla score (১০/১০), not just one digit',
        () {
      expect(svc.extractScore('স্কোর: ১০/১০ — সর্বোচ্চ ঝুঁকি।'), 10);
    });

    test('an ASCII "X/10" pattern prefers the numerator over the 10', () {
      // Regression: naive multi-digit matching could grab the "10" in
      // "7/10" instead of the actual score, 7.
      expect(svc.extractScore('Risk score: 7/10'), 7);
    });

    test('still handles ASCII digits (defensive — not the expected shape)',
        () {
      expect(svc.extractScore('score is 3'), 3);
    });

    test('returns null when no number is present at all', () {
      expect(svc.extractScore('কোনো সংখ্যা নেই এখানে।'), isNull);
    });

    test('clamps an out-of-range extracted number into 1-10', () {
      // Defensive: if the model ever emits something like "স্কোর ৯৯",
      // don't hand the UI a nonsensical out-of-scale badge.
      expect(svc.extractScore('স্কোর ৯৯/১০'), 10);
    });
  });
}
