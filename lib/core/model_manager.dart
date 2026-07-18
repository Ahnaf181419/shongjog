import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shongjog/features/chat/local_llm.dart';

import 'device_capability.dart';

enum ModelState {
  notDownloaded,
  downloading,
  ready,
  loading,
  failed,
}

class ModelManager extends ChangeNotifier implements LocalLlm {
  static const _sizeTolerance = 0.99;

  /// Context window passed to getActiveModel(). `.litertlm` refuses to
  /// allocate tensors below 1024 (upstream #318) — this is NOT the reply cap.
  static const _kContextTokens = 1024;

  /// Reply-length cap, applied per session. Mirrors the 512 in docs/prd.md §8.
  static const _kMaxOutputTokens = 512;
  static const _kTemperature = 0.2;
  static const _kTopK = 40;

  /// Files written by the pre-1.x MediaPipe build. They are `.task`/`.bin`
  /// artifacts the LiteRT-LM engine cannot read (and the E2B one was a
  /// web/WASM build that never worked on Android), so they are dead weight —
  /// up to ~1.9 GB of it — and are deleted on first init.
  static const _deadLegacyFiles = <String>[
    'model.bin',
    'model_e2b.bin',
    'model_e4b.bin',
    'model_twelveb.bin',
    'gemma-4-E2B-it-web.task',
  ];

  /// Test-only override of path_provider's docs directory. Lets unit
  /// tests put files in a temporary directory instead of relying on the
  /// OS-default (which throws under `flutter test`). Production code
  /// leaves this null and uses `getApplicationDocumentsDirectory()`.
  @visibleForTesting
  static String? debugFilesDirOverride;

  /// Test-only override of the size floor used by [isOnDisk]. Real
  /// production compares `f.length() >= 0.99 * DeviceCapability.sizeBytes`
  /// which means tests would have to write ~1.85 GB of zeros to mark a
  /// variant "ready". Bypass this by setting `debugSizeFloorOverride` to
  /// a small value (e.g. 1 byte); then any non-empty file is "ready".
  @visibleForTesting
  static int? debugSizeFloorOverride;

  ModelVariant _activeVariant = ModelVariant.e2b;
  ModelVariant get activeVariant => _activeVariant;

  final Map<ModelVariant, ModelState> _states = {
    ModelVariant.e2b: ModelState.notDownloaded,
    ModelVariant.e4b: ModelState.notDownloaded,
    ModelVariant.twelveb: ModelState.notDownloaded,
  };

  final Map<ModelVariant, double?> _progress = {
    ModelVariant.e2b: null,
    ModelVariant.e4b: null,
    ModelVariant.twelveb: null,
  };

  InferenceModel? _model;
  Future<InferenceModel>? _initFuture;

  /// Optional LoRA adapter path. When set, `createSession` passes it to
  /// the SDK via `loraPath:`. Hot-swappable — see [setLoraAdapter] /
  /// [clearLoraAdapter]. Stored per-session so it can be toggled without
  /// reloading the 2.5 GB base model.
  String? _loraPath;
  String? get loraPath => _loraPath;

  /// Per-query thinking mode override. When non-null, `createSession`
  /// receives `enableThinking: _enableThinking`. Used by the urgency
  /// classifier (Phase 3) to route reflex vs. deliberation.
  bool? _enableThinking;

  /// Why the last on-device load failed, or null if it never has.
  ///
  /// Tier 2 degrades silently to corpus answers by design, which makes a
  /// broken offline model indistinguishable from a working one on a phone
  /// with no logcat attached. Settings → ডায়াগনস্টিকস surfaces this string.
  String? _lastInitError;
  String? get lastInitError => _lastInitError;

  /// Per-variant single-flight: concurrent callers to ensureModel() for the
  /// same variant share one download future, preventing two IOSinks from
  /// appending to the same file simultaneously.
  final Map<ModelVariant, Future<void>> _downloadFutures = {};

  ModelState get state => _states[_activeVariant]!;
  double? get downloadProgress => _progress[_activeVariant];

  ModelState getState(ModelVariant v) => _states[v]!;
  double? getProgress(ModelVariant v) => _progress[v];

  /// True if any variant is currently downloading. Used by the Home AppBar
  /// chip to surface background downloads without being on Settings.
  bool get isAnyVariantDownloading =>
      _states.values.any((s) => s == ModelState.downloading);

