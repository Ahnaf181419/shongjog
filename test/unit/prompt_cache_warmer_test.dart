import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/locale_controller.dart';
import 'package:shongjog/core/prompt_cache_warmer.dart';
import 'package:shongjog/core/text_loader.dart';
import 'package:shongjog/rag/rumour_strings_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptCacheWarmer', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TextLoader.debugClearCache();
    });

    test('start primes cachedRumour for default locale', () async {
      final controller = LocaleController();
      final warmer = PromptCacheWarmer(controller);
      await warmer.start();

      expect(cachedRumour.rumourPrefixes, isNotEmpty);
      expect(cachedRumour.systemInstruction, isNotEmpty);
    });

    test('switching locale updates cachedRumour to English', () async {
      final controller = LocaleController();
      final warmer = PromptCacheWarmer(controller);
      await warmer.start();

      await controller.setLocale(const Locale('en'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(cachedRumour.systemInstruction.toLowerCase(), contains('rumour'));
    });
  });
}
