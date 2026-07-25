/// Pure-Dart detector for shelter-search intent in a chat query.
///
/// Used by [ChatRepository] to decide whether a user message is asking
/// for nearby shelters — if so, the repository routes through the
/// function-calling tool path instead of (or in addition to) the
/// generic RAG prompt. This is a fast keyword gate; the model still
/// does the final structured extraction via the tool call.
class ShelterIntentDetector {
  ShelterIntentDetector._();

  /// Bangla + English keywords that signal a shelter-search intent.
  static const _keywords = [
    // Bangla
    'শেল্টার', 'শেল্টারে', 'আশ্রয়', 'আশ্রয়কেন্দ্র', 'আশ্রয়ে',
    'নিকটস্থ', 'কাছে', 'কোথায়', 'কোন', 'নিরাপদ', 'গিয়ে',
    'ঘূর্ণিঝড়', 'জলোচ্ছ্বাস', 'বন্যা',
    // English / Banglish
    'shelter', 'nearest', 'closest', 'safe place', 'cyclone',
  ];

  /// Negation words that flip an affirmative match to a non-shelter query.
  /// E.g. "শেল্টার নেই" (there is no shelter) is still a shelter query,
  /// but we keep this list small to avoid over-filtering.
  static const _negations = <String>[];

  /// Returns true if [query] looks like a request for shelter info.
  static bool isShelterQuery(String query) {
    final lower = query.toLowerCase();
    for (final kw in _keywords) {
      if (lower.contains(kw.toLowerCase())) {
        // Check negations — if any negation is present, skip.
        var negated = false;
        for (final neg in _negations) {
          if (lower.contains(neg)) {
            negated = true;
            break;
          }
        }
        if (!negated) return true;
      }
    }
    return false;
  }
}
