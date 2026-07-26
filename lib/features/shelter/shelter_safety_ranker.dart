import 'dart:convert';

import 'nearest_shelter.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';

/// AI-augmented shelter ranker (Option 2 in docs/AI-MAP-FEATURES.md).
///
/// Re-orders a distance-ranked shelter list by an AI-computed safety
/// score that considers live hazard proximity (cyclone tracks, floods)
/// and shelter capacity. When the model is unavailable or its response
/// is unparseable, falls back to the distance-only ranking — the map
/// never blocks on a model call.
///
/// The prompt is built deterministically from structured data and the
/// model's response is a JSON array of indices. Both the prompt
/// construction and the response parsing are pure Dart and unit-tested.
class ShelterSafetyRanker {
  ShelterSafetyRanker._();

  /// Build the one-shot ranking prompt from the user's location, the
  /// candidate shelters, and nearby hazards. Returns null when there
  /// are no hazards to weight against — in that case the distance-only
  /// ranking is already correct and the model shouldn't be called.
  static String? buildPrompt({
    required double userLat,
    required double userLon,
    required List<RankedShelter> candidates,
    List<EonetEvent>? hazards,
    List<GdacsAlert>? alerts,
  }) {
    // No hazards → no AI weighting needed. The caller keeps the
    // distance-only ranking.
    final hasHazards =
        (hazards != null && hazards.isNotEmpty) ||
        (alerts != null && alerts.isNotEmpty);
    if (!hasHazards || candidates.length <= 1) return null;

    final buf = StringBuffer();
    buf.writeln('You are a disaster-safety assistant for Bangladesh.');
    buf.writeln(
        'Given the user\'s location and a list of nearby cyclone shelters, '
        'rank them SAFEST-FIRST considering:');
    buf.writeln('- Distance from the user (closer is better).');
    buf.writeln('- Proximity to active hazards (farther from storms/floods is better).');
    buf.writeln('- Capacity (larger is better during a surge).');
    buf.writeln();
    buf.writeln('User location: lat $userLat, lon $userLon');
    buf.writeln();

    buf.writeln('Shelters (indexed 0..${candidates.length - 1}):');
    for (var i = 0; i < candidates.length; i++) {
      final r = candidates[i];
      buf.writeln(
          '  [$i] ${r.shelter.nameBn.isNotEmpty ? r.shelter.nameBn : r.shelter.name} '
          '— ${r.km.toStringAsFixed(1)} km, capacity ${r.shelter.capacity ?? "unknown"}, '
          'lat ${r.shelter.lat}, lon ${r.shelter.lon}');
    }
    buf.writeln();

    if (hazards != null && hazards.isNotEmpty) {
      buf.writeln('Active hazards nearby:');
      for (final h in hazards.take(5)) {
        buf.writeln(
            '  - ${h.category.labelBn}: "${h.title}" '
            'at lat ${h.latitude}, lon ${h.longitude} (active: ${h.isActive})');
      }
      buf.writeln();
    }

    if (alerts != null && alerts.isNotEmpty) {
      buf.writeln('UN/GDACS alerts:');
      for (final a in alerts.take(3)) {
        buf.writeln(
            '  - ${a.severity.labelBn}: "${a.title}" '
            'at lat ${a.latitude}, lon ${a.longitude}');
      }
      buf.writeln();
    }

    buf.writeln('Return ONLY a JSON array of shelter indices, safest-first. '
        'Example: [2, 0, 1]');
    return buf.toString();
  }

  /// Parse the model's JSON-array response into a re-ordered shelter
  /// list. Returns null if the response is unparseable, references
  /// out-of-range indices, or doesn't cover all candidates — the
  /// caller then keeps the distance-only ranking.
  ///
  /// [response] is the raw model output (may contain markdown fences
  /// or extra text around the JSON). [candidates] is the original
  /// distance-ranked list the prompt was built from.
  static List<RankedShelter>? parseResponse(
    String response,
    List<RankedShelter> candidates,
  ) {
    final indices = _extractIndices(response);
    if (indices == null) return null;

    // Validate: every index must be in range, and the reordered set
    // must cover all candidates exactly once (no duplicates, no gaps).
    if (indices.length != candidates.length) return null;
    final seen = <int>{};
    for (final i in indices) {
      if (i < 0 || i >= candidates.length) return null;
      if (!seen.add(i)) return null; // duplicate
    }

    // Build the reordered list.
    return indices.map((i) => candidates[i]).toList();
  }

  /// Extracts a permutation of ints from the model's raw response.
  ///
  /// Handles markdown code fences (```json … ```) and free-form text
  /// around the array. Uses `dart:convert` for robust parsing — the
  /// old hand-rolled splitter couldn't handle strings-with-commas or
  /// nested arrays, and the old greedy regex `\[[\s\S]*\]` would span
  /// from the first `[` to the LAST `]` if the model emitted two
  /// arrays, producing garbage.
  static List<int>? _extractIndices(String response) {
    if (response.trim().isEmpty) return null;
    // Strip markdown code fences (```json / ```) so the body parses.
    final cleaned =
        response.replaceAll(RegExp(r'```(?:json)?'), '').trim();

    // 1. Try the whole response as JSON first.
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        final list = _toIntList(decoded);
        if (list != null) return list;
      }
    } catch (_) {
      // Not a standalone JSON document — fall through to extraction.
    }

    // 2. Extract the FIRST JSON array (non-greedy, so a second array
    //    later in the response can't extend the match).
    final arrayMatch = RegExp(r'\[[\s\S]*?\]').firstMatch(cleaned);
    if (arrayMatch == null) return null;
    try {
      final decoded = jsonDecode(arrayMatch.group(0)!);
      if (decoded is List) return _toIntList(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Coerces a decoded JSON list to a list of ints, rejecting any
  /// non-numeric entry entirely (the caller validates the permutation).
  static List<int>? _toIntList(List<dynamic> decoded) {
    final out = <int>[];
    for (final d in decoded) {
      if (d is int) {
        out.add(d);
      } else if (d is num) {
        out.add(d.toInt());
      } else {
        // A string, bool, nested list, or map → not a valid index set.
        return null;
      }
    }
    return out;
  }
}
