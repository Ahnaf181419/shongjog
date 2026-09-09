import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/rag/embedding_models.dart' as emb;

import '../rag/embedder.dart';

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
  })  : _hasActive = hasActive ?? FlutterGemma.hasActiveEmbedder,
        _getActive = getActive ?? FlutterGemma.getActiveEmbedder;

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

  /// Download + install the embedder and set it active. Idempotent —
  /// already-installed files are skipped by the plugin.
  ///
  /// [hfToken] is required by the gated HF repos (see class doc).
  /// [variant] defaults to the full-precision 300M (~300 MB); the 4-bit
  /// variant (~75 MB) is a reasonable pick for low-RAM devices.
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
      var builder = FlutterGemma.installEmbedder()
          .modelFromNetwork(variant.url, token: hfToken)
          .tokenizerFromNetwork(variant.tokenizerUrl, token: hfToken);
      if (onModelProgress != null) {
        builder = builder.withModelProgress(onModelProgress);
      }
      if (onTokenizerProgress != null) {
        builder = builder.withTokenizerProgress(onTokenizerProgress);
      }
      await builder.install();
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
