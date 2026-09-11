import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/demo_seeder.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('bn'));
  });

  group('DemoSeeder.seeds', () {
    test('returns 3 seed Q&A pairs', () {
      final seeds = DemoSeeder.seeds(l10n);
      expect(seeds, hasLength(3));
    });

    test('each seed has a non-empty question and answer', () {
      for (final s in DemoSeeder.seeds(l10n)) {
        expect(s.question, isNotEmpty);
        expect(s.answer, isNotEmpty);
      }
    });

    test('seeds are stable across calls', () {
      final first = DemoSeeder.seeds(l10n);
      final second = DemoSeeder.seeds(l10n);
      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].question, second[i].question);
        expect(first[i].answer, second[i].answer);
      }
    });
  });
}
