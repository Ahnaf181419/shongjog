import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
/// Extends [ChangeNotifier] so the UI (ChatScreen, SettingsScreen) can
/// react to model state transitions reactively. The cold-start window
/// (3–10s on arm64) surfaces "AI প্রস্তুত হচ্ছে..." in the chat UI
/// (docs/design.md §13.5).
///
/// Download uses [HttpClient] with resume support (Range header). The
/// `background_downloader` package was removed from pubspec in favour of
/// stdlib HttpClient (smaller APK; the size of the Gemma file means we
/// need UI-level progress, not OS-level background continuation).
class ModelManager extends ChangeNotifier {
  static const _modelFileName = 'gemma4_e2b_int4.task';

  /// Default model URL. Confirmed at Phase 0 spike A; substituted if the
  /// spike pivots to Gemma 3 1B.
  static const _defaultUrl =
      'https://huggingface.co/google/gemma-4-e2b-it-litertlm/resolve/main/gemma4_e2b_int4.task';

  ModelState _state = ModelState.notDownloaded;
  ModelState get state => _state;

  /// Download progress as a 0.0–1.0 fraction, or null when not downloading.
  double? _downloadProgress;
  double? get downloadProgress => _downloadProgress;

  InferenceModel? _model;
  bool _initializing = false;

  void _setState(ModelState s) {
    _state = s;
    notifyListeners();
  }

  /// Set state without the usual download flow (e.g. when discovering the
  /// model is already on disk during settings screen init).
  void markReadyIfOnDisk() {
    _state = ModelState.ready;
    notifyListeners();
  }

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

  /// Ensure the model file is on disk. Uses [HttpClient] with Range-based
  /// resume support for reliability on flaky networks.
  ///
  /// [onProgress] reports a 0.0–1.0 fraction as bytes stream in.
  Future<void> ensureModel({
    String url = _defaultUrl,
    void Function(double)? onProgress,
  }) async {
    final path = await modelPath();
    final f = File(path);
    if (await f.exists() && await f.length() > 100000000) {
      _setState(ModelState.ready);
      return;
    }

    _setState(ModelState.downloading);
    _downloadProgress = 0.0;
    notifyListeners();

    final client = HttpClient();
    try {
      // Resume support: send Range header for partial downloads.
      var existingBytes = 0;
      if (await f.exists()) {
        existingBytes = await f.length();
      }

      final req = await client.getUrl(Uri.parse(url));
      if (existingBytes > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }

      final resp = await req.close();

      // Critical: if server returns 200 (not 206 Partial Content) despite
      // our Range request, we must NOT append — that would corrupt the file.
      // Truncate and restart from zero.
      var received = 0;
      IOSink sink;
      if (existingBytes > 0 && resp.statusCode == 206) {
        received = existingBytes;
        sink = f.openWrite(mode: FileMode.append);
      } else {
        received = 0;
        sink = f.openWrite(mode: FileMode.write);
      }

      final expectedTotal = resp.statusCode == 206
          ? (resp.contentLength > 0
              ? resp.contentLength + existingBytes
              : 0)
          : (resp.contentLength > 0 ? resp.contentLength : 0);

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (expectedTotal > 0) {
          final fraction = (received / expectedTotal).clamp(0.0, 1.0);
          _downloadProgress = fraction;
          if (onProgress != null) onProgress(fraction);
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();

      if (received > 100000000) {
        _downloadProgress = null;
        _setState(ModelState.ready);
      } else {
        _downloadProgress = null;
        _setState(ModelState.failed);
        throw Exception('Download incomplete: only $received bytes received');
      }
    } catch (e) {
      _downloadProgress = null;
      _setState(ModelState.failed);
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
      throw StateError('Model is already initializing');
    }
    _initializing = true;
    _setState(ModelState.loading);
    try {
      final path = await modelPath();
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(path);
      _model = await FlutterGemmaPlugin.instance.init(
        maxTokens: 512,
        temperature: 0.2,
      );
      _setState(ModelState.ready);
      return _model!;
    } catch (e) {
      _setState(ModelState.failed);
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

  /// Whether the model is downloaded and ready for generation.
  /// Note: the model is loaded into RAM lazily by [generate].
  bool get isReady => _state == ModelState.ready;

  /// Whether the model is currently loading (downloading or initializing).
  bool get isLoading =>
      _state == ModelState.loading || _state == ModelState.downloading;

  /// Human-readable Bangla status for diagnostics UI.
  String get statusLabelBn {
    switch (_state) {
      case ModelState.notDownloaded:
        return 'ডাউনলোড প্রয়োজন';
      case ModelState.downloading:
        final pct = _downloadProgress != null
            ? '${(_downloadProgress! * 100).round()}%'
            : '';
        return 'ডাউনলোড হচ্ছে $pct';
      case ModelState.ready:
        return 'প্রস্তুত';
      case ModelState.loading:
        return 'প্রস্তুত হচ্ছে...';
      case ModelState.failed:
        return 'ব্যর্থ';
    }
  }
}

/// App-wide singleton. Use [modelManager] from anywhere.
final ModelManager modelManager = ModelManager();
