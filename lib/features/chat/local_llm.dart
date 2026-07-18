/// Minimal contract that [ChatRepository] needs from an on-device LLM.
///
/// Extracted from [ModelManager] so the repository can be unit-tested
/// with a 30-line fake without spinning up the real ChangeNotifier +
/// path_provider + flutter_gemma stack. The production class
/// [ModelManager] already exposes these exact members, so it implements
/// this interface via duck typing (see model_manager.dart).
///
/// If [ChatRepository] ever needs another member from the LLM (e.g.
/// `stop()`, `cancelStream()`, or `tokenCount`), add it here AND to
/// ModelManager's implementation. The `@override` annotation on
/// ModelManager's version will fail the analyzer if the signature
/// diverges, so the contract is statically enforced.
library;

import 'package:flutter_gemma/core/tool.dart';

abstract class LocalLlm {
  /// True if the LLM has finished loading and can answer immediately
  /// (no native init call needed). When false, [generate] must do a
  /// lazy-load or cold-start on first call.
  bool get isReady;

  /// True if any model variant is fully downloaded on disk. Differs
  /// from [isReady] when the file is present but the runtime hasn't
  /// been initialized yet — for example, the first chat message after
  /// a fresh app install.
  Future<bool> isAnyOnDisk();

  /// Run inference on [prompt] and return the answer. Must throw on
  /// failure rather than returning a partial / canned response — the
  /// repository decides how to recover (and [ChatRepository] surfaces
  /// the failure to the UI rather than silently masking it).
  Future<String> generate(String prompt);

  /// Run inference with function-calling and return the raw SDK JSON
  /// containing the tool call arguments. Used by SOS composer for
  /// structured extraction. Returns null if the model doesn't support
  /// tool calls or the session doesn't expose RawSdkResponseSession.
  /// Default implementation is a no-op for test fakes.
  Future<String?> generateStructured({
    required String prompt,
    required List<Tool> tools,
  }) async =>
      null;

  /// Override the model's thinking mode for the next [generate] call.
  /// Set to null to use the SDK default. Used by the urgency classifier
  /// to route reflex (critical) vs. deliberation (complex) queries.
  /// Default implementation is a no-op for test fakes that don't care.
  void setThinkingMode(bool? enable) {}
}
