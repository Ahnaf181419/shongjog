import 'dart:async';

import '../core/locale_controller.dart';
import '../features/damage_scanner/damage_scan_strings_loader.dart';
import '../features/intelligence/situation_summary_strings_loader.dart';
import '../features/planner/kit_strings_loader.dart';
import '../features/planner/planner_strings_loader.dart';
import '../features/planner/risk_strings_loader.dart';
import '../features/profile/districts_loader.dart';
import '../features/quick_cards/cards_data.dart';
import '../features/shelter/shelter_strings_loader.dart';
import '../rag/rumour_strings_loader.dart';

/// Primes all locale-dependent asset-backed caches and re-primes them
/// whenever the user switches language.
///
/// Six prompt-string caches (`cachedKit/Planner/Risk/Shelter/DamageScan/
/// SituationSummary`) previously defaulted to `_empty()` in production —
/// every prompt-builder consumer fell back to blank templates. This
/// warmer loads them at startup (after the persisted locale has been
/// restored) and re-loads them on every `localeController` change.
///
/// Quick Cards and districts are warmed here too so the locale change
/// listener is the single point of truth.
class PromptCacheWarmer {
  PromptCacheWarmer(this._localeController);

  final LocaleController _localeController;
  bool _started = false;
  bool _initialPrimed = false;
  int _inflightToken = 0;

  /// Called from `main()` after [LocaleController.ensureLoaded].
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _localeController.ensureLoaded();
    await _primeAll();
    _initialPrimed = true;
    _localeController.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (!_initialPrimed) return;
    // Fire-and-forget: each loader is per-locale cached by TextLoader, so
    // re-priming after the first time is cheap (no raw asset re-parse).
    unawaited(_primeAll());
  }

  Future<void> _primeAll() async {
    final token = ++_inflightToken;
    final locale = _localeController.languageCode;

    Future<void> one(Future<void> Function() load) async {
      try {
        await load();
      } catch (_) {
        // Best-effort priming — empty caches are no worse than today's
        // shipped behavior. Test paths stub setUpAll().
      }
    }

    await Future.wait<void>([
      one(() async => cachedKit = await loadKitStrings(locale)),
      one(() async => cachedPlanner = await loadPlannerStrings(locale)),
      one(() async => cachedRisk = await loadRiskStrings(locale)),
      one(() async => cachedShelter = await loadShelterStrings(locale)),
      one(() async => cachedDamageScan = await loadDamageScanStrings(locale)),
      one(
        () async =>
            cachedSituationSummary = await loadSituationSummaryStrings(locale),
      ),
      one(() async => cachedRumour = await loadRumourStrings(locale)),
      one(() async => await loadDistricts(locale)),
      one(() async => await ensureQuickCardsLoaded(locale)),
    ]);

    // Only honor the latest call.
    if (token != _inflightToken) return;
  }
}
