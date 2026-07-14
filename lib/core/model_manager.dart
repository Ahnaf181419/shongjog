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
/// into the MediaPipe LlmInference runtime (via flutter_gemma).
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
///
/// **Filename constraint:** The file MUST be named `model.bin`. This is
/// because `flutter_gemma` 0.5.1's `MobileModelManager.isModelLoaded`
/// hard-checks for the constant `_modelPath = 'model.bin'` at the app
/// docs directory — NOT the path passed to `setModelPath()`. If the file
/// is named anything else, `init()` throws "Gemma Model is not loaded
/// yet" even though the file is on disk and the path was set correctly.
class ModelManager extends ChangeNotifier {
  /// MUST be 'model.bin' — see class doc comment.
  static const _modelFileName = 'model.bin';

  /// Previous filename used before the flutter_gemma compatibility fix.
  /// Used by [_migrateOldFilename] to rename existing downloads.
  static const _legacyFileName = 'gemma-4-E2B-it-web.task';

  /// LiteRT-community mirror of Gemma 4 E2B IT (MediaPipe .task format,
  /// int4 quantized). Verified accessible (HTTP 302 → CDN, no auth required).
  /// Actual file size: ~1.87 GB (2,003,697,664 bytes).
  static const _defaultUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.task';

  /// Known size of the model file (bytes). Used by [isOnDisk] to detect
  /// partial downloads. Sourced from HF Content-Length header.
  /// ~1.87 GB = 2,003,697,664 bytes.
  static const _expectedModelSize = 2003697664;

  /// Tolerance fraction for size check — file within 99% of expected is
  /// considered complete (handles minor CDN re-encoding differences).
  static const _sizeTolerance = 0.99;

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

  /// True if a model file matching the expected size is on disk.
  /// Uses [_expectedModelSize] with 99% tolerance to detect partial
  /// downloads — a file at 60% completion would be ~1.2 GB, well below
  /// the 99% threshold (~1.98 GB), so it's correctly rejected.
  Future<bool> isOnDisk() async {
    final f = File(await modelPath());
    if (!await f.exists()) return false;
    final len = await f.length();
    return len >= (_expectedModelSize * _sizeTolerance).round();
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
    if (await f.exists() &&
        await f.length() >= (_expectedModelSize * _sizeTolerance).round()) {
      _setState(ModelState.ready);
      return;
    }

    _setState(ModelState.downloading);
    _downloadProgress = 0.0;
    notifyListeners();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
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

      // Throttle notifyListeners to avoid flooding the UI with rebuilds
      // (~100k chunks for a 1.87 GB file). Notify at most once per second,
      // plus on every whole-percent boundary for smooth progress bar.
      var lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
      var lastNotifiedPercent = -1;

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (expectedTotal > 0) {
          final fraction = (received / expectedTotal).clamp(0.0, 1.0);
          _downloadProgress = fraction;
          if (onProgress != null) onProgress(fraction);

          final now = DateTime.now();
          final currentPercent = (fraction * 100).floor();
          if (now.difference(lastNotifyTime) >= const Duration(seconds: 1) ||
              currentPercent != lastNotifiedPercent) {
            lastNotifyTime = now;
            lastNotifiedPercent = currentPercent;
            notifyListeners();
          }
        }
      }
      await sink.flush();
      await sink.close();

      // Completion check: compare against expected size with tolerance.
      if (received >= (_expectedModelSize * _sizeTolerance).round()) {
        _downloadProgress = null;
        _setState(ModelState.ready);
      } else {
        _downloadProgress = null;
        _setState(ModelState.failed);
        throw Exception(
            'Download incomplete: $received bytes (expected ~$_expectedModelSize)');
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
  ///
  /// On failure, the model file is deleted so the user can re-download
  /// cleanly instead of getting stuck in a "ready → failed → ready" loop
  /// with a corrupted/partial file.
  Future<InferenceModel> initialize() async {
    if (_model != null) return _model!;
    if (_initializing) {
      throw StateError('Model is already initializing');
    }
    _initializing = true;
    _setState(ModelState.loading);
    try {
      await _migrateOldFilename();
      final path = await modelPath();
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(path);
      _model = await FlutterGemmaPlugin.instance.init(
        maxTokens: 512,
        temperature: 0.2,
      );
      _setState(ModelState.ready);
      return _model!;
    } catch (e) {
      // Delete the model file on failure so a corrupted/partial file
      // doesn't cause a permanent "ready → failed" loop on every relaunch.
      // The user will see "ডাউনলোড প্রয়োজন" and can re-download.
      try {
        final path = await modelPath();
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      _model = null;
      _setState(ModelState.failed);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// One-time migration: if a file under the legacy name exists, rename it
  /// to the current [_modelFileName]. Handles devices that downloaded
  /// before the filename fix.
  Future<void> _migrateOldFilename() async {
    final dir = await getApplicationDocumentsDirectory();
    final oldFile = File('${dir.path}/$_legacyFileName');
    if (await oldFile.exists()) {
      final newFile = File('${dir.path}/$_modelFileName');
      if (await newFile.exists()) {
        await newFile.delete();
      }
      await oldFile.rename('${dir.path}/$_modelFileName');
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

  /// Drop the in-memory session and return the manager to [ModelState.notDownloaded].
  /// Does NOT delete the on-disk model file — pair with a [File.delete] on
  /// [modelPath] if the caller wants a clean slate.
  void reset() {
    _model = null;
    _initializing = false;
    _downloadProgress = null;
    _setState(ModelState.notDownloaded);
  }

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