  /// Progress (0.0–1.0) of the first variant currently downloading, or null.
  double? get activeDownloadProgress {
    for (final v in ModelVariant.values) {
      if (_states[v] == ModelState.downloading) return _progress[v];
    }
    return null;
  }

  void _setState(ModelVariant v, ModelState s) {
    _states[v] = s;
    notifyListeners();
  }

  void _setProgress(ModelVariant v, double? p) {
    _progress[v] = p;
    // NOTE: does NOT call notifyListeners() here. The download loop in
    // ensureModel() has its own throttled notify (1/sec + on percent-change)
    // to avoid UI jank during the ~1.87 GB download. Terminal _setProgress
    // calls (completion/failure) are always followed by _setState(), which
    // does notify. Calling notify here on every TCP chunk defeats the throttle.
  }

  /// Each variant is stored under its own name and loaded in place — the
  /// LiteRT-LM engine takes an absolute path, so there is no magic filename
  /// to satisfy and no copy step (contrast with the old MediaPipe path, which
  /// hard-checked for `model.bin`).
  Future<String> _pathForVariant(ModelVariant v) async {
    final dir = debugFilesDirOverride ??
        (await getApplicationDocumentsDirectory()).path;
    return '$dir/model_${v.name}.litertlm';
  }

  Future<String> _filesDir() async =>
      debugFilesDirOverride ?? (await getApplicationDocumentsDirectory()).path;

  /// Mark [v] ready only after verifying a complete file is on disk.
  Future<void> markReadyIfOnDisk(ModelVariant v) async {
    try {
      if (await isOnDisk(v)) _setState(v, ModelState.ready);
    } catch (_) {
      // Disk probe unavailable (web / tests) — leave state unchanged.
    }
  }

  Future<bool> isOnDisk(ModelVariant v) async {
    final path = await _pathForVariant(v);
    final f = File(path);
    if (!await f.exists()) return false;

    final len = await f.length();
    if (debugSizeFloorOverride != null) {
      return len >= debugSizeFloorOverride!;
    }

    final recs = await DeviceCapability.getRecommendations();
    final rec = recs.firstWhere((r) => r.variant == v);

    return len >= (rec.sizeBytes * _sizeTolerance).round();
  }
  
  @override
  Future<bool> isAnyOnDisk() async {
    for (final v in ModelVariant.values) {
      if (await isOnDisk(v)) return true;
    }
    return false;
  }

  Future<void> ensureModel({
    ModelVariant? variant,
    void Function(double)? onProgress,
  }) async {
    final v = variant ?? _activeVariant;

    // Single-flight: concurrent callers share one download future so two
    // IOSinks never append to the same file. The map is populated
    // synchronously (before the first await in _doEnsureModel), so the
    // second caller always sees the stored future.
    final existing = _downloadFutures[v];
    if (existing != null) return existing;

    final fut = _doEnsureModel(v, onProgress: onProgress);
    _downloadFutures[v] = fut;
    try {
      await fut;
    } finally {
      _downloadFutures.remove(v);
    }
  }

