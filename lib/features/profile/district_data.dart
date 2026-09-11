/// District lists now live in `assets/data/districts.json` (bilingual).
///
/// Call sites must `await loadDistricts(locale.languageCode)` to fetch
/// the bundle for the active locale — see `districts_loader.dart`.
library;

export 'districts_loader.dart';
