import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/data/districts.json';

Future<Map<String, List<String>>> loadDistricts(String? activeLocale) async {
  // We always load BOTH blocks so callers can resolve a canonical id to
  // the display name in any locale. TextLoader caches the raw asset
  // string per-locale; the bundle is small (<5 KB).
  final bn = await TextLoader.loadJson<Map<String, List<String>>>(
    _kAssetPath,
    (raw, _) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      final block = outer['bn'] as Map<String, dynamic>;
      return block.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    },
    locale: 'bn',
  );
  final en = await TextLoader.loadJson<Map<String, List<String>>>(
    _kAssetPath,
    (raw, _) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      final block = outer['en'] as Map<String, dynamic>;
      return block.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    },
    locale: 'en',
  );
  // Also touch the cache with the user's active locale so screen reads
  // are instant on the next getBundle() call.
  if (activeLocale != null && activeLocale != 'bn' && activeLocale != 'en') {
    await TextLoader.loadJson<Map<String, List<String>>>(
      _kAssetPath,
      (raw, _) {
        final outer = jsonDecode(raw) as Map<String, dynamic>;
        final block = TextLoader.pickBundle(outer, activeLocale);
        return block.map(
          (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
        );
      },
      locale: activeLocale,
    );
  }
  // Return the active locale's bundle for back-compat callers.
  final code = (activeLocale ?? 'bn').toLowerCase();
  if (code.startsWith('en')) return en;
  return bn;
}

/// Build a canonical, locale-independent id for a division/district pair.
/// Format: `__district_<divIndex>_<distIndex>`. The bn and en blocks have
/// the same number of divisions and matching district counts per index, so
/// the position pair resolves identically in both locales.
String districtCanonicalId(Map<String, List<String>> bnBlock, String division, String district) {
  final divisions = bnBlock.keys.toList();
  final divIdx = divisions.indexOf(division);
  if (divIdx < 0) return '';
  final distIdx = bnBlock[division]!.indexOf(district);
  if (distIdx < 0) return '';
  return '__district_${divIdx}_$distIdx';
}

/// Reverse a canonical id back to (bnDivisionName, bnDistrictName). Returns
/// null if the id is malformed or the block shape has changed.
({String division, String district})? districtFromCanonicalId(
    Map<String, List<String>> bnBlock, String id) {
  if (!id.startsWith('__district_')) return null;
  final rest = id.substring('__district_'.length);
  final parts = rest.split('_');
  if (parts.length != 2) return null;
  final divIdx = int.tryParse(parts[0]);
  final distIdx = int.tryParse(parts[1]);
  if (divIdx == null || distIdx == null) return null;
  final divisions = bnBlock.keys.toList();
  if (divIdx < 0 || divIdx >= divisions.length) return null;
  final division = divisions[divIdx];
  final districts = bnBlock[division]!;
  if (distIdx < 0 || distIdx >= districts.length) return null;
  return (division: division, district: districts[distIdx]);
}
