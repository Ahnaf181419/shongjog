/// Semantic search intent classifier (Option 4 in docs/AI-MAP-FEATURES.md).
///
/// Takes a free-form Bangla/English query from the map search bar and
/// classifies it into one of three structured intents:
///
/// - [SearchIntent.shelterFilter] — the user wants to filter the
///   existing shelter layer (e.g. "সাইক্লোন শেল্টার", "shelter").
///   Works offline.
/// - [SearchIntent.geocode] — the user named a place (e.g. "ঢাকা
///   মেডিকেল কলেজ") that needs geocoding via Nominatim. Online only.
/// - [SearchIntent.poiQuery] — the user is looking for a type of
///   facility (e.g. "হাসপাতাল", "pharmacy") that needs an Overpass
///   POI query. Online only.
///
/// The classification is pure keyword heuristics — no model call
/// needed for the common cases, keeping it fast and offline-capable.
/// The model can be added later for ambiguous queries if needed.
enum SearchIntent { shelterFilter, geocode, poiQuery }

/// The result of classifying a search query.
class SemanticSearchResult {
  final SearchIntent intent;
  final String query;
  final String? poiTag;
  const SemanticSearchResult({
    required this.intent,
    required this.query,
    this.poiTag,
  });
}

class SemanticSearchService {
  SemanticSearchService._();

  /// Keywords that signal a POI (point-of-interest) search. Maps to
  /// Overpass amenity tags.
  static const _poiKeywords = <String, String>{
    'হাসপাতাল': 'hospital',
    'হসপিটাল': 'hospital',
    'ক্লিনিক': 'clinic',
    'ফার্মেসি': 'pharmacy',
    'প্রেসক্রিপশন': 'pharmacy',
    'পুলিশ': 'police',
    'থানা': 'police',
    'ফায়ার': 'fire_station',
    'অগ্নিনির্বাপণ': 'fire_station',
    'hospital': 'hospital',
    'clinic': 'clinic',
    'pharmacy': 'pharmacy',
    'police': 'police',
    'fire': 'fire_station',
  };

  /// Keywords that signal a shelter-filter intent.
  static const _shelterKeywords = [
    'শেল্টার', 'আশ্রয়', 'সাইক্লোন', 'ঘূর্ণিঝড়', 'জলোচ্ছ্বাস',
    'shelter', 'cyclone', 'storm',
  ];

  /// Classify a raw query into a structured intent.
  static SemanticSearchResult classify(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) {
      return const SemanticSearchResult(
          intent: SearchIntent.shelterFilter, query: '');
    }

    // Check POI first — if the query mentions a hospital/pharmacy/etc,
    // it's a POI search even if it also mentions shelters.
    for (final entry in _poiKeywords.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return SemanticSearchResult(
          intent: SearchIntent.poiQuery,
          query: query,
          poiTag: entry.value,
        );
      }
    }

    // Check shelter filter.
    for (final kw in _shelterKeywords) {
      if (lower.contains(kw.toLowerCase())) {
        return SemanticSearchResult(
          intent: SearchIntent.shelterFilter,
          query: query,
        );
      }
    }

    // Default: treat as a geocode (place name) search.
    return SemanticSearchResult(
      intent: SearchIntent.geocode,
      query: query,
    );
  }
}
