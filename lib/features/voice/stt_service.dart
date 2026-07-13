import 'dart:async';

/// Vosk-Bangla speech-to-text service. Fully offline (bundled model).
///
/// STATUS (skeleton phase): BLOCKED. The `vosk_flutter_service` 0.1.2
/// plugin ships with `compileSdk 33` hardcoded in its pub-cache
/// android/build.gradle, which AGP 9.x hard-rejects (its transitive
/// androidx deps need compileSdk ≥ 34). The plugin was removed from
/// pubspec.yaml at Phase 1.1 for this reason.
///
/// Resolution paths for Phase 4.1 (pick one at spike time):
///   1. Fork vosk_flutter_service, bump its compileSdk to 36, publish /
///      path-override.
///   2. Edit the pub-cache build.gradle in place (fragile — lost on
///      `flutter pub cache repair`).
///   3. Use `speech_to_text` (already in pubspec) as a hybrid fallback —
///      not truly offline on all OEM builds, but compiles today.
///   4. Write a thin Flutter platform channel wrapping Vosk's Android AAR
///      directly (com.alphacephei:vosk-android:0.3.75).
///
/// The chat screen's mic button is wired to a placeholder snackbar until
/// this resolves (lib/features/chat/chat_screen.dart _onMicPressed).
class SttService {
  final _ready = false;

  Future<void> init() async {
    if (_ready) return;
    // Implementation lands when the plugin blocker above is resolved.
    throw UnimplementedError(
      'Vosk STT not yet wired — see stt_service.dart doc comment for the '
      'four resolution paths. The vosk_flutter_service plugin is blocked '
      'on a compileSdk-33 vs AGP-9.x conflict.',
    );
  }

  /// Stream of partial + final transcripts. Hooked to the mic stream at
  /// 16kHz mono PCM, fed into VoskRecognizer.acceptWaveform.
  Stream<String> listen() async* {
    // Yields nothing until init() succeeds.
  }

  Future<void> stop() async {}
}