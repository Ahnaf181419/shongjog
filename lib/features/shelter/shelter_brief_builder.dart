import 'nearest_shelter.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';

/// Builds the prompt for an AI-generated per-shelter risk brief
/// (Option 3 in docs/AI-MAP-FEATURES.md).
///
/// When the user taps a shelter pin, this produces a one-sentence
/// Bangla risk assessment that combines distance, capacity, and
/// proximity to live hazards. The model writes the sentence; this
/// class supplies the structured context.
///
/// Also provides a deterministic fallback string for when the model
/// is offline or fails — the info card always shows something useful.
class ShelterBriefBuilder {
  ShelterBriefBuilder._();

  /// Build the prompt for the model. Returns null when there's not
  /// enough context to write a meaningful brief (no user position or
  /// no shelter).
  static String? buildPrompt({
    required double? userLat,
    required double? userLon,
    required RankedShelter? shelter,
    List<EonetEvent>? hazards,
    List<GdacsAlert>? alerts,
  }) {
    if (userLat == null || userLon == null || shelter == null) return null;

    final s = shelter.shelter;
    final name = s.nameBn.isNotEmpty ? s.nameBn : s.name;
    final buf = StringBuffer();
    buf.writeln('You are Shongjog, a warm Bangla emergency companion.');
    buf.writeln('Write ONE concise sentence (in Bangla) assessing the safety '
        'of this shelter for the user right now. Be warm but factual. '
        'Use Bengali numerals (০-৯).');
    buf.writeln();
    buf.writeln('শেল্টার: $name');
    buf.writeln('দূরত্ব: ${shelter.km.toStringAsFixed(1)} কিমি');
    if (s.capacity != null) {
      buf.writeln('ধারণক্ষমতা: ${s.capacity}');
    }
    buf.writeln('অবস্থান: lat ${s.lat}, lon ${s.lon}');
    buf.writeln('ব্যবহারকারীর অবস্থান: lat $userLat, lon $userLon');

    if (hazards != null && hazards.isNotEmpty) {
      buf.writeln('সক্রিয় ঝুঁকি:');
      for (final h in hazards.take(3)) {
        buf.writeln('  - ${h.category.labelBn}: ${h.title} '
            '(lat ${h.latitude}, lon ${h.longitude})');
      }
    }
    if (alerts != null && alerts.isNotEmpty) {
      buf.writeln('UN/GDACS সতর্কতা:');
      for (final a in alerts.take(2)) {
        buf.writeln('  - ${a.severity.labelBn}: ${a.title}');
      }
    }

    buf.writeln();
    buf.write('উত্তর (এক বাক্যে, বাংলায়):');
    return buf.toString();
  }

  /// Deterministic fallback brief for when the model is unavailable.
  /// Always returns a useful sentence — never empty.
  static String fallbackBrief({
    required RankedShelter? shelter,
  }) {
    if (shelter == null) {
      return 'এই শেল্টারের তথ্য লোড হচ্ছে।';
    }
    final s = shelter.shelter;
    final name = s.nameBn.isNotEmpty ? s.nameBn : s.name;
    // Build the distance with Bengali numerals.
    final distBn = _toBangla(shelter.km.toStringAsFixed(1));
    var brief = '$name আপনার অবস্থান থেকে $distBn কিমি দূরে।';
    if (s.capacity != null) {
      final capBn = _toBangla('${s.capacity}');
      brief += ' ধারণক্ষমতা $capBn জন।';
    }
    return brief;
  }

  static String _toBangla(String s) {
    const map = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }
}
