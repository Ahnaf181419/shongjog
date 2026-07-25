import 'dart:async';

import 'stt_provider.dart';

/// Offline speech-to-text provider using Vosk with a bundled Bangla acoustic
/// model. This is the target architecture for true offline voice input.
///
/// BLOCKED: The `vosk_flutter` plugin (0.1.2) ships `compileSdk 33` in its
/// Android build.gradle, which AGP 9.x hard-rejects. Options to unblock:
/// 1. Fork the plugin and bump compileSdk to 35
/// 2. Edit pub-cache directly (fragile, lost on flutter pub cache repair)
/// 3. Wait for upstream release with compileSdk 35+
/// 4. Use a different Vosk plugin or platform channel
///
/// When unblocked: bundle `assets/vosk/model-bn/` (≈40MB small model),
/// implement [init] to load the model via the plugin, and [listen] to
/// run recognition. [SttService] will automatically prefer this provider
/// when [isAvailable] returns true.
class VoskSttProvider implements SttProvider {
  @override
  String get name => 'Vosk (offline)';

  @override
  bool get isOffline => true;

  @override
  bool get isInitialized => false;

  /// Check if the Vosk model is bundled in assets.
  /// Returns false until the plugin compiles and the model is added.
  static Future<bool> isModelBundled() async {
    // When the plugin is fixed, check for assets/vosk/model-bn/ here.
    // For now, always returns false — speech_to_text is used instead.
    return false;
  }

  @override
  Future<bool> init() async {
    // TODO(vosk): When plugin compiles, load the Bangla model from assets.
    // final model = await VoskFlutterPlugin.instance.createModel(
    //   await rootBundle.load('assets/vosk/model-bn'));
    // _recognizer = await VoskFlutterPlugin.instance.createRecognizer(model: model);
    // return _recognizer != null;
    return false;
  }

  @override
  Future<String?> listen({
    String localeId = 'bn-BD',
    void Function(String partial)? onPartial,
  }) async {
    // TODO(vosk): Start recognition and emit partial/final results.
    throw UnimplementedError('Vosk provider not yet active — plugin compileSdk issue');
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
