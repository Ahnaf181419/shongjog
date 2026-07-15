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

  /// Release resources.
  void dispose();
}
