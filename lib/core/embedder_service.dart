import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/rag/embedding_models.dart' as emb;

import '../rag/embedder.dart';

/// Where the embedder model + tokenizer come from at install time.
///
/// Default (`network`) downloads from HuggingFace using an HF access token
/// (license-gated). `asset` reads pre-bundled files from
/// `android/app/src/main/assets/embeddinggemma/` — populated by
/// `tool/bundle_embedder.py` before a prebuilt APK build. The runtime
/// source is selected at compile time via `--dart-define` and read
/// once when [EmbedderService] is constructed.
enum EmbedderSource { network, asset }

/// Asset paths used when [EmbedderSource.asset] is selected. Kept as
/// constants so they stay in sync with [tool/bundle_embedder.py].
const String kEmbedderAssetModelPath = 'assets/embeddinggemma/model.tflite';
const String kEmbedderAssetTokenizerPath =
    'assets/embeddinggemma/sentencepiece.model';

/// Compile-time default read from `--dart-define=EMBEDDER_SOURCE=asset|network`.
/// Defaults to `network` when the flag is absent.
const EmbedderSource kDefaultEmbedderSource = bool.hasEnvironment('EMBEDDER_SOURCE')
    ? (String.fromEnvironment('EMBEDDER_SOURCE') == 'asset'
        ? EmbedderSource.asset
        : EmbedderSource.network)
    : EmbedderSource.network;

/// Lifecycle + status for the on-device semantic-search embedder
/// (EmbeddingGemma 300M, `.tflite` via flutter_gemma's LiteRT backend).
///
/// Mirrors [modelManager]'s shape (ChangeNotifier singleton) but stays
/// deliberately thin: two files (model + sentencepiece tokenizer), one
/// install path, no variant matrix, no resume logic — the plugin's
/// [EmbeddingInstallationBuilder] is idempotent and reports progress.
///
/// NOTE: the HuggingFace repos for EmbeddingGemma are license-gated
/// (`needsAuth: true` in the plugin's own registry), so downloads need a
/// HF token passed to [install]. Until a token (or an ungated mirror
/// URL) is configured, callers should treat the embedder as optional
/// and the app degrades to keyword retrieval exactly as before.
class EmbedderService extends ChangeNotifier {
  EmbedderService({
    @visibleForTesting bool Function()? hasActive,
    @visibleForTesting Future<EmbeddingModel> Function()? getActive,
    EmbedderSource source = kDefaultEmbedderSource,
  })  : _hasActive = hasActive ?? FlutterGemma.hasActiveEmbedder,
        _getActive = getActive ?? FlutterGemma.getActiveEmbedder,
        // ignore: prefer_initializing_formals
        _source = source;

  /// Where [install] pulls the model + tokenizer from. Defaults to the
  /// compile-time `--dart-define=EMBEDDER_SOURCE=asset|network` value;
  /// tests can override via the named parameter.
  EmbedderSource get source => _source;
  final EmbedderSource _source;

  /// Override hooks for unit tests; defaults to the live plugin calls.
  final bool Function() _hasActive;
  final Future<EmbeddingModel> Function() _getActive;

  EmbedderStatus _status = EmbedderStatus.unknown;
  String? _error;

  EmbedderStatus get status => _status;
  String? get error => _error;

  /// Probe the plugin for an installed embedder. Cheap (no model load);
  /// safe to call at startup.
  Future<void> refreshStatus() async {
    try {
      _status = _hasActive()
          ? EmbedderStatus.ready
          : EmbedderStatus.notInstalled;
      _error = null;
    } catch (e) {
      _status = EmbedderStatus.unknown;
      _error = '$e';
    }
    notifyListeners();
  }

  /// Return a live [Embedder] when one is installed, else null.
  /// Loads the tflite model (first call only — the plugin caches the
  /// active instance), so prefer calling this off the first frame.
  Future<Embedder?> createEmbedder() async {
    try {
      if (!_hasActive()) return null;
      final model = await _getActive();
      return EmbedderImpl(model);
    } catch (e) {
      debugPrint('[EmbedderService] getActiveEmbedder failed: $e');
      return null;
    }
  }

  /// Install the embedder and set it active. Idempotent — already-installed
  /// files are skipped by the plugin.
  ///
  /// Behavior depends on [source]:
  /// - [EmbedderSource.asset] reads pre-bundled files from
  ///   `assets/embeddinggemma/`. [hfToken] is ignored. This is what a
  ///   prebuilt APK uses; the user never has to do anything.
  /// - [EmbedderSource.network] (default) downloads from HuggingFace using
  ///   [hfToken]. The HF repos for EmbeddingGemma are license-gated, so
  ///   the caller must supply a valid token whose account has accepted
  ///   the model's license.
  ///
  /// [variant] is ignored in the asset path (the prebuilt APK ships one
  /// variant — typically the 4-bit quantization — chosen at build time).
  Future<void> install({
    String? hfToken,
    emb.EmbeddingModel variant = emb.EmbeddingModel.embeddingGemma300M,
    void Function(int progress)? onModelProgress,
    void Function(int progress)? onTokenizerProgress,
  }) async {
    _status = EmbedderStatus.installing;
    _error = null;
    notifyListeners();
    try {
      late final EmbeddingInstallationBuilder builder;
      switch (_source) {
        case EmbedderSource.asset:
          builder = FlutterGemma.installEmbedder()
              .modelFromAsset(kEmbedderAssetModelPath)
              .tokenizerFromAsset(kEmbedderAssetTokenizerPath);
        case EmbedderSource.network:
          builder = FlutterGemma.installEmbedder()
              .modelFromNetwork(variant.url, token: hfToken)
              .tokenizerFromNetwork(variant.tokenizerUrl, token: hfToken);
      }
      var withProgress = builder;
      if (onModelProgress != null) {
        withProgress = withProgress.withModelProgress(onModelProgress);
      }
      if (onTokenizerProgress != null) {
        withProgress = withProgress.withTokenizerProgress(onTokenizerProgress);
      }
      await withProgress.install();
      _status = EmbedderStatus.ready;
    } catch (e) {
      _status = EmbedderStatus.failed;
      _error = '$e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}

enum EmbedderStatus { unknown, notInstalled, installing, ready, failed }

/// App-wide singleton, mirroring `modelManager`.
final EmbedderService embedderService = EmbedderService();