  Future<void> _doEnsureModel(
    ModelVariant v, {
    void Function(double)? onProgress,
  }) async {
    final recs = await DeviceCapability.getRecommendations();
    final rec = recs.firstWhere((r) => r.variant == v);
    if (!rec.available) {
      throw StateError('Variant ${v.name} is not available for download.');
    }

    final path = await _pathForVariant(v);
    final f = File(path);
    if (await f.exists() && await f.length() >= (rec.sizeBytes * _sizeTolerance).round()) {
      _setState(v, ModelState.ready);
      await _activate(v);
      return;
    }

    _setState(v, ModelState.downloading);
    _setProgress(v, 0.0);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    try {
      var existingBytes = 0;
      if (await f.exists()) {
        existingBytes = await f.length();
      }

      final req = await client.getUrl(Uri.parse(rec.downloadUrl));
      if (existingBytes > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }

      final resp = await req.close();

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
          ? (resp.contentLength > 0 ? resp.contentLength + existingBytes : 0)
          : (resp.contentLength > 0 ? resp.contentLength : 0);

      var lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
      var lastNotifiedPercent = -1;

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (expectedTotal > 0) {
          final fraction = (received / expectedTotal).clamp(0.0, 1.0);
          _setProgress(v, fraction);
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

      if (received >= (rec.sizeBytes * _sizeTolerance).round()) {
        _setProgress(v, null);
        _setState(v, ModelState.ready);
        await _activate(v);
      } else {
        _setProgress(v, null);
        _setState(v, ModelState.failed);
        throw Exception('Download incomplete: $received bytes (expected ~${rec.sizeBytes})');
      }
    } catch (e) {
      _setProgress(v, null);
      _setState(v, ModelState.failed);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<InferenceModel> initialize() async {
    if (_model != null) return _model!;
    // Single-flight: concurrent callers await the same init instead of one
    // of them getting a StateError and silently degrading to corpus text.
    final fut = _initFuture ??= _doInitialize();
    try {
      return await fut;
    } catch (_) {
      if (identical(_initFuture, fut)) _initFuture = null;
      rethrow;
    }
  }

  Future<InferenceModel> _doInitialize() async {
    await _purgeIncompatibleLegacyFiles();

    if (!await isOnDisk(_activeVariant)) {
      // The active variant may never have been downloaded: auto-select
      // recommends by RAM tier, not by what is on disk. Fall back to any
      // fully downloaded variant rather than refusing to answer offline.
      final downloaded = await getDownloadedVariants();
      if (downloaded.isEmpty) {
        throw Exception('No model variant is downloaded fully.');
      }
      // Switch WITHOUT resetSession(): nulling _initFuture mid-flight would
      // let a concurrent initialize() start a second native init.
      await _setActiveVariantOnly(downloaded.first);
    }
    final v = _activeVariant;

    _setState(v, ModelState.loading);
    try {
      final variantPath = await _pathForVariant(v);

      // Register the already-downloaded file with the plugin. `.fromFile()` is
      // instant — the FileSourceHandler only records the path, it does not
      // copy, so a 2.5 GB model costs no extra disk. install() also marks this
      // spec active, which is what getActiveModel() below resolves.
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(variantPath).install();

      // maxTokens here is the CONTEXT WINDOW, not the reply length. It must be
      // >= 1024: `.litertlm` fails to allocate tensors below that (upstream
      // #318), so the old MediaPipe-era 512 would break outright. Reply length
      // is capped per-session via maxOutputTokens in [generate].
      _model = await FlutterGemma.getActiveModel(maxTokens: _kContextTokens)
          .timeout(
        // Documented cold start is 3–10s on arm64 (docs/spike-results.md);
        // 60s is a generous ceiling that still fails fast enough for a user
        // waiting on a chat reply.
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
            'flutter_gemma init timed out for ${v.name} at $variantPath'),
      );
      _lastInitError = null;
      _setState(v, ModelState.ready);
      return _model!;
    } catch (e) {
      _model = null;
      _lastInitError = '${v.name}: $e';
      debugPrint('[ModelManager] init failed for ${v.name}: $e');
      _setState(v, ModelState.failed);
      rethrow;
    }
  }

  /// Make [v] the active variant so the next generate() loads it.
  ///
  /// Downloading implies intent to use: without this, autoSelectBestModel()'s
  /// RAM-tier recommendation stays active while the variant the user actually
  /// downloaded sits unused and initialize() refuses to start.
  Future<void> _activate(ModelVariant v) async {
    if (_activeVariant != v) {
      await resetSession();
    }
    await _setActiveVariantOnly(v);
  }

  /// Record [v] as active without touching the model session. Safe to call
  /// from inside _doInitialize(), where resetSession() must not run.
  Future<void> _setActiveVariantOnly(ModelVariant v) async {
    _activeVariant = v;
    await _saveActiveVariant();
    notifyListeners();
  }

  /// Delete pre-1.x MediaPipe artifacts.
  ///
  /// They are `.task`/`.bin` files the LiteRT-LM engine cannot read, so there
  /// is nothing to migrate — only ~1.9 GB to reclaim on devices that ran the
  /// old build. Best-effort: a failure here must never block inference.
  Future<void> _purgeIncompatibleLegacyFiles() async {
    try {
      final dir = await _filesDir();
      for (final name in _deadLegacyFiles) {
        final f = File('$dir/$name');
        if (await f.exists()) {
          debugPrint('[ModelManager] removing incompatible legacy file: $name');
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('[ModelManager] legacy purge skipped: $e');
    }
  }

  /// Set a LoRA adapter path. Subsequent [generate] calls will pass it
  /// to `createSession(loraPath: ...)`. Does NOT reload the base model —
  /// the adapter is lightweight and applied per-session.
  void setLoraAdapter(String path) {
    _loraPath = path;
    notifyListeners();
  }

  /// Remove the LoRA adapter. Reverts to base model behavior.
  void clearLoraAdapter() {
    _loraPath = null;
    notifyListeners();
  }

  /// Override the thinking mode for the next [generate] call. Set to
  /// null to use the SDK default (thinking off). Used by the urgency
  /// classifier — critical queries get thinking=false (reflex), complex
  /// queries get thinking=true (deliberation).
  @override
  void setThinkingMode(bool? enable) {
    _enableThinking = enable;
  }

  @override
  Future<String> generate(String prompt) async {
    final model = await initialize();
    // A fresh session per query: each ask() is single-shot RAG (the prompt
    // already carries its context), so leftover KV-cache history would only
    // bias the next answer. Sessions are cheap — the weights stay loaded.
    final session = await model.createSession(
      temperature: _kTemperature,
      topK: _kTopK,
      // Caps GENERATED tokens without shrinking the context window, which
      // `.litertlm` requires to stay >= 1024. Preserves the short-answer
      // intent of the documented run config (docs/prd.md §8).
      maxOutputTokens: _kMaxOutputTokens,
      // LoRA adapter — null means base model only.
      loraPath: _loraPath,
      // Thinking mode — only override when explicitly set; SDK default
      // is thinking off.
      enableThinking: _enableThinking ?? false,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await session.getResponse();
    } finally {
      // Native sessions hold a KV cache; leaking them exhausts memory after a
      // handful of questions on a low-RAM phone.
      await session.close();
    }
  }

  @override
  bool get isReady => state == ModelState.ready;

  /// Drop the loaded model, closing the native engine handle.
  ///
  /// close() is NOT optional: the weights are mmap'd natively (2.5 GB for E2B,
  /// 3.5 GB for E4B) and closing is also what lets flutter_gemma's core reset
  /// its singleton bookkeeping (see InferenceModel.addCloseListener). Merely
  /// nulling the Dart reference would leave the old variant resident while the
  /// next getActiveModel() loads another one — an OOM on any phone.
  Future<void> resetSession() async {
    final old = _model;
    _model = null;
    _initFuture = null;
    // Don't reset states of downloaded files
    if (old != null) {
      try {
        await old.close();
      } catch (e) {
        debugPrint('[ModelManager] close failed (continuing): $e');
      }
    }
  }

  Future<void> reset() async {
    await resetSession();
    _states[_activeVariant] = ModelState.notDownloaded;
    notifyListeners();
  }

  Future<void> deleteVariant(ModelVariant v) async {
    try {
      // Close BEFORE unlinking: the engine has this file mmap'd, and on
      // Android the inode would otherwise stay alive (holding the disk the
      // user is trying to reclaim) until the handle is dropped.
      if (_activeVariant == v) await resetSession();

      final path = await _pathForVariant(v);
      final f = File(path);
      if (await f.exists()) await f.delete();

      _setState(v, ModelState.notDownloaded);
    } catch (e) {
      debugPrint('Failed to delete variant: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Auto-select & initialization
  // ════════════════════════════════════════════════════════════════

  /// Auto-select the best model for this device on first run.
  ///
  /// Checks SharedPreferences for a previously saved variant preference.
  /// If none, selects the recommended variant based on hardware tier.
  /// If the recommended model is already on disk, marks it ready.
  ///
  /// Fallback: if the saved variant is missing OR the recommended
  /// variant isn't on disk, look for ANY fully-downloaded variant on
  /// disk and activate it. Without this, the previous logic pointed
  /// _activeVariant at a variant with no file, _states stayed
  /// notDownloaded, the appbar showed "অফলাইন (তথ্যকোষ)" even though a
  /// usable model file existed, and the only way to recover was a
  /// manual settings-page tap.
  Future<void> autoSelectBestModel() async {
    // Reclaim pre-1.x MediaPipe files at boot rather than waiting for the
    // first chat message — they are unreadable now and cost ~1.9 GB.
    await _purgeIncompatibleLegacyFiles();

    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('active_model_variant');

    if (savedIndex != null && savedIndex < ModelVariant.values.length) {
      final saved = ModelVariant.values[savedIndex];
      if (await isOnDisk(saved)) {
        _activeVariant = saved;
        _setState(saved, ModelState.ready);
        return;
      }
    }

    // First run (no saved pref), or saved variant was deleted: pick the
    // recommended variant by hardware tier.
    final recommended = await DeviceCapability.getRecommendedVariant();
    if (await isOnDisk(recommended)) {
      _activeVariant = recommended;
      _setState(recommended, ModelState.ready);
      notifyListeners();
      return;
    }

    // Last resort: any fully-downloaded variant. The on-disk variant
    // list is ordered (e2b, e4b, twelveb) so e2b wins ties — the
    // cheapest option. Without this, _activeVariant points at the
    // recommended tier without a file, _states stays notDownloaded,
    // and the user's offline AI is silently unreachable.
    final downloaded = <ModelVariant>[];
    for (final v in ModelVariant.values) {
      if (await isOnDisk(v)) downloaded.add(v);
    }
    if (downloaded.isNotEmpty) {
      _activeVariant = downloaded.first;
      _setState(downloaded.first, ModelState.ready);
    } else {
      // No file on disk; keep recommended as the "intent" so the
      // download UI knows what to suggest.
      _activeVariant = recommended;
    }
    notifyListeners();
  }

  /// Save the current active variant to SharedPreferences.
  Future<void> _saveActiveVariant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_model_variant', _activeVariant.index);
  }

  Future<void> setActiveVariant(ModelVariant v) async {
    if (_activeVariant == v) return;
    // Unload the current variant before switching, or both sets of weights
    // sit in memory at once.
    await resetSession();
    _activeVariant = v;
    await _saveActiveVariant();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════
  //  Storage management
  // ════════════════════════════════════════════════════════════════

  /// Get total bytes used by all downloaded model files.
  Future<int> getStorageUsedBytes() async {
    int total = 0;
    for (final v in ModelVariant.values) {
      try {
        final path = await _pathForVariant(v);
        final f = File(path);
        if (await f.exists()) {
          total += await f.length();
        }
      } catch (e) { debugPrint("[Catch] model_manager: $e"); }
    }
    // No second copy to count any more: the engine loads each variant in
    // place, so the per-variant files above are the whole footprint.
    return total;
  }

  /// Get which variants are currently downloaded on disk.
  Future<List<ModelVariant>> getDownloadedVariants() async {
    final downloaded = <ModelVariant>[];
    for (final v in ModelVariant.values) {
      if (await isOnDisk(v)) {
        downloaded.add(v);
      }
    }
    return downloaded;
  }

  /// Get the size of a specific variant on disk (0 if not downloaded).
  Future<int> getVariantSizeBytes(ModelVariant v) async {
    try {
      final path = await _pathForVariant(v);
      final f = File(path);
      if (await f.exists()) return await f.length();
    } catch (e) { debugPrint("[Catch] model_manager: $e"); }
    return 0;
  }

  bool get isLoading =>
      state == ModelState.loading || state == ModelState.downloading;

  String get statusLabelBn {
    switch (state) {
      case ModelState.notDownloaded:
        return 'ডাউনলোড প্রয়োজন';
      case ModelState.downloading:
        final pct = downloadProgress != null
            ? '${(downloadProgress! * 100).round()}%'
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

  /// Test-only: simulate a variant being mid-download at [progress].
  /// Lets widget tests drive the Home AppBar chip without a real 1.87 GB
  /// download.
  @visibleForTesting
  void debugSetDownloadingState(ModelVariant v, double progress) {
    _states[v] = ModelState.downloading;
    _progress[v] = progress;
    notifyListeners();
  }

  /// Test-only: clear a simulated downloading state.
  @visibleForTesting
  void debugClearDownloadingState(ModelVariant v) {
    _states[v] = ModelState.notDownloaded;
    _progress[v] = null;
    notifyListeners();
  }
}

final ModelManager modelManager = ModelManager();
