import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'stt_provider.dart';

/// Online speech-to-text provider using the device's built-in SpeechRecognizer
/// (Android: Google STT; iOS: Siri). Requires network on most OEM builds.
///
/// This is the fallback when no offline engine (Vosk) is available.
class SpeechToTextProvider implements SttProvider {
  final _stt = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;

  @override
  String get name => 'speech_to_text (online)';

  @override
  bool get isOffline => false;

  @override
  bool get isInitialized => _ready;

  @override
  Future<bool> init() async {
    if (_ready) return _ready;
    _ready = await _stt.initialize(
      onError: (e) => debugPrint('STT error: $e'),
      onStatus: (_) {},
    );
    return _ready;
  }

  @override
  Future<String?> listen({
    String localeId = 'bn_BD',
    void Function(String partial)? onPartial,
  }) async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return null;
    }
    if (_listening) return null;
    _listening = true;

    final completer = Completer<String?>();
    _stt.listen(
      onResult: (r) {
        if (onPartial != null) onPartial(r.recognizedWords);
        if (r.finalResult) {
          _listening = false;
          if (!completer.isCompleted) {
            completer.complete(r.recognizedWords);
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _listening = false;
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
  }

  @override
  void dispose() {
    _stt.cancel();
  }
}
