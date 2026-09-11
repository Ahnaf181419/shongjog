import 'nearest_shelter.dart';
import 'shelter_strings_loader.dart';
import '../../core/bangla_numerals.dart';

/// Formats the result of a `find_nearest_shelter` tool call into a
/// Bangla chat message.
///
/// Pure Dart — no device, no plugins. The chat repository calls this
/// after running `ShelterToolDispatcher.dispatch` to produce the text
/// the user sees in the chat bubble.
class ShelterToolResultFormatter {
  ShelterToolResultFormatter._();

  /// Build the user-facing message from a ranked shelter list.
  /// Templates come from the locale-loaded `ShelterStrings` bundle; the
  /// shelter name and digits follow the app's current locale.
  static String toMessage(
    List<RankedShelter> ranked, {
    ShelterStrings? s,
    String localeCode = 'bn',
  }) {
    final strings = s ?? cachedShelter;
    if (ranked.isEmpty) {
      return strings.toolEmpty;
    }

    final isBangla = localeCode.toLowerCase().startsWith('bn');
    final buf = StringBuffer();
    buf.writeln(strings.toolTitle);
    buf.writeln();
    for (var i = 0; i < ranked.length; i++) {
      final r = ranked[i];
      final name = r.shelter.displayName(localeCode);
      final dist = isBangla
          ? toBanglaDigits(r.km.toStringAsFixed(1))
          : r.km.toStringAsFixed(1);
      final index = isBangla
          ? toBanglaDigits('${i + 1}')
          : '${i + 1}';
      final template = r.shelter.capacity != null
          ? strings.toolEntryWithCapacity
          : strings.toolEntry;
      final entry = template
          .replaceAll('{index}', index)
          .replaceAll('{name}', name)
          .replaceAll('{km}', dist);
      if (r.shelter.capacity != null) {
        final cap = isBangla
            ? toBanglaDigits('${r.shelter.capacity}')
            : '${r.shelter.capacity}';
        buf.writeln(entry.replaceAll('{capacity}', cap));
      } else {
        buf.writeln(entry);
      }
    }
    buf.writeln();
    buf.write(strings.toolMapHint);
    return buf.toString();
  }

  /// Back-compat alias. Same as [toMessage] but defaults to bn.
  static String toBanglaMessage(List<RankedShelter> ranked,
      {ShelterStrings? s}) {
    return toMessage(ranked, s: s, localeCode: 'bn');
  }

  /// Convert ASCII digits in [s] to Bengali numerals (০-৯). Leaves all
  /// other characters (letters, punctuation, the decimal point)
  /// untouched. Used for distances, capacities, and list indices.
}
