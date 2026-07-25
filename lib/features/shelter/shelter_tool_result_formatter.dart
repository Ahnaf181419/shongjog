import 'nearest_shelter.dart';

/// Formats the result of a `find_nearest_shelter` tool call into a
/// Bangla chat message.
///
/// Pure Dart — no device, no plugins. The chat repository calls this
/// after running `ShelterToolDispatcher.dispatch` to produce the text
/// the user sees in the chat bubble.
class ShelterToolResultFormatter {
  ShelterToolResultFormatter._();

  /// Build the user-facing Bangla message from a ranked shelter list.
  ///
  /// Empty list → a helpful fallback pointing the user to 999.
  /// Non-empty → a numbered list (Bengali digits) of name + distance +
  /// optional capacity, plus a "tap to view on map" hint.
  static String toBanglaMessage(List<RankedShelter> ranked) {
    if (ranked.isEmpty) {
      return 'আমার কাছে এই এলাকার কোনো শেল্টারের তথ্য নেই। '
          'জরুরি সাহায্যের জন্য ৯৯৯ এ কল করুন।';
    }

    final buf = StringBuffer();
    buf.writeln('নিকটস্থ শেল্টারসমূহ:');
    buf.writeln();
    for (var i = 0; i < ranked.length; i++) {
      final r = ranked[i];
      final name = r.shelter.nameBn.isNotEmpty ? r.shelter.nameBn : r.shelter.name;
      final distBn = toBanglaDigits(r.km.toStringAsFixed(1));
      buf.write('${toBanglaDigits('${i + 1}')}. $name — $distBn কিমি');
      if (r.shelter.capacity != null) {
        final capBn = toBanglaDigits('${r.shelter.capacity}');
        buf.write(' (ধারণক্ষমতা $capBn)');
      }
      buf.writeln();
    }
    buf.writeln();
    buf.write('মানচিত্রে দেখতে আশ্রয় ট্যাবে যান।');
    return buf.toString();
  }

  /// Convert ASCII digits in [s] to Bengali numerals (০-৯). Leaves all
  /// other characters (letters, punctuation, the decimal point)
  /// untouched. Used for distances, capacities, and list indices.
  static String toBanglaDigits(String s) {
    const map = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }
}
