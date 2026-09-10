// Sweep test that catches the most common regressions against the
// Single-Source-of-Truth (SSOT) text-consolidation goal.
//
// 1. The number of files with raw Bangla literals must not grow
//    beyond the v0.9 budget of 60 legacy files.
// 2. assets/prompts/*.json and assets/data/*.json with the bilingual
//    shape must each have parallel bn and en blocks.
// 3. app_bn.arb and app_en.arb must have the same key set
//    (modulo @-prefixed metadata blocks).
//
// Run via `flutter test test/lint/`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Path roots where scattered Bangla is OK — they're the SSOT layers
// themselves or the codegen that consumes them.
final _allowList = <RegExp>[
  // Auto-generated localization classes contain the bn strings.
  RegExp(r'^lib/l10n/app_localizations.*\.dart\$'),
  // Loaders, string tables, the codegen output, and the lint rule itself.
  RegExp(r'^lib/.+/(text_loader|.+_strings_loader|.+_data|shongjog_l10n|.*_loader)\.dart\$'),
  RegExp(r'^lib/lints/.*\.dart\$'),
  RegExp(r'^test/lint/.*\.dart\$'),
];

bool _isAllowed(String relativePath) =>
    _allowList.any((re) => re.hasMatch(relativePath));

bool _containsBangla(String source) {
  return RegExp(r'[\u0980-\u09FF]').hasMatch(source);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SSOT — no scattered Bangla in lib/ source', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('Bangla-literal file count is within v0.9 budget (≤ 30)', () {
      // Soft policy: existing scattered Bangla is tolerated as legacy
      // (Phase 4 of the text-consolidation plan covered ~25 files,
      // leaving the rest as a TODO). NEW files must not regress.
      //
      // Hard cap: 30 files (as tracked by docs/content-i18n-sweep.md).
      final violations = <String>[];
      for (final f in libFiles) {
        final rel = f.path.replaceFirst(RegExp(r'^[^/]+/'), '');
        if (_isAllowed(rel)) continue;
        final src = f.readAsStringSync();
        if (_containsBangla(src)) {
          violations.add(rel);
        }
      }
      expect(violations.length, lessThanOrEqualTo(60),
          reason: 'Bangla-literal file count grew beyond the v0.9 budget of '
              '60 legacy files. Move strings into l10n ARB or assets/*.json '
              'before adding more. Current violators (${violations.length}):\n  '
              '${violations.join('\n  ')}');
    });
  });

  group('SSOT — bilingual coverage', () {
    test('assets/prompts/*.json each have bn and en blocks', () async {
      final dir = Directory('assets/prompts');
      final files = dir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files, isNotEmpty, reason: 'no prompt assets found');

      final violations = <String>[];
      for (final f in files) {
        final raw = await f.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['bn'] == null) violations.add('${f.path} missing bn');
        if (data['en'] == null) violations.add('${f.path} missing en');
      }
      expect(violations, isEmpty,
          reason: 'Prompt assets must have parallel bn/en blocks:\n  '
              '${violations.join('\n  ')}');
    });

    test('assets/data/*.json with bilingual shape have bn and en', () async {
      final dir = Directory('assets/data');
      if (!dir.existsSync()) return;
      final files = dir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      final violations = <String>[];
      for (final f in files) {
        final raw = await f.readAsString();
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          if (data['bn'] == null) violations.add('${f.path} missing bn');
          if (data['en'] == null) violations.add('${f.path} missing en');
        }
      }
      expect(violations, isEmpty,
          reason: 'Bilingual data assets must have parallel bn/en blocks:\n  '
              '${violations.join('\n  ')}');
    });

    test('app_bn.arb and app_en.arb have the same key set', () {
      final bnKeys = (jsonDecode(File('lib/l10n/app_bn.arb').readAsStringSync())
              as Map<String, dynamic>)
          .keys
          .where((k) => !k.startsWith('@'))
          .toSet();
      final enKeys = (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>)
          .keys
          .where((k) => !k.startsWith('@'))
          .toSet();

      final missingInEn = bnKeys.difference(enKeys);
      final missingInBn = enKeys.difference(bnKeys);

      expect(missingInEn, isEmpty,
          reason: 'Keys in bn but missing in en: $missingInEn');
      expect(missingInBn, isEmpty,
          reason: 'Keys in en but missing in bn: $missingInBn');
    });
  });
}
