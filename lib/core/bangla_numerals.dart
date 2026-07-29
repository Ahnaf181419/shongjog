/// Bangla numeral conversion — the single source of truth.
///
/// This lived in seven places before, including twice in the same file with
/// two different implementations. For a Bangla-first app that is not a
/// duplication nit: it is a formatting rule about how the product speaks, and
/// it belongs next to the font tokens rather than scattered through screens.
///
/// Deliberately NOT `intl`'s `NumberFormat`. That would also insert locale
/// grouping separators, which changes emergency numbers and shelter counts in
/// ways no call site asked for. This is a pure digit substitution.
library;

const List<String> _banglaDigits = [
  '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
];

/// Latin digits in [input] rendered as Bangla. Every other character —
/// separators, units, Bangla text — passes through untouched.
///
/// ```dart
/// toBanglaDigits('12.5 km')  // '১২.৫ km'
/// ```
String toBanglaDigits(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    // 0x30..0x39 is ASCII '0'..'9'.
    if (rune >= 0x30 && rune <= 0x39) {
      buf.write(_banglaDigits[rune - 0x30]);
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

/// [n] as a Bangla numeral. Negative values keep their leading minus.
String banglaNumber(int n) => toBanglaDigits(n.toString());
