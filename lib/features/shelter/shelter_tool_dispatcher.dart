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
}
