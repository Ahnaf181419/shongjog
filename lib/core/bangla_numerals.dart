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

/// [n] in the numeral system that [languageCode] reads.
///
/// The generated `AppLocalizations` methods interpolate an `int` placeholder
/// with `'$n'`, which is always Latin digits — so a Bangla string built from
/// an int placeholder renders "12 মিনিট আগে" rather than "১২ মিনিট আগে",
/// against §5.2 ("Numbers in user-facing copy: Bangla numerals"). Call sites
/// pass the numeral through here and the ARB placeholder is typed `String`.
///
/// Takes a language code rather than a `BuildContext` so this file stays
/// Flutter-free, like the rest of `core/`.
String numberForLocale(int n, String languageCode) =>
    languageCode.toLowerCase().startsWith('bn')
        ? banglaNumber(n)
        : n.toString();

/// Renders a pre-formatted number string (e.g. `"12.5"`, `"45%"`) in the
/// numeral system for [languageCode]. Bangla in bn mode, Latin elsewhere.
/// Decimal separators and any non-digit characters pass through.
String digitsForLocale(String s, String languageCode) =>
    languageCode.toLowerCase().startsWith('bn') ? toBanglaDigits(s) : s;
