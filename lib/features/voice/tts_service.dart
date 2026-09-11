import 'package:flutter_tts/flutter_tts.dart';

import '../../core/locale_controller.dart';

/// Text-to-speech adapter. Configured per docs/design.md §15.1:
/// bn-BD (fallback bn-IN), speech rate 0.9x for stressed-voice clarity,
/// max volume (crisis context), default pitch.
///
/// In en mode the voice picks en-US (fallback en-GB) so English answers
/// don't get read aloud in a Bangla voice. The active locale is read
/// from [LocaleController] on every [init] so a switch is reflected on
/// the next call to [speak] / [setLanguage].
///
/// Per design.md §13.12, the actual voice name is locked in Phase 5 QA
/// after device testing; this service exposes setVoice for that.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String _configuredLang = '';

  Future<void> init() async {
    if (_ready) return;
    await _applyLocale(localeController.languageCode);
    await _tts.setSpeechRate(0.45); // ~0.9x on flutter_tts's 0-1 scale
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  /// Switch the TTS voice to match the active locale. Call after a
  /// language change so subsequent [speak] calls use the right voice.
  Future<void> setLanguage(String localeCode) async {
    await _applyLocale(localeCode);
  }

  Future<void> _applyLocale(String localeCode) async {
    final isEnglish = localeCode.toLowerCase().startsWith('en');
    String candidate;
    if (isEnglish) {
      // en-US first; fallback en-GB if not available.
      final us = await _tts.isLanguageAvailable('en-US');
      candidate = us == true ? 'en-US' : 'en-GB';
    } else {
      // bn-BD first; fallback bn-IN if not available.
      final bd = await _tts.isLanguageAvailable('bn-BD');
      candidate = bd == true ? 'bn-BD' : 'bn-IN';
    }
    if (_configuredLang != candidate) {
      await _tts.setLanguage(candidate);
      _configuredLang = candidate;
    }
  }

  Future<void> speak(String text) async {
    await init();
    // Re-apply locale in case the user switched languages since init().
    await _applyLocale(localeController.languageCode);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}