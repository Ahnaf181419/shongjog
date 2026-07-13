import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Lifecycle state of the on-device Gemma model, surfaced in the UI as the
/// AppBar subtitle (docs/design.md §13.14).
enum ModelState {
  notDownloaded,
  downloading,
  ready,
  loading,
  failed,
}

/// Manages the on-device Gemma 4 E2B lifecycle: download (one-time, gated
/// behind INTERNET permission), persist to app docs dir, lazy-initialize
/// into the LiteRT-LM runtime.
///
/// Wraps flutter_gemma 0.5.x's real API surface:
///   - `FlutterGemma.instance.modelManager.setModelPath(path)` to register
///     the model file.
///   - `FlutterGemma.instance.init(maxTokens, temperature, ...)` to load
///     it into RAM and return an [InferenceModel].
///   - `model.getResponse(prompt:)` for synchronous generation.
///
/// Source of truth: docs/architecture.md §5 (pipeline), §9 (failure modes).
class ModelManager {
  static const _modelFileName = 'gemma4_e2b_int4.task';

  /// Default model URL. Confirmed at Phase 0 spike A; substituted if the
  /// spike pivots to Gemma 3 1B.
  static const _defaultUrl =
      'https://huggingface.co/google/gemma-4-e2b-it-litertlm/resolve/main/gemma4_e2b_int4.task';

  ModelState _state = ModelState.notDownloaded;
  ModelState get state => _state;

  InferenceModel? _model;
  bool _initializing = false;

  /// Path to the model file inside the app's documents directory.
  Future<String> modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFileName';
  }

  /// True if a model file >100MB is already on disk (heuristic — the .task
  /// artifact is ~1.5GB; 100MB guards against partial downloads).
  Future<bool> isOnDisk() async {
    final f = File(await modelPath());
    if (!await f.exists()) return false;
    return await f.length() > 100000000;
  }

  /// Ensure the model file is on disk. Uses a plain [HttpClient] for the
  /// spike; Phase 3 swaps in `background_downloader` for resume-on-failure.
  ///
  /// [onProgress] reports a 0.0–1.0 fraction as bytes stream in.
  Future<void> ensureModel({
    String url = _defaultUrl,
    void Function(double)? onProgress,
  }) async {
    final path = await modelPath();
    final f = File(path);
    if (await f.exists() && await f.length() > 100000000) {
      _state = ModelState.ready;
      return;
    }
    _state = ModelState.downloading;
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      final sink = f.openWrite();
      var received = 0;
      final total = resp.contentLength;
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      _state = ModelState.ready;
    } catch (e) {
      _state = ModelState.failed;
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Lazily initialize the model into RAM and cache the [InferenceModel].
  ///
  /// Cold start loads the model into RAM — expect 3–10s on a real arm64
  /// device. The UI must surface "AI প্রস্তুত হচ্ছে..." during this window
  /// (docs/design.md §13.5).
  ///
  /// Config per docs/prd.md §8: 4-bit, thinking off, maxTokens 512,
  /// temperature 0.2 for grounded-but-not-creative answers.
  Future<InferenceModel> initialize() async {
    if (_model != null) return _model!;
    if (_initializing) {
      // Guard against concurrent init calls from rapid taps.
      throw StateError('Model is already initializing');
    }
    _initializing = true;
    _state = ModelState.loading;
    try {
      final path = await modelPath();
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(path);
      _model = await FlutterGemmaPlugin.instance.init(
        maxTokens: 512,
        temperature: 0.2,
      );
      _state = ModelState.ready;
      return _model!;
    } catch (e) {
      _state = ModelState.failed;
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// Generate a response for [prompt]. Initializes the model on first call.
  Future<String> generate(String prompt) async {
    final model = await initialize();
    return model.getResponse(prompt: prompt);
  }
}