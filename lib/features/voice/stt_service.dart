import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Bangla speech-to-text service. Uses device STT (Android SpeechRecognizer
/// via speech_to_text plugin). On most OEM builds this routes through
/// Google's network STT — acceptable for the demo, not truly offline on
/// every device. Phase 4.1 would replace with a true offline path if
/// venue WiFi is unreliable.
class SttService {
  final _stt = stt.SpeechToText();
  final _partialCtl = StreamController<String>.broadcast();
  final _finalCtl = StreamController<String>.broadcast();
  final _errorCtl = StreamController<String>.broadcast();
  bool _ready = false;
  bool _listening = false;

  Future<bool> init() async {
    if (_ready) return _ready;
    _ready = await _stt.initialize(
      onError: (e) => _errorCtl.add('stt-error'),
      onStatus: (_) {},
    );
    return _ready;
  }

  bool get isListening => _listening;
  Stream<String> get partials => _partialCtl.stream;
  Stream<String> get finals => _finalCtl.stream;
  Stream<String> get errors => _errorCtl.stream;

  /// Start listening with bn_BD locale. Returns the final transcript when
  /// the user stops speaking, or null on timeout/cancel.
  Future<String?> listen({String localeId = 'bn_BD'}) async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return null;
    }
    if (_listening) return null;
    _listening = true;

    final completer = Completer<String?>();
    _stt.listen(
      onResult: (r) {
        _partialCtl.add(r.recognizedWords);
        if (r.finalResult) {
          _finalCtl.add(r.recognizedWords);
          if (!completer.isCompleted) {
            _listening = false;
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
        if (!completer.isCompleted) {
          _listening = false;
          completer.complete(null);
        }
        return null;
      },
    );
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
  }
}
