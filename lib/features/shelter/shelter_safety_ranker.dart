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
    // Extract the JSON array from the response. The model often wraps
    // it in ```json fences or adds explanation text.
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
    if (arrayMatch == null) return null;
    final arrayStr = arrayMatch.group(0)!;

    // Parse the indices.
    final List<dynamic> decoded;
    try {
      decoded = _jsonDecode(arrayStr) as List<dynamic>;
    } catch (_) {
      return null;
    }

    // Convert to ints, skip non-int entries.
    final indices = <int>[];
    for (final d in decoded) {
      if (d is int) {
        indices.add(d);
      } else if (d is num) {
        indices.add(d.toInt());
      }
    }

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

  /// Lightweight JSON decode — avoids importing dart:convert at the
  /// top level so this file stays dependency-free for unit tests.
  static dynamic _jsonDecode(String s) {
    return _decoder.convert(s);
  }

  static final _decoder = _LiteJsonDecoder();
}

/// Minimal JSON decoder for the ranker's needs: handles arrays of ints
/// and whitespace. We don't pull in dart:convert to keep this file
/// pure-Dart-testable without any platform imports.
class _LiteJsonDecoder {
  dynamic convert(String s) {
    final trimmed = s.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      throw FormatException('Not a JSON array');
    }
    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    if (inner.isEmpty) return <dynamic>[];
    return inner
        .split(',')
        .map((e) => e.trim())
        .map((e) => int.tryParse(e) ?? (num.tryParse(e) ?? e))
        .toList();
  }
}
