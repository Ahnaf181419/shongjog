import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import 'package:shongjog/features/chat/local_llm.dart';
import 'package:shongjog/rag/repetition_detector.dart';

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
  static const kContextTokens = 1024;

  /// Whether the active engine can separate the model's internal "thought"
  /// channel from its user-visible answer. On the `.litertlm` FFI path it
  /// CANNOT: `enableThinking: true` only injects `{"enable_thinking": true}`
  /// into the prompt template (flutter_gemma_litertlm 1.1.0,
  /// ffi_inference_model.dart:631) and the engine then streams the raw
  /// `<|channel|>thought …` tokens straight into the response string. There
  /// is no "final channel" API to read the answer back out of.
  ///
  /// The result is the bug in `docs/image.png`: the whole bubble is
  /// `<|channel|>thought Thinking<|channel|>…`. Because that garbage starts
  /// at index 0, [ChatRepository.truncateAtTurnMarker] cuts the entire
  /// string away and the user gets a blank bubble instead.
  ///
  /// So thinking stays OFF until the engine grows real channel separation.
  /// [setThinkingMode] still records the caller's intent (the urgency badge
  /// in the UI reads it) — it just can't reach the SDK yet.
  static const bool kThinkingModeSupported = false;

  /// A seed the native sampler will actually accept.
  ///
  /// `LiteRtLmSamplerParams.seed` is `@ffi.Int32()`
  /// (litert_lm_bindings.dart:2028). `DateTime.now().microsecondsSinceEpoch`
  /// is ~1.78e15, ~830,000x over the Int32 max, and Dart FFI stores it by
  /// silently truncating to the low 32 bits *signed* — so the seed handed to
  /// native flips negative for ~35.8 minutes out of every 71.6 (the period of
  /// bit 31 of a microsecond counter). Masking with 0x7FFFFFFF keeps the
  /// low-order entropy that makes each call differ while guaranteeing a
  /// non-negative, in-range value.
  @visibleForTesting
  static int nextRandomSeed() =>
      DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  /// Reply-length cap, applied per session. Kept small to (a) speed up
  /// generation — a 2B model at 512 tokens runs ~5-8s with most
  /// tokens being degenerate, and (b) prevent the model from
  /// wandering into repetition loops after producing a valid answer,
  /// because the SDK has no `stopStrings` API on the .litertlm path.
  /// 256 is enough for the longest grounded emergency answer
  /// (numbered steps + warning signs + 999 escalation) with headroom.
  static const int kMaxOutputTokens = 256;

  /// Sampling temperature. 0.2 was too greedy — at low temp with high
  /// topK, the model could pick a token that started a loop and then
  /// keep picking it. 0.3 is still grounded (RAG context dominates)
  /// but adds enough variation to break out of degenerate sequences.
  static const double kTemperature = 0.3;

  /// Top-K sampling. 40 is the LiteRT-LM Gemma 4 default and is
  /// appropriate for grounded RAG — we don't want the model picking
  /// from the long tail of the vocabulary when an answerable chunk
  /// is right there in context.
  static const int kTopK = 40;

  /// Nucleus sampling (top-P). The SDK supports it via [topP]. We
  /// cap the cumulative probability at 0.95 as a safety net on top
  /// of [kTopK]: even if topK keeps a low-prob token in the pool,
  /// topP excludes it once the high-prob tokens cover 95% of mass.
  /// This is the single most effective knob for preventing the
  /// "long random same texts" symptom users reported, because
  /// repetition loops almost always start from a low-prob tail pick.
  static const double kTopP = 0.95;

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
      _model = await FlutterGemma.getActiveModel(maxTokens: kContextTokens)
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

  /// The thinking flag actually handed to the SDK. Gated by
  /// [kThinkingModeSupported] so the caller's intent is recorded but never
  /// reaches an engine that would leak the thought channel as visible text.
  bool get _effectiveThinking =>
      kThinkingModeSupported && (_enableThinking ?? false);

  @override
  Future<String> generate(String prompt) async {
    final model = await initialize();
    // A fresh session per query: each ask() is single-shot RAG (the prompt
    // already carries its context), so leftover KV-cache history would only
    // bias the next answer. Sessions are cheap — the weights stay loaded.
    //
    // randomSeed: the SDK defaults to 1, which means identical prompts
    // produce byte-identical degenerate output across runs — the
    // "long random same texts" symptom. A fresh random seed per call
    // guarantees variation even when the model is deterministic at
    // temperature 0.
    final session = await model.createSession(
      temperature: kTemperature,
      topK: kTopK,
      // Nucleus sampling — safety net against repetition loops.
      // See [kTopP] doc for rationale.
      topP: kTopP,
      // Fresh seed per call. Without this the SDK's default of 1 makes
      // every query with the same prompt return the exact same degenerate
      // output. Random seed + temperature 0.3 gives controlled variation.
      // Must go through [nextRandomSeed] — the native field is Int32 and
      // a raw microsecond timestamp truncates to a negative value half
      // the time. See [nextRandomSeed].
      randomSeed: nextRandomSeed(),
      // Caps GENERATED tokens without shrinking the context window, which
      // `.litertlm` requires to stay >= 1024. 256 is enough for the
      // longest grounded emergency answer; lower than 512 because
      // greedy sampling at low temp produces degenerate output as it
      // runs out of real content to generate.
      maxOutputTokens: kMaxOutputTokens,
      // LoRA adapter — null means base model only.
      loraPath: _loraPath,
      // Forced off on the .litertlm path — the engine has no channel
      // separation, so turning this on leaks the raw thought stream into
      // the answer. See [kThinkingModeSupported].
      enableThinking: _effectiveThinking,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      // Blocking getResponse() — the streaming + early-stop approach
      // (commit 016daf2) caused blank replies on real hardware because
      // stopGeneration() was killing the session before meaningful
      // content landed. The blocking call is slower but RELIABLE: it
      // always returns the full response. Repetition loops are trimmed
      // post-hoc by ChatRepository.truncateAtTurnMarker + the safe
      // repetition trim below — neither of which can return empty.
      final raw = await session.getResponse();
      return _safeTrimRepetition(raw);
    } finally {
      // Native sessions hold a KV cache; leaking them exhausts memory after a
      // handful of questions on a low-RAM phone.
      await session.close();
    }
  }

  /// Trim trailing repetition loops from [raw] WITHOUT ever returning
  /// empty. If the trim would produce an empty string, return the raw
  /// input unchanged — a degenerate answer is strictly better than a
  /// blank bubble.
  ///
  /// Uses [RepetitionDetector.trimmed] when it yields a non-empty
  /// result; otherwise falls back to the raw string. This is a safety
  /// net layered below ChatRepository.truncateAtTurnMarker (which
  /// handles turn markers / channel leaks).
  static String _safeTrimRepetition(String raw) {
    if (raw.trim().isEmpty) return raw;
    try {
      final detector = RepetitionDetector();
      detector.feed(raw);
      if (!detector.shouldStop) return raw;
      final trimmed = detector.trimmed();
      // The golden rule: NEVER return empty. If the detector fired too
      // early (false positive on a short or repetitive-but-valid answer)
      // and trimmed() wiped the whole thing, fall back to the raw text.
      // A user seeing "আমি আমি আমি" can retry; a user seeing blank
      // thinks the app is broken.
      return trimmed.trim().isEmpty ? raw : trimmed;
    } catch (_) {
      return raw;
    }
  }

  /// Run inference with function-calling for structured SOS extraction.
  /// Returns the raw SDK JSON response containing the tool call args.
  /// Returns null if the session doesn't expose RawSdkResponseSession
  /// or if generation fails (caller should fall back to manual entry).
  @override
  Future<String?> generateStructured({
    required String prompt,
    required List<Tool> tools,
  }) async {
    final model = await initialize();
    final session = await model.createSession(
      temperature: kTemperature,
      topK: kTopK,
      topP: kTopP,
      maxOutputTokens: kMaxOutputTokens,
      tools: tools,
      loraPath: _loraPath,
      enableThinking: _effectiveThinking,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      await session.getResponse();
      // Read the raw SDK JSON to extract the tool call arguments.
      if (session is RawSdkResponseSession) {
        return session.lastRawResponse;
      }
      return null;
    } catch (e) {
      debugPrint('[ModelManager/generateStructured] failed: $e');
      return null;
    } finally {
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

  String statusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state) {
      case ModelState.notDownloaded:
        return l10n.modelStatusNotDownloaded;
      case ModelState.downloading:
        final pct = downloadProgress != null
            ? '${(downloadProgress! * 100).round()}%'
            : '';
        return l10n.modelStatusDownloading(pct);
      case ModelState.ready:
        return l10n.modelStatusReady;
      case ModelState.loading:
        return l10n.modelStatusLoading;
      case ModelState.failed:
        return l10n.modelStatusFailed;
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
