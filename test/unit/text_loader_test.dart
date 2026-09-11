import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/text_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextLoader', () {
    test('loadJson parses an array asset (directory.json)', () async {
      final result = await TextLoader.loadJson<List<dynamic>>(
        'assets/data/emergency_directory.json',
        (raw, _) => jsonDecode(raw) as List<dynamic>,
      );
      expect(result, isA<List<dynamic>>());
      expect(result, isNotEmpty);
    });

    test('localeFor falls back to bn when tag is unknown', () {
      expect(TextLoader.localeFor('xx'), 'bn');
      expect(TextLoader.localeFor('bn'), 'bn');
      expect(TextLoader.localeFor('en'), 'en');
      expect(TextLoader.localeFor('EN'), 'en');
      expect(TextLoader.localeFor(null), 'bn');
    });

    test('pickBundle returns the bn block by default', () {
      final fake = <String, dynamic>{
        'bn': {'a': 1},
        'en': {'a': 2},
      };
      expect(TextLoader.pickBundle(fake, 'en')['a'], 2);
      expect(TextLoader.pickBundle(fake, 'bn')['a'], 1);
      expect(TextLoader.pickBundle(fake, 'xx')['a'], 1);
      expect(TextLoader.pickBundle(fake, null)['a'], 1);
    });

    test('pickBundle falls through to bn when the asked block is absent', () {
      final fake = <String, dynamic>{
        'bn': {'a': 1},
      };
      expect(TextLoader.pickBundle(fake, 'en')['a'], 1);
    });
  });
}
