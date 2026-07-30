import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/voice/speech_to_text_provider.dart';
import 'package:shongjog/features/voice/stt_provider.dart';

/// Locale resolution for speech input.
///
/// The app asks for `bn-BD`. Google ships Bangla speech recognition as a
/// SEPARATE on-device download, so on a large share of phones it simply is
/// not installed — and handing the engine a locale it does not have fails the
/// entire session rather than degrading. From the user's side that is
/// indistinguishable from "the mic button does nothing", which is exactly how
/// it was reported.
///
/// Engines also report ids inconsistently (`bn_BD`, `bn-BD`, bare `bn`), so
/// naive string equality misses installed Bangla packs.
void main() {
  group('resolveLocale', () {
    test('takes an exact match when the pack is installed', () {
      expect(
        SpeechToTextProvider.resolveLocale('bn-BD', ['en_US', 'bn_BD', 'hi_IN']),
        'bn_BD',
      );
    });

    test('matches across separator and case differences', () {
      // The request uses a hyphen; Android reports underscores.
      expect(SpeechToTextProvider.resolveLocale('bn-BD', ['BN_bd']), 'BN_bd');
      expect(SpeechToTextProvider.resolveLocale('bn-BD', ['bn-BD']), 'bn-BD');
    });

    test('falls back to the same language in another region', () {
      // bn_IN recognises Bangla perfectly well. Refusing it because the
      // region differs would strand a user who has a usable pack installed.
      expect(
        SpeechToTextProvider.resolveLocale('bn-BD', ['en_US', 'bn_IN']),
        'bn_IN',
      );
    });

    test('matches a bare language id', () {
      expect(SpeechToTextProvider.resolveLocale('bn-BD', ['bn']), 'bn');
    });

    test('returns null — meaning device default — when the language is '
        'absent entirely', () {
      // Null is deliberate. English recognition is far more use than a mic
      // button that fails identically every time.
      expect(
        SpeechToTextProvider.resolveLocale('bn-BD', ['en_US', 'hi_IN']),
        isNull,
      );
    });

    test('passes the request through when locales could not be enumerated', () {
      // An empty list means "we do not know", not "nothing is installed".
      // Overriding to the device default there would silently drop Bangla on
      // a phone that has it.
      expect(SpeechToTextProvider.resolveLocale('bn-BD', const []), 'bn-BD');
    });
  });

  group('classify', () {
    test('separates causes that need different things from the user', () {
      expect(SpeechToTextProvider.classify('error_language_not_supported'),
          SttFailure.languageUnavailable);
      expect(SpeechToTextProvider.classify('error_language_unavailable'),
          SttFailure.languageUnavailable);
      expect(SpeechToTextProvider.classify('error_network'),
          SttFailure.networkRequired);
      expect(SpeechToTextProvider.classify('error_network_timeout'),
          SttFailure.networkRequired);
      expect(SpeechToTextProvider.classify('error_insufficient_permissions'),
          SttFailure.permissionDenied);
    });

    test('no_match and speech_timeout are the only retryable ones', () {
      expect(SpeechToTextProvider.classify('error_no_match'),
          SttFailure.noMatch);
      expect(SpeechToTextProvider.classify('error_speech_timeout'),
          SttFailure.noMatch);
    });

    test('a ListenFailedException about language is classified, not dropped',
        () {
      // This is the shape thrown when listen() is handed a locale the engine
      // does not have — it arrives as an exception, not an onError callback.
      expect(
        SpeechToTextProvider.classify(
            'ListenFailedException: error_language_not_supported'),
        SttFailure.languageUnavailable,
      );
    });

    test('anything unrecognised is unknown rather than mislabelled', () {
      expect(SpeechToTextProvider.classify('some_new_oem_error'),
          SttFailure.unknown);
    });
  });

  group('hasLanguage', () {
    test('is true for any region of the language', () {
      final p = SpeechToTextProvider()..availableLocales = ['en_US', 'bn_IN'];
      expect(p.hasLanguage('bn'), isTrue);
      expect(p.hasLanguage('BN'), isTrue, reason: 'case-insensitive');
    });

    test('is false when the language is absent', () {
      final p = SpeechToTextProvider()..availableLocales = ['en_US', 'hi_IN'];
      expect(p.hasLanguage('bn'), isFalse);
    });

    test('is false when locales are unknown, so the UI does not claim a '
        'missing pack it has not verified', () {
      final p = SpeechToTextProvider();
      expect(p.hasLanguage('bn'), isFalse);
      expect(p.availableLocales, isEmpty);
    });
  });
}
