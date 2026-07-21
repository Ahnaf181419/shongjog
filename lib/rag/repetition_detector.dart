/// Pure-Dart repetition detector for streaming LLM token output.
///
/// The on-device Gemma 4 E2B model (via LiteRT-LM) has no
/// `repetitionPenalty` / `presencePenalty` knob in the flutter_gemma
/// 1.3.0 SDK, and no `stopStrings` API on the `.litertlm` path. When
/// the model falls into a degenerate loop (repeating a token, short
/// phrase, or emitting "long random same texts"), the SDK will happily
/// generate `maxOutputTokens` tokens of garbage. The user sees the full
/// garbage pile because `getResponse()` blocks until the cap.
///
/// This detector consumes the token stream from `getResponseAsync()`
/// and signals [shouldStop] the moment a repetition pattern is
/// recognised. The caller then invokes `session.stopGeneration()` to
/// kill native decoding immediately, and keeps whatever clean prefix
/// accumulated before the loop.
///
/// Design: stateful, append-only. Feed tokens via [feed]; read
/// [shouldStop] after each feed. Three independent heuristics, any
/// of which fires [shouldStop]:
///
/// 1. **Exact n-gram repeat.** The last `window` characters end with
///    a 2- to 8-token phrase that just appeared moments earlier.
///    This is the classic Gemma repetition loop: "আমি আমি আমি আমি".
/// 2. **Single-token stall.** The same short token (≤ 4 chars) was
///    emitted `stallLimit` times in a row. Catches "। । । ।" and
///    "the the the the".
/// 3. **Vocabulary collapse.** In the last `window` characters, the
///    number of *distinct* tokens falls below `minDistinctRatio` of
///    total tokens. Catches the "long random same texts" symptom
///    where the model cycles through a tiny vocabulary.
class RepetitionDetector {
  RepetitionDetector({
    this.window = 120,
    this.stallLimit = 5,
    this.minDistinctRatio = 0.40,
    this.minTokensBeforeCheck = 12,
  });

  /// Size of the rolling character window we inspect. 120 chars ≈
  /// 20–40 Bangla tokens — enough to see a loop without firing on
  /// legitimate repetition (e.g. "৯৯৯" in an emergency answer).
  final int window;

  /// If the same short token appears this many times consecutively,
  /// stop. 5 is conservative — a real answer rarely repeats a 1–4
  /// char token 5× in a row.
  final int stallLimit;

  /// Minimum ratio of distinct tokens to total tokens in the window.
  /// 0.40 means: if the last `window` chars have fewer than 40%
  /// unique whitespace-split tokens, we consider it vocabulary
  /// collapse and stop.
  final double minDistinctRatio;

  /// Don't run any heuristic until at least this many characters
  /// have been generated. Prevents false positives on short,
  /// legitimately-repetitive openings ("হ্যাঁ, হ্যাঁ").
  final int minTokensBeforeCheck;

  final StringBuffer _buf = StringBuffer();
  bool _stopped = false;

  /// True once any heuristic has fired. Sticky — once stopped, always
  /// stopped. The caller should call `session.stopGeneration()` and
  /// stop feeding.
  bool get shouldStop => _stopped;

  /// Current clean prefix — everything accumulated so far. After
  /// [shouldStop] fires, this is the trimmed good output.
  String get buffer => _buf.toString();

  /// Append a generated [chunk] and run the heuristics. Safe to call
  /// after [shouldStop] (no-op).
  void feed(String chunk) {
    if (_stopped || chunk.isEmpty) return;
    _buf.write(chunk);
    final text = _buf.toString();
    if (text.length < minTokensBeforeCheck) return;
    _runHeuristics(text);
  }

  void _runHeuristics(String text) {
    final tail = text.length > window ? text.substring(text.length - window) : text;

    // Tokenise once; every heuristic below reuses this list.
    final tokens = tail.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // 1. Single-token stall on short tokens. Walk the trailing run of
    //    identical short tokens; if the run length crosses stallLimit
    //    we stop. This handles both streaming (one token per feed)
    //    and batch (many tokens in one feed).
    var runLen = 0;
    String? runTok;
    for (var i = tokens.length - 1; i >= 0; i--) {
      final t = tokens[i];
      if (t.length <= 4) {
        if (runTok == null) {
          runTok = t;
          runLen = 1;
        } else if (t == runTok) {
          runLen++;
        } else {
          break;
        }
      } else {
        break;
      }
      if (runLen >= stallLimit) {
        _stopped = true;
        return;
      }
    }

    // 2. Vocabulary collapse in the window.
    if (tokens.length >= 8) {
      final distinct = tokens.toSet().length;
      final ratio = distinct / tokens.length;
      if (ratio < minDistinctRatio) {
        _stopped = true;
        return;
      }
    }

    // 3. Exact n-gram repeat: look for a 2–6 token phrase that repeats
    //    back-to-back. "foo bar foo bar" or "আমি যাচ্ছি আমি যাচ্ছি".
    if (_hasRepeatingNgram(tokens)) {
      _stopped = true;
      return;
    }
  }

  /// True if any 2–6 token phrase appears twice in immediate succession.
  /// "a b a b" → n=2 matches. "x y z x y z" → n=3 matches.
  static bool _hasRepeatingNgram(List<String> tokens) {
    for (var n = 2; n <= 6; n++) {
      if (tokens.length < n * 2) continue;
      // Inspect only the tail-most boundary: does the last n-token
      // phrase equal the n-token phrase immediately before it?
      final i = tokens.length - n;
      final a = tokens.sublist(i - n, i);
      final b = tokens.sublist(i, i + n);
      if (!_tokensEqual(a, b)) continue;

      // Found a back-to-back repeat. Confirm it's not a legitimate
      // emphasis (e.g. "হ্যাঁ হ্যাঁ") by requiring either n >= 3 OR
      // the same phrase to appear a third time earlier.
      if (n >= 3) return true;
      final before = i - n * 2;
      if (before >= 0) {
        final c = tokens.sublist(before, before + n);
        if (_tokensEqual(c, a)) return true;
      }
      // n == 2 with only a double repeat is ambiguous; don't fire.
    }
    return false;
  }

  static bool _tokensEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Trim trailing partial-repetition from [buffer]. After [shouldStop]
  /// fires the buffer may still contain the first instance of the
  /// repeating phrase (e.g. one "আমি" before the loop). Caller may
  /// want to keep it or trim it; this helper trims conservatively.
  String trimmed() {
    var out = buffer.trimRight();
    if (out.isEmpty) return out;
    // If the last ~20 chars contain a repeated short token, chop back
    // to before the first occurrence of that token in the tail.
    final tail = out.length > 20 ? out.substring(out.length - 20) : out;
    final m = RegExp(r'(\S{1,12})(\s+\1){2,}$').firstMatch(tail);
    if (m != null) {
      out = out.substring(0, out.length - (tail.length - m.start)).trimRight();
    }
    return out;
  }
}
