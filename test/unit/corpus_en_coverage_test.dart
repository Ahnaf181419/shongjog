import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('corpus bilingual coverage', () {
    final corpusPath = 'assets/data/corpus.json';
    final data = jsonDecode(File(corpusPath).readAsStringSync())
        as List<dynamic>;

    test('every corpus chunk has non-empty text_en', () {
      final missing = <String>[];
      for (final r in data) {
        final m = r as Map<String, dynamic>;
        if ((m['text_en'] as String).trim().isEmpty) {
          missing.add(m['id'] as String);
        }
      }
      expect(missing, isEmpty,
          reason: 'Chunks missing text_en (would degrade English retrieval): '
              '${missing.join(', ')}');
    });

    test('every corpus chunk has at least 3 keywords_en', () {
      final shortKw = <String>[];
      for (final r in data) {
        final m = r as Map<String, dynamic>;
        final kws = (m['keywords_en'] as List?) ?? const [];
        if (kws.length < 3) {
          shortKw.add(m['id'] as String);
        }
      }
      expect(shortKw, isEmpty,
          reason: 'Chunks with fewer than 3 keywords_en: '
              '${shortKw.join(', ')}');
    });

    test('text_en is a non-trivial translation (>= 30 chars)', () {
      // Guard against accidental reverts to placeholder strings.
      final shortEn = <String>[];
      for (final r in data) {
        final m = r as Map<String, dynamic>;
        final en = (m['text_en'] as String).trim();
        if (en.length < 30) {
          shortEn.add('${m['id']} (${en.length} chars)');
        }
      }
      expect(shortEn, isEmpty,
          reason: 'text_en suspiciously short:\n  ${shortEn.join('\n  ')}');
    });
  });
}
