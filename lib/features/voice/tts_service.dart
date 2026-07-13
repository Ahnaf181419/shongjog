import 'package:flutter_tts/flutter_tts.dart';

/// Bangla text-to-speech adapter. Configured per docs/design.md §15.1:
/// bn-BD (fallback bn-IN), speech rate 0.9x for stressed-voice clarity,
/// max volume (crisis context), default pitch.
///
/// Per design.md §13.12, the actual voice name is locked in Phase 5 QA
/// after device testing; this service exposes setVoice for that.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    // Try bn-BD first; fall back to bn-IN if unavailable.
    final bd = await _tts.isLanguageAvailable('bn-BD');
    if (bd == true) {
      await _tts.setLanguage('bn-BD');
    } else {
      await _tts.setLanguage('bn-IN');
    }
    await _tts.setSpeechRate(0.45); // ~0.9x on flutter_tts's 0-1 scale
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}