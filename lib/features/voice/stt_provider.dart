import 'dart:async';

/// Abstract speech-to-text provider interface.
///
/// Allows swapping between online (speech_to_text) and offline (Vosk)
/// engines without touching the call site. [SttService] automatically
/// picks the best available provider.
///
/// Architecture note: Vosk integration is blocked by the vosk_flutter
/// plugin's compileSdk 33 incompatibility with AGP 9.x. When that's
/// resolved (fork, alternative plugin, or manual pub-cache edit),
/// [VoskSttProvider] can be activated by returning true from [isAvailable]
/// after checking for the bundled model in assets/vosk/.
abstract class SttProvider {
  /// Human-readable name for diagnostics UI.
  String get name;

  /// True if this provider is fully offline (no network needed).
  bool get isOffline;

  /// Initialize the engine. Returns true if ready to listen.
  Future<bool> init();

  /// Whether the engine is initialized and ready.
  bool get isInitialized;

  /// Start listening. Returns the final transcript or null on
  /// timeout/cancel.
  ///
  /// [onPartial] fires with interim recognition results.
  /// [localeId] is a BCP-47 tag like 'bn-BD'.
  Future<String?> listen({
    String localeId,
    void Function(String partial)? onPartial,
  });

  /// Stop the current listening session.
  Future<void> stop();

  /// Why the last [listen] returned null, in engine terms.
  ///
  /// A null transcript has several very different causes — no speech
  /// recognised, the requested language is not installed, no network on an
  /// OEM build that needs it, the recogniser is missing entirely — and they
  /// need different things from the user. Without this the UI could only say
  /// "try again", which is unhelpful when trying again cannot possibly work.
  ///
  /// Null when the last session succeeded or none has run.
  SttFailure? get lastFailure;

  /// Locale ids the engine can actually recognise, populated by [init].
  /// Empty when the engine could not be queried.
  List<String> get availableLocales;

  /// Release resources.
  void dispose();
}

/// Why a listen session produced nothing.
enum SttFailure {
  /// The engine reported no recognisable speech. Retrying may work.
  noMatch,

  /// The requested language pack is not installed on this device.
  languageUnavailable,

  /// The engine needs a network connection it does not have.
  networkRequired,

  /// The microphone permission was refused.
  permissionDenied,

  /// No speech recogniser is reachable at all.
  engineUnavailable,

  /// Something else — see the engine's own message in the log.
  unknown,
}
