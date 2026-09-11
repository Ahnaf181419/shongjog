// Quick-card entries now live in assets/data/cards.json (bn+en) and are
// loaded through `cards_loader.dart`. This file used to hold a hand-written
// 25-card list; it now re-exports the loader's typed shape so callers can
// be migrated incrementally.

import 'cards_loader.dart' show QuickCardEntry, loadQuickCards;

export 'cards_loader.dart' show QuickCardEntry, loadQuickCards;

/// Synchronous accessor — caches the result of the most recent async load.
/// Set by [ensureQuickCardsLoaded] before the first build that needs cards.
List<QuickCardEntry>? _loaded;

Future<void> ensureQuickCardsLoaded(String? locale) async {
  final list = await loadQuickCards(locale);
  _loaded = list;
}

/// Synchronous accessor — valid only after [ensureQuickCardsLoaded] has
/// been awaited.
List<QuickCardEntry> cachedQuickCards() {
  final l = _loaded;
  if (l == null) {
    throw StateError(
      'Call ensureQuickCardsLoaded(locale) before cachedQuickCards().',
    );
  }
  return l;
}

void debugSetCardsForTest(List<QuickCardEntry> entries) {
  _loaded = entries;
}
