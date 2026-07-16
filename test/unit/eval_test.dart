import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates eval/test_set.json — ensures 50 queries across 5 categories
/// with all required fields. This is the "test the test" guard.
///
/// Reads from the filesystem (not rootBundle) because eval/ is not a
/// Flutter asset — it's a dev/CI tool.
void main() {
  // Walk up from test/unit/ to find eval/test_set.json.
  final testSetPath = '${Directory.current.path}/eval/test_set.json';

  group('eval test set', () {
    test('file exists', () {
      expect(File(testSetPath).existsSync(), isTrue,
          reason: 'eval/test_set.json not found at $testSetPath');
    });

    test('has exactly 50 entries with all required fields', () {
      final raw = File(testSetPath).readAsStringSync();
      final data = jsonDecode(raw) as List;

      expect(data, hasLength(50));

      for (final entry in data) {
        final e = entry as Map<String, dynamic>;
        expect(e['id'], isA<String>(), reason: 'missing id');
        expect(e['query'], isA<String>(), reason: 'missing query');
        expect(e['category'], isA<String>(), reason: 'missing category');
        expect(
          ['standard', 'cross_hazard', 'myth', 'out_of_scope', 'follow_up'],
          contains(e['category']),
          reason: 'invalid category: ${e['category']}',
        );
        expect(
          e.containsKey('expected_topic'),
          isTrue,
          reason: 'missing expected_topic (can be null)',
        );
        expect(
          e.containsKey('expected_safety_refusal'),
          isTrue,
          reason: 'missing expected_safety_refusal',
        );
      }
    });

    test('has 10 queries per category', () {
      final raw = File(testSetPath).readAsStringSync();
      final data = jsonDecode(raw) as List;

      final counts = <String, int>{};
      for (final entry in data) {
        final cat = (entry as Map<String, dynamic>)['category'] as String;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }

      for (final cat in [
        'standard',
        'cross_hazard',
        'myth',
        'out_of_scope',
        'follow_up',
      ]) {
        expect(counts[cat], 10, reason: 'expected 10 queries in $cat');
      }
    });

    test('all myth queries have a myth_to_correct', () {
      final raw = File(testSetPath).readAsStringSync();
      final data = jsonDecode(raw) as List;

      for (final entry in data) {
        final e = entry as Map<String, dynamic>;
        if (e['category'] == 'myth') {
          expect(
            e['myth_to_correct'],
            isNotNull,
            reason: 'myth query ${e['id']} must have myth_to_correct',
          );
        }
      }
    });

    test('all out_of_scope queries expect a safety refusal', () {
      final raw = File(testSetPath).readAsStringSync();
      final data = jsonDecode(raw) as List;

      for (final entry in data) {
        final e = entry as Map<String, dynamic>;
        if (e['category'] == 'out_of_scope') {
          expect(
            e['expected_safety_refusal'],
            isTrue,
            reason:
                'out_of_scope query ${e['id']} must expect safety refusal',
          );
        }
      }
    });
  });
}
