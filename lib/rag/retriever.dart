import 'dart:typed_data';

import 'types.dart';

/// Brute-force cosine top-k retriever over a small on-device index.
///
/// At N≈23 vectors × 768 dims, brute force is O(N·D) ≈ 17k multiplies —
/// sub-millisecond on any phone (docs/architecture.md §2). No HNSW needed.
class BruteForceRetriever {
  final List<Chunk> chunks;
  final Float32List _flat; // row-major [N * D]
  final int _dim;

  BruteForceRetriever({required this.chunks, required Float32List vectors})
      : _flat = vectors,
        _dim = chunks.isEmpty ? 0 : (vectors.length ~/ chunks.length);

  /// Return the top-k chunks whose cosine similarity to [query] is ≥ [floor].
  ///
  /// Vectors are assumed L2-normalized at build time (docs/architecture.md
  /// §6), so the dot product equals cosine similarity directly.
  List<RetrievalHit> topK(Float32List query, {int k = 3, double floor = 0.35}) {
    if (chunks.isEmpty) return const [];
    assert(query.length == _dim,
        'query dim ${query.length} != index dim $_dim');
    final scores = List<double>.filled(chunks.length, 0.0);
    for (int i = 0; i < chunks.length; i++) {
      var dot = 0.0;
      final off = i * _dim;
      for (int j = 0; j < _dim; j++) {
        dot += _flat[off + j] * query[j];
      }
      scores[i] = dot;
    }
    final ranked = List<int>.generate(chunks.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final hits = <RetrievalHit>[];
    for (final idx in ranked.take(k)) {
      if (scores[idx] < floor) break;
      hits.add(RetrievalHit(chunks[idx], scores[idx]));
    }
    return hits;
  }
}