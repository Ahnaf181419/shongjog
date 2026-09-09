import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

/// Shared async JSON loader for content assets and LLM prompts.
///
/// All content assets under `assets/data/*.json` and `assets/prompts/*.json`
/// are loaded through this. The first read materialises the asset and caches
/// the *parsed* result keyed by asset path. Concurrent callers share the same
/// Future via an in-flight map — so a second call while the first is still
/// loading returns the same parsed object.
///
/// Prompts in `assets/prompts/*.json` use the bilingual shape
/// `{"bn": {...}, "en": {...}}`. [pickBundle] returns the right block for
/// the active locale, with `bn` as the fallback (matches the project's
/// default locale in [LocaleController]).
abstract final class TextLoader {
  static final Map<String, Object?> _cache = <String, Object?>{};
  static final Map<String, Future<Object?>> _inFlight =
      <String, Future<Object?>>{};

  /// Load and parse a JSON asset, with a typed parser.
  ///
  /// [parseRaw] receives the raw UTF-8 string and must return the typed value.
  /// Same parser function MUST be used for the same path — the cache stores
  /// the parser's return type, so a different parser for the same path will
  /// fail at the cast site.
  static Future<T> loadJson<T>(
    String assetPath,
    T Function(String raw) parseRaw,
  ) async {
    final cached = _cache[assetPath];
    if (cached != null) {
      return cached as T;
    }
    final inFlight = _inFlight[assetPath];
    if (inFlight != null) {
      return inFlight as Future<T>;
    }
    final completer = _doLoad<T>(assetPath, parseRaw);
    _inFlight[assetPath] = completer;
    try {
      final value = await completer;
      _cache[assetPath] = value;
      return value;
    } finally {
      _inFlight.remove(assetPath);
    }
  }

  static Future<T> _doLoad<T>(
    String assetPath,
    T Function(String) parseRaw,
  ) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseRaw(raw);
  }

  /// Coerce a language tag (case-insensitive) to one of `bn` | `en`.
  /// Returns `bn` for anything unrecognised, including `null`.
  static String localeFor(String? languageTag) {
    final tag = (languageTag ?? '').toLowerCase();
    if (tag.startsWith('bn')) return 'bn';
    if (tag.startsWith('en')) return 'en';
    return 'bn';
  }

  /// Pick the bn|en block out of a bilingual content bundle.
  ///
  /// Returns the `en` block if [activeLocale] is `en` AND the `en` block is
  /// present; otherwise returns the `bn` block. Falls through to whichever
  /// block exists last as a final defensive default.
  static Map<String, dynamic> pickBundle(
    Map<String, dynamic> bundle,
    String? activeLocale,
  ) {
    final key = localeFor(activeLocale);
    final bn = bundle['bn'];
    final en = bundle['en'];
    if (key == 'en' && en is Map<String, dynamic>) return en;
    if (bn is Map<String, dynamic>) return bn;
    if (en is Map<String, dynamic>) return en;
    throw StateError('Bundle has neither bn nor en block: $bundle');
  }

  /// For tests — drop the parsed cache so the next `loadJson` re-reads.
  static void debugClearCache() {
    _cache.clear();
  }
}
