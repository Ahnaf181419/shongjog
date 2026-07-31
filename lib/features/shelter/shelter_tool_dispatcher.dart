import 'nearest_shelter.dart';
import 'shelter_model.dart';

/// Pure-Dart executor for the `find_nearest_shelter` tool call.
///
/// The model emits a tool call with optional arguments (just `count`
/// for now). This class:
///   1. Extracts the args from the raw JSON envelope flutter_gemma
///      emits (two shapes: flat `{name, arguments}` or nested under
///      `tool_calls[].function`).
///   2. Runs the existing `nearestShelters()` haversine ranker over
///      the bundled shelter list + the user's GPS.
///
/// Everything here is pure Dart and unit-testable without a device.
class ShelterToolDispatcher {
  /// Tool name this dispatcher recognises.
  static const toolName = 'find_nearest_shelter';

  /// Default number of shelters to return when `count` is missing or
  /// unparseable. Mirrors the search panel default.
  static const _defaultCount = 3;

  /// Hard cap to prevent the model from asking for an unreasonable
  /// number (e.g. `count: 9999`) and flooding the chat bubble.
  static const _maxCount = 10;

  /// Run the tool. Returns the ranked shelters sorted by distance.
  ///
  /// [args] is the parsed arguments map extracted by
  /// [extractArgsFromJson]. [userLat] / [userLon] are the user's GPS
  /// (or a fallback). [shelters] is the full bundled list.
  static List<RankedShelter> dispatch({
    required Map<String, dynamic> args,
    required double userLat,
    required double userLon,
    required List<Shelter> shelters,
  }) {
    if (shelters.isEmpty) return const [];
    final count = _parseCount(args) ?? _defaultCount;
    final effective = count.clamp(1, _maxCount);
    return nearestShelters(
      lat: userLat,
      lon: userLon,
      all: shelters,
      k: effective,
    );
  }

  /// Extract the arguments map from the raw JSON envelope emitted by
  /// flutter_gemma when the model makes a tool call. Returns null if
  /// the envelope doesn't contain our tool.
  ///
  /// Handles both shapes:
  ///   - flat: `{"name": "find_nearest_shelter", "arguments": {...}}`
  ///   - nested: `{"tool_calls": [{"function": {"name": ..., "arguments": ...}}]}`
  static Map<String, dynamic>? extractArgsFromJson(Map<String, dynamic> json) {
    // Flat shape.
    final name = json['name'] as String?;
    if (name == toolName) {
      final args = json['arguments'];
      if (args is Map<String, dynamic>) return args;
      return const {};
    }

    // Nested shape (OpenAI-style tool_calls array).
    final toolCalls = json['tool_calls'];
    if (toolCalls is List) {
      for (final tc in toolCalls) {
        if (tc is Map<String, dynamic>) {
          final fn = tc['function'];
          if (fn is Map<String, dynamic> && fn['name'] == toolName) {
            final args = fn['arguments'];
            if (args is Map<String, dynamic>) return args;
            return const {};
          }
        }
      }
    }

    return null;
  }

  /// Quick check: does this JSON envelope contain a shelter tool call?
  static bool isShelterToolCall(Map<String, dynamic> json) {
    if (json['name'] == toolName) return true;
    final toolCalls = json['tool_calls'];
    if (toolCalls is List) {
      for (final tc in toolCalls) {
        if (tc is Map<String, dynamic>) {
          final fn = tc['function'];
          if (fn is Map<String, dynamic> && fn['name'] == toolName) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static int? _parseCount(Map<String, dynamic> args) {
    final raw = args['count'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Digits in both scripts, plus the small Bangla/English number words a
  /// user would realistically type when asking for shelters.
  static const _numberWords = <String, int>{
    'এক': 1, 'একটা': 1, 'একটি': 1,
    'দুই': 2, 'দুটি': 2, 'দুটো': 2, 'দু': 2,
    'তিন': 3, 'তিনটি': 3, 'তিনটা': 3,
    'চার': 4, 'চারটি': 4, 'চারটা': 4,
    'পাঁচ': 5, 'পাঁচটি': 5, 'পাঁচটা': 5,
    'ছয়': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  };

  /// How many shelters the user asked for, read straight from [query].
  ///
  /// **Why this exists.** The chat repository used to spend an entire
  /// on-device generation — load the model, open a session, run inference,
  /// close it — purely to have the model emit a `find_nearest_shelter` tool
  /// call whose *only* payload the dispatcher reads is this integer.
  /// [ShelterIntentDetector] had already decided the query was
  /// shelter-shaped, and everything that actually answers it (the haversine
  /// ranker, the Bangla formatter) is pure Dart. Worse, when the model
  /// answered in prose instead of a tool call the repository fell through
  /// and generated a *second* time — two full inferences, 30–50s on a
  /// mid-range phone, for a number a regex finds instantly.
  ///
  /// Returns null when the query names no count, which makes [dispatch] use
  /// its default of 3 — the same behaviour as an omitted tool argument.
  static int? parseRequestedCount(String query) {
    // Bangla digits (০-৯) map onto ASCII by codepoint offset.
    final normalized = String.fromCharCodes(query.runes.map(
        (r) => (r >= 0x09E6 && r <= 0x09EF) ? r - 0x09E6 + 0x30 : r));

    final digits = RegExp(r'\d+').firstMatch(normalized);
    if (digits != null) {
      final n = int.tryParse(digits.group(0)!);
      // Ignore incidental numbers that cannot be a shelter count, so
      // "১০ নম্বর ওয়ার্ডের আশ্রয়কেন্দ্র" doesn't silently become a
      // request for ten shelters... but 10 itself is a legal count, so
      // only reject what is out of range outright.
      if (n != null && n >= 1 && n <= _maxCount) return n;
    }

    final lower = normalized.toLowerCase();
    for (final entry in _numberWords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
