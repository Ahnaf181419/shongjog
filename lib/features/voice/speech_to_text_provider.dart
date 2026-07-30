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
  SttFailure? lastFailure;

  @override
  List<String> availableLocales = const [];

  /// The locale actually handed to the engine, which may not be the one that
  /// was asked for — see [resolveLocale].
  String? lastUsedLocale;

  /// Best partial transcript seen this session.
  ///
  /// Some OEM builds stop listening without ever delivering a final result.
  /// Returning what the user demonstrably said beats discarding it and
  /// showing "try again".
  String _bestPartial = '';

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
    if (!_ready) {
      lastFailure = SttFailure.engineUnavailable;
      return false;
    }
    // Cache what the engine can actually recognise. Asking for a language
    // the device does not have installed fails the whole session, and
    // Bangla is very often absent — Google ships it as a separate download.
    try {
      final locales = await _stt.locales();
      availableLocales = locales.map((l) => l.localeId).toList(growable: false);
      debugPrint('STT: ${availableLocales.length} locales available');
    } catch (e) {
      debugPrint('STT: could not enumerate locales: $e');
      availableLocales = const [];
    }
    return _ready;
  }

  /// Pick the closest installed locale to [requested].
  ///
  /// Engines report ids inconsistently — `bn_BD`, `bn-BD`, sometimes bare
  /// `bn` — so matching is done on a normalised form. Order:
  ///
  ///   1. exact match
  ///   2. same language, any region (`bn_IN` will still recognise Bangla)
  ///   3. null, meaning "use the device default"
  ///
  /// Falling back to the device default rather than failing is deliberate: a
  /// user who can only get English recognition is far better served than one
  /// whose mic button does nothing. The caller can see what happened via
  /// [lastUsedLocale].
  @visibleForTesting
  static String? resolveLocale(String requested, List<String> available) {
    if (available.isEmpty) return requested;
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();

    final want = norm(requested);
    for (final a in available) {
      if (norm(a) == want) return a;
    }

    final lang = want.split('_').first;
    for (final a in available) {
      if (norm(a).split('_').first == lang) return a;
    }

    return null;
  }

  /// Whether any variant of [languageCode] is installed.
  bool hasLanguage(String languageCode) {
    final lang = languageCode.toLowerCase();
    return availableLocales.any(
        (a) => a.replaceAll('-', '_').toLowerCase().split('_').first == lang);
  }

  /// Map the engine's error string onto something the UI can act on.
  static SttFailure classify(String errorMsg) {
    final e = errorMsg.toLowerCase();
    if (e.contains('language') || e.contains('locale')) {
      return SttFailure.languageUnavailable;
    }
    if (e.contains('network')) return SttFailure.networkRequired;
    if (e.contains('permission')) return SttFailure.permissionDenied;
    if (e.contains('no_match') || e.contains('speech_timeout')) {
      return SttFailure.noMatch;
    }
    if (e.contains('busy') || e.contains('client')) return SttFailure.unknown;
    return SttFailure.unknown;
  }

  /// Called by the `speech_to_text` plugin for every recognition error.
  /// Permanent errors (no_match, network, permission) must complete the
  /// active completer immediately so the UI doesn't hang for 30s.
  void _onSttError(SpeechRecognitionError e) {
    debugPrint(
        'STT error: ${e.errorMsg} (${e.permanent ? 'permanent' : 'recoverable'})');
    lastFailure = classify(e.errorMsg);
    if (e.permanent && _activeCompleter != null && !_activeCompleter!.isCompleted) {
      _listening = false;
      _activeCompleter!.complete(_bestPartialOrNull());
    }
  }

  /// Called by the `speech_to_text` plugin when the listening state changes.
  /// Handles the case where the platform stops listening without a final
  /// result (some OEMs do this after their internal silence timeout).
  void _onSttStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (_listening && _activeCompleter != null && !_activeCompleter!.isCompleted) {
        _listening = false;
        _activeCompleter!.complete(_bestPartialOrNull());
      }
    }
  }

  String? _bestPartialOrNull() {
    final t = _bestPartial.trim();
    if (t.isEmpty) return null;
    debugPrint('STT: no final result; falling back to best partial');
    return t;
  }

  @override
  Future<String?> listen({
    String localeId = 'bn-BD',
    void Function(String partial)? onPartial,
  }) async {
    if (!_ready) {
      final ok = await init();
      if (!ok) return null;
    }
    if (_listening) return null;
    _listening = true;
    _bestPartial = '';
    lastFailure = null;

    final resolved = resolveLocale(localeId, availableLocales);
    lastUsedLocale = resolved;
    if (resolved != localeId) {
      debugPrint('STT: "$localeId" unavailable; using '
          '${resolved ?? "the device default"} instead');
    }

    final completer = Completer<String?>();
    _activeCompleter = completer;
    try {
      await _stt.listen(
        onResult: (r) {
          if (r.recognizedWords.isNotEmpty) _bestPartial = r.recognizedWords;
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
          // pauseFor: how long a SILENCE may last before the platform
          // decides the user is done talking — this is the "natural end
          // of utterance" signal and 5s is a reasonable value for it.
          pauseFor: const Duration(seconds: 5),
          // listenFor: the actual ceiling on total session length while
          // the user keeps talking. This was previously unset, and the
          // manual `.timeout(10s)` below was standing in for it — except
          // that manual timeout fired 10s after listen() STARTED
          // regardless of whether the user was still actively speaking,
          // silently discarding the whole utterance and returning null.
          // For a voice-first emergency app, describing a real situation
          // ("আমার বাড়িতে আগুন লেগেছে, আমরা তিনতলায় আটকা পড়েছি...")
          // routinely takes well past 10 seconds — every such query was
          // being cut off mid-sentence, which is exactly what "voice
          // input doesn't work" looks like from the user's side.
          listenFor: const Duration(seconds: 60),
          // Null means "device default". Passing a locale the engine does
          // not have installed fails the entire session.
          localeId: resolved,
        ),
      );
    } catch (e) {
      // ListenFailedException lands here — most often because the requested
      // language is not installed on this device.
      debugPrint('STT listen() threw: $e');
      lastFailure = classify(e.toString());
      _listening = false;
      if (!completer.isCompleted) completer.complete(null);
      return null;
    }

    // Last-resort hang guard only — normal completion happens via
    // onResult's finalResult, or via _onSttStatus/_onSttError when the
    // platform reports listening has stopped (including its own
    // listenFor/pauseFor timeouts above). This outer timeout exists
    // solely in case the native side never calls back at all; it's set
    // comfortably longer than listenFor so it never fires under normal
    // operation.
    return completer.future.timeout(
      const Duration(seconds: 70),
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
      _activeCompleter!.complete(_bestPartialOrNull());
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
