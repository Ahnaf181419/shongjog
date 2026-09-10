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

  /// Build the user-facing Bangla message from a ranked shelter list.
  static String toBanglaMessage(List<RankedShelter> ranked, {ShelterStrings? s}) {
    final strings = s ?? cachedShelter;
    if (ranked.isEmpty) {
      return strings.toolEmpty;
    }

    final buf = StringBuffer();
    buf.writeln(strings.toolTitle);
    buf.writeln();
    for (var i = 0; i < ranked.length; i++) {
      final r = ranked[i];
      final name = r.shelter.nameBn.isNotEmpty ? r.shelter.nameBn : r.shelter.name;
      final distBn = toBanglaDigits(r.km.toStringAsFixed(1));
      final indexBn = toBanglaDigits('${i + 1}');
      final template = r.shelter.capacity != null
          ? strings.toolEntryWithCapacity
          : strings.toolEntry;
      final entry = template
          .replaceAll('{index}', indexBn)
          .replaceAll('{name}', name)
          .replaceAll('{km}', distBn);
      if (r.shelter.capacity != null) {
        final capBn = toBanglaDigits('${r.shelter.capacity}');
        buf.writeln(entry.replaceAll('{capacity}', capBn));
      } else {
        buf.writeln(entry);
      }
    }
    buf.writeln();
    buf.write(strings.toolMapHint);
    return buf.toString();
  }

  /// Convert ASCII digits in [s] to Bengali numerals (০-৯). Leaves all
  /// other characters (letters, punctuation, the decimal point)
  /// untouched. Used for distances, capacities, and list indices.
}
