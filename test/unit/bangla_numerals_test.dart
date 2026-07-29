import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/bangla_numerals.dart';

/// Numeral conversion is a product-voice rule for a Bangla-first app, not a
/// utility detail — a shelter capacity or a phone number rendered in Latin
/// digits reads as a bug to the people this is built for.
///
/// It previously existed in five places, twice in the same file with two
/// different implementations. These tests cover the one that survived.
void main() {
  group('toBanglaDigits', () {
    test('converts ASCII digits', () {
      expect(toBanglaDigits('3.4'), '৩.৪');
      expect(toBanglaDigits('1200'), '১২০০');
      expect(toBanglaDigits('0'), '০');
      expect(toBanglaDigits('0123456789'), '০১২৩৪৫৬৭৮৯');
    });

    test('leaves non-digit characters untouched', () {
      expect(toBanglaDigits('km 12.5'), 'km ১২.৫');
      expect(toBanglaDigits('12.5 কিমি'), '১২.৫ কিমি');
      expect(toBanglaDigits(''), '');
      expect(toBanglaDigits('কোনো সংখ্যা নেই'), 'কোনো সংখ্যা নেই');
    });

    test('does not double-convert digits that are already Bangla', () {
      // Guards against a call site that converts twice — which the old
      // scattered helpers made easy to do by accident.
      expect(toBanglaDigits('১২৩'), '১২৩');
      expect(toBanglaDigits(toBanglaDigits('123')), '১২৩');
    });

    test('preserves separators and symbols inside numbers', () {
      expect(toBanglaDigits('+880 1712-345678'), '+৮৮০ ১৭১২-৩৪৫৬৭৮');
      expect(toBanglaDigits('50%'), '৫০%');
      expect(toBanglaDigits('1,200'), '১,২০০',
          reason: 'Grouping separators pass through — this is a digit '
              'substitution, not a NumberFormat.');
    });
  });

  group('banglaNumber', () {
    test('converts ints', () {
      expect(banglaNumber(0), '০');
      expect(banglaNumber(7), '৭');
      expect(banglaNumber(2026), '২০২৬');
    });

    test('keeps the minus sign on negatives', () {
      expect(banglaNumber(-5), '-৫');
    });

    test('does not insert grouping separators', () {
      // The admin dashboard shows raw counts; a separator would be a
      // formatting decision no call site asked for.
      expect(banglaNumber(1200), '১২০০');
      expect(banglaNumber(1000000), '১০০০০০০');
    });
  });
}
