import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';

import 'stt_provider.dart';

/// Online speech-to-text provider using the device's built-in SpeechRecognizer
/// (Android: Google STT; iOS: Siri). Requires network on most OEM builds.
///
/// This is the fallback when no offline engine (Vosk) is available.
class SpeechToTextProvider implements SttProvider {
  final _stt = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;

  /// Active completer for the current listen session. Non-null only while
  /// a session is in flight — the error/status callbacks use this to
  /// short-circuit the 30s timeout on permanent errors.
  Completer<String?>? _activeCompleter;

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
      onError: _onSttError,
      onStatus: _onSttStatus,
    );
    return _ready;
  }

  /// Called by the `speech_to_text` plugin for every recognition error.
  /// Permanent errors (no_match, network, permission) must complete the
  /// active completer immediately so the UI doesn't hang for 30s.
  void _onSttError(SpeechRecognitionError e) {
    debugPrint('STT error: ${e.errorMsg} (${e.permanent ? 'permanent' : 'recoverable'})');
    if (e.permanent && _activeCompleter != null && !_activeCompleter!.isCompleted) {
      _listening = false;
      _activeCompleter!.complete(null);
    }
  }

  /// Called by the `speech_to_text` plugin when the listening state changes.
  /// Handles the case where the platform stops listening without a final
  /// result (some OEMs do this after their internal silence timeout).
  void _onSttStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (_listening && _activeCompleter != null && !_activeCompleter!.isCompleted) {
        _listening = false;
        _activeCompleter!.complete(null);
      }
    }
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
    _activeCompleter = completer;
    try {
      await _stt.listen(
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
          pauseFor: const Duration(seconds: 5),
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('STT listen() threw: $e');
      _listening = false;
      if (!completer.isCompleted) completer.complete(null);
      return null;
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _listening = false;
        _stt.stop();
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    ).whenComplete(() {
      if (_activeCompleter == completer) _activeCompleter = null;
    });
  }

  @override
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
    // Complete the active completer so the caller's await resolves
    // instead of hanging until timeout.
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(null);
    }
  }

  @override
  void dispose() {
    _ready = false;
    _listening = false;
    _activeCompleter = null;
    _stt.cancel();
  }
}
