import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../rag/keyword_retriever.dart';
import '../rag/retriever.dart';
import '../rag/types.dart';

/// In-memory handle to the loaded on-device knowledge base.
///
/// Loads `assets/kb/corpus.json` (the verified Bangla chunks) and
/// `assets/kb/vectors.bin` (the float32 [N, 768] L2-normalized embeddings
/// produced by `tools/build_kb.py`). Both ship inside the APK so the KB is
/// present in airplane mode with no first-run network step
/// (docs/architecture.md §6).
///
/// The [keywordRetriever] is always available. The [cosineRetriever] is
/// nullable because it requires vectors.bin (present after build_kb.py runs).
class KnowledgeBase {
  final List<Chunk> chunks;
  final KeywordRetriever keywordRetriever;
  final BruteForceRetriever? cosineRetriever;

  const KnowledgeBase({
    required this.chunks,
    required this.keywordRetriever,
    this.cosineRetriever,
  });

  /// Load the KB from the bundled assets.
  ///
  /// If vectors.bin is missing or fails to load, only the keyword retriever
  /// is available (graceful degradation).
  static Future<KnowledgeBase> load() async {
    final jsonStr = await rootBundle.loadString('assets/kb/corpus.json');
    final chunks = parseCorpus(jsonStr);

    BruteForceRetriever? cosine;
    try {
      final raw = await rootBundle.load('assets/kb/vectors.bin');
      final vectors = raw.buffer.asFloat32List();
      cosine = BruteForceRetriever(chunks: chunks, vectors: vectors);
    } catch (e) {
      if (!kReleaseMode) debugPrint('KB: vectors.bin not found, keyword-only mode: $e');
    }

    return KnowledgeBase(
      chunks: chunks,
      keywordRetriever: KeywordRetriever(chunks: chunks),
      cosineRetriever: cosine,
    );
  }

  /// Copy the bundled vectors to the app docs dir so the on-device embedder
  /// (Phase 3.3) can read them as a plain file. Used during integration.
  Future<File>? writeToDiskForEmbedder() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/kb_vectors.bin');
    final bytes = await rootBundle.load('assets/kb/vectors.bin');
    return f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }
}