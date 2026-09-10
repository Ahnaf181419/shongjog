import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/data/districts.json';

Future<Map<String, List<String>>> loadDistricts(String? activeLocale) {
  return TextLoader.loadJson<Map<String, List<String>>>(
    _kAssetPath,
    (raw, locale) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      final block = TextLoader.pickBundle(outer, activeLocale);
      return block.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    },
  );
}
