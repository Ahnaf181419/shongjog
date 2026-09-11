import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

/// Shared async JSON loader for content assets and LLM prompts.
///
/// All content assets under `assets/data/*.json` and `assets/prompts/*.json`
/// are loaded through this. The first read materialises the asset and caches
/// the *raw* string keyed by asset path. The parser is locale-aware — it
/// receives the raw string AND the active locale and resolves the right
/// bn|en block. Subsequent calls with the same locale return the cached
/// parsed value; with a different locale, the parser runs again. This means
/// the cache is per-path-per-locale — bn and en blocks coexist.
///
/// Prompts in `assets/prompts/*.json` use the bilingual shape
/// `{"bn": {...}, "en": {...}}`. [pickBundle] returns the right block for
/// the active locale, with `bn` as the fallback (matches the project's
/// default locale in [LocaleController]).
abstract final class TextLoader {
  static final Map<String, String> _rawCache = <String, String>{};
  static final Map<String, Future<String>> _inFlightRaw =
      <String, Future<String>>{};
  static final Map<String, Object?> _parsedCache = <String, Object?>{};

  /// Load and parse a JSON asset, with a locale-aware typed parser.
  ///
  /// [parseRaw] receives the raw UTF-8 string and the active locale tag, and
  /// must return the typed value. The parsed result is cached per
  /// `(assetPath, locale)` so a different locale re-parses from the same
  /// raw payload — saving the asset read.
  static Future<T> loadJson<T>(
    String assetPath,
    T Function(String raw, String? locale) parseRaw, {
    String? locale,
  }) async {
    final cacheKey = _cacheKey(assetPath, locale);
    final cached = _parsedCache[cacheKey];
    if (cached != null) {
      return cached as T;
    }
    final raw = await _loadRaw(assetPath);
    final parsed = parseRaw(raw, locale);
    _parsedCache[cacheKey] = parsed;
    return parsed;
  }

  static Future<String> _loadRaw(String assetPath) async {
    final cached = _rawCache[assetPath];
    if (cached != null) return cached;
    final inFlight = _inFlightRaw[assetPath];
    if (inFlight != null) return inFlight;
    final completer = rootBundle.loadString(assetPath);
    _inFlightRaw[assetPath] = completer;
    try {
      final raw = await completer;
      _rawCache[assetPath] = raw;
      return raw;
    } finally {
      _inFlightRaw.remove(assetPath);
    }
  }

  static String _cacheKey(String path, String? locale) =>
      '$path::${localeFor(locale)}';

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
    _rawCache.clear();
    _parsedCache.clear();
  }
}
