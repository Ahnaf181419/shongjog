import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'embedder.dart';
import 'retriever.dart';
import 'types.dart';

/// Semantic retriever over an on-device [Embedder] (EmbeddingGemma 300M).
///
/// Owns the corpus-side vector index that the bundled `vectors.bin`
/// cannot provide: those vectors were built offline with mpnet
/// (`tools/build_kb.py`), and an EmbeddingGemma *query* vector is not
/// cosine-compatible with an mpnet *document* vector — different models,
/// different vector spaces. So the first time this retriever runs it
/// re-embeds all 48 corpus chunks with the same on-device embedder
/// (document task type), L2-normalized, and persists the result to a
/// private cache file. Later launches load the cache in ~1 ms and never
/// touch the embedder until the corpus changes.
///
/// Retrieval itself is delegated to the existing [BruteForceRetriever]
/// (pure Dart, sub-millisecond at N=48 × 768 dims).
class EmbeddingRetriever {
  EmbeddingRetriever({
    required this.embedder,
    required this.chunks,
    this.cacheFile,
    this.floor = 0.35,
  });

  /// The embedder used for BOTH document indexing and queries — same
  /// model, same vector space, or cosine scores are garbage.
  final Embedder embedder;

  final List<Chunk> chunks;

  /// Optional persistent cache for the document vectors. When null the
  /// index is rebuilt (48 embeds) on every launch — still correct, just
  /// slower, and the right default for tests.
  ///
  /// Callers should derive the filename from [cacheFilename] so a model swap
  /// (different `dim`) writes to a distinct file instead of corrupting the
  /// prior cache.
  final File? cacheFile;

  /// Stable, dim-derived cache filename inside an app docs dir.
  /// Example: `kb_vectors_embeddinggemma_d768.bin`. Use with `getApplicationDocumentsDirectory()`.
  /// Callers should `await embedder.dim()` first (cached inside the embedder impl).
  static String cacheFilename(int dim) =>
      'kb_vectors_embeddinggemma_d$dim.bin';

  /// Minimum cosine similarity for a hit. Passed through to
  /// [BruteForceRetriever.topK].
  final double floor;

  BruteForceRetriever? _index;
  Future<bool>? _building;

  /// Cache format: `SJEG` magic + int32 chunkCount + int32 dim +
  /// count×dim float32, little-endian, row-major.
  static const int _kHeaderBytes = 4 + 4 + 4;

  /// Whether the index is loaded/built and [topK] can run without
  /// embedding documents first (a query still embeds, of course).
  bool get isReady => _index != null;

  /// Build the index from the disk cache or, when the cache is absent or
  /// stale (chunk count changed), by embedding every chunk once.
  ///
  /// Single-flight: concurrent callers share one build. A failed build
  /// resets so a later call can retry. Returns true when the index is
  /// usable. Throws propagate to the caller (ChatRepository catches and
  /// falls back to keyword retrieval).
  Future<bool> ensureIndex() {
    if (_index != null) return Future.value(true);
    return _building ??= _loadOrBuild().catchError((Object e) {
      _building = null; // allow retry on next call
      throw e;
    });
  }

  /// Semantic top-k. Requires [ensureIndex] to have succeeded; callers
  /// that didn't check get a clear [StateError].
  Future<List<RetrievalHit>> topK(String query, {int k = 3}) async {
    final index = _index;
    if (index == null) {
      throw StateError('EmbeddingRetriever.ensureIndex() not completed');
    }
    final q = await embedder.embed(query, task: EmbedTask.query);
    return index.topK(q, k: k, floor: floor);
  }

  Future<bool> _loadOrBuild() async {
    if (chunks.isEmpty) return false;
    final cached = await _readCache();
    if (cached != null) {
      _index = BruteForceRetriever(chunks: chunks, vectors: cached);
      debugPrint('[EmbeddingRetriever] loaded cached index '
          '(${chunks.length}×${cached.length ~/ chunks.length})');
      return true;
    }
    debugPrint('[EmbeddingRetriever] building index over '
        '${chunks.length} chunks (first run after install)');
    final dim = await embedder.embed(_documentText(chunks.first),
        task: EmbedTask.document);
    final flat = Float32List(dim.length * chunks.length);
    flat.setRange(0, dim.length, dim);
    for (var i = 1; i < chunks.length; i++) {
      final v = await embedder.embed(_documentText(chunks[i]),
          task: EmbedTask.document);
      if (v.length != dim.length) {
        throw StateError('embedder dim changed mid-build '
            '(${v.length} != ${dim.length})');
      }
      flat.setRange(i * dim.length, (i + 1) * dim.length, v);
    }
    _index = BruteForceRetriever(chunks: chunks, vectors: flat);
    _writeCache(flat);
    return true;
  }

  /// Mirrors `tools/build_kb.py` so offline (Colab) and on-device indexes
  /// embed byte-identical text.
  static String _documentText(Chunk c) =>
      'Topic: ${c.topic}. ${c.text} ${c.keywordsBn.join(' ')}';

  Future<Float32List?> _readCache() async {
    final f = cacheFile;
    if (f == null) return null;
    try {
      if (!f.existsSync()) return null;
      final bytes = f.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      if (bytes.length < _kHeaderBytes) return null;
      if (String.fromCharCodes(bytes.take(4)) != 'SJEG') return null;
      final count = data.getInt32(4, Endian.little);
      final dim = data.getInt32(8, Endian.little);
      if (count != chunks.length || dim <= 0) return null;
      // Defend against a dimension mismatch if the embedder model changes
      // (e.g. swap EmbeddingGemma for a different model). A wrong dim would
      // silently produce garbage cosine scores against the new query vectors.
      if (dim != await embedder.dim()) return null;
      if (bytes.length != _kHeaderBytes + 4 * count * dim) return null;
      final out = Float32List(count * dim);
      for (var i = 0; i < out.length; i++) {
        out[i] = data.getFloat32(_kHeaderBytes + 4 * i, Endian.little);
      }
      return out;
    } catch (e) {
      debugPrint('[EmbeddingRetriever] cache unreadable, rebuilding: $e');
      return null;
    }
  }

  void _writeCache(Float32List flat) {
    final f = cacheFile;
    if (f == null) return;
    try {
      final count = chunks.length;
      final dim = flat.length ~/ count;
      final bytes = ByteData(_kHeaderBytes + flat.length * 4);
      for (var i = 0; i < 4; i++) {
        bytes.setUint8(i, 'SJEG'.codeUnitAt(i));
      }
      bytes.setInt32(4, count, Endian.little);
      bytes.setInt32(8, dim, Endian.little);
      for (var i = 0; i < flat.length; i++) {
        bytes.setFloat32(_kHeaderBytes + 4 * i, flat[i], Endian.little);
      }
      f.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
    } catch (e) {
      // A failed cache write must never break retrieval — next launch
      // just rebuilds the index.
      debugPrint('[EmbeddingRetriever] cache write failed (ignored): $e');
    }
  }
}
