import 'dart:math' as math;

import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

/// Which task an embedding is for. Mirrors `flutter_gemma`'s `TaskType`
/// (the plugin prepends the canonical EmbeddingGemma prefix itself):
/// query → `task: search result | query: `,
/// document → `title: none | text: `.
enum EmbedTask { query, document }

/// Abstract interface — pure, no Flutter or plugin deps beyond the data
/// type. The retriever and ChatRepository code against this, so the
/// concrete impl can swap without touching inner layers.
abstract class Embedder {
  /// Output dimensionality of the embedder (e.g. 768 for EmbeddingGemma).
  /// Used by the retriever cache to detect a model swap that would produce
  /// silently-incompatible vectors against the cached corpus.
  Future<int> dim();

  Future<Float32List> embed(String text, {EmbedTask task});
}

/// EmbeddingGemma 300M client — embeds Bangla text into a 768-dim
/// L2-normalized vector for brute-force cosine retrieval.
///
/// flutter_gemma 1.3.2 exposes a real embedder API
/// (`FlutterGemma.installEmbedder()` / `getActiveEmbedder()` →
/// `EmbeddingModel.generateEmbedding`), resolving the old Phase 0 spike
/// question — this file used to throw `UnimplementedError`.
///
/// The adapter L2-normalizes whatever the plugin returns so the plain
/// dot product in [BruteForceRetriever] equals cosine similarity even if
/// a future backend forgets to normalize.
class EmbedderImpl implements Embedder {
  EmbedderImpl(this._model);

  final EmbeddingModel _model;

  @override
  Future<int> dim() => _model.getDimension();

  @override
  Future<Float32List> embed(String text,
      {EmbedTask task = EmbedTask.query}) async {
    final vector = await _model.generateEmbedding(
      text,
      taskType: task == EmbedTask.query
          ? TaskType.retrievalQuery
          : TaskType.retrievalDocument,
    );
    return normalize(Float32List.fromList(vector));
  }

  /// Scale [v] to unit length (on a copy). A zero vector is returned
  /// unchanged — cosine against it is meaningless either way, and
  /// dividing by 0 would poison the whole index.
  static Float32List normalize(Float32List v) {
    var sumSquares = 0.0;
    for (final x in v) {
      sumSquares += x * x;
    }
    final norm = math.sqrt(sumSquares);
    if (norm == 0.0 || norm == 1.0) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }
}
