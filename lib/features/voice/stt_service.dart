import 'dart:async';

import 'speech_to_text_provider.dart';
import 'stt_provider.dart';
import 'vosk_stt_provider.dart';

/// Bangla speech-to-text service. Automatically picks the best available
/// engine:
///
/// 1. **Vosk** (offline) — preferred when the plugin compiles and a model is
///    bundled. Currently blocked by compileSdk incompatibility.
/// 2. **speech_to_text** (online) — fallback using the device's built-in
///    SpeechRecognizer. Works on most Android/iOS devices but requires
///    network on some OEM builds.
///
/// The active provider is surfaced in diagnostics via [activeProviderName].
class SttService {
  SttProvider? _provider;
  final _partialCtl = StreamController<String>.broadcast();

  Stream<String> get partials => _partialCtl.stream;

  /// The name of the active provider, or null if not yet initialized.
  String? get activeProviderName => _provider?.name;

  /// Whether the active provider works fully offline.
  bool get isOfflineCapable => _provider?.isOffline ?? false;

  /// Lazily select and initialize the best available provider.
  Future<SttProvider> _ensureProvider() async {
    if (_provider != null) return _provider!;

    // Try Vosk first (true offline).
    if (await VoskSttProvider.isModelBundled()) {
      final vosk = VoskSttProvider();
      if (await vosk.init()) {
        _provider = vosk;
        return _provider!;
      }
    }

    // Fall back to speech_to_text (online).
    _provider = SpeechToTextProvider();
    return _provider!;
  }

  /// Initialize the STT engine. Returns true if ready to listen.
  Future<bool> init() async {
    final p = await _ensureProvider();
    if (!p.isInitialized) {
      return await p.init();
    }
    return true;
  }

  /// Start listening with bn-BD locale. Returns the final transcript when
  /// the user stops speaking, or null on timeout/cancel.
  Future<String?> listen({String localeId = 'bn-BD'}) async {
    final p = await _ensureProvider();
    return p.listen(
      localeId: localeId,
      onPartial: (text) => _partialCtl.add(text),
    );
  }

  /// Stop the current listening session.
  Future<void> stop() async {
    await _provider?.stop();
  }

  /// Release all resources.
  void dispose() {
    _provider?.dispose();
    _partialCtl.close();
  }
}
