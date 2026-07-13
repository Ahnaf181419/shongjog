import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../rag/retriever.dart';
import '../rag/types.dart';

/// In-memory handle to the loaded on-device knowledge base.
///
/// Loads `assets/kb/corpus.json` (the verified Bangla chunks) and
/// `assets/kb/vectors.bin` (the float32 [N, 768] L2-normalized embeddings
/// produced by `tools/build_kb.py`). Both ship inside the APK so the KB is
/// present in airplane mode with no first-run network step
/// (docs/architecture.md §6).
class KnowledgeBase {
  final List<Chunk> chunks;
  final BruteForceRetriever retriever;

  const KnowledgeBase({required this.chunks, required this.retriever});

  /// Load the KB from the bundled assets.
  static Future<KnowledgeBase> load() async {
    final jsonStr = await rootBundle.loadString('assets/kb/corpus.json');
    final chunks = parseCorpus(jsonStr);
    final raw = await rootBundle.load('assets/kb/vectors.bin');
    final vectors = raw.buffer.asFloat32List();
    return KnowledgeBase(
      chunks: chunks,
      retriever: BruteForceRetriever(chunks: chunks, vectors: vectors),
    );
  }

  /// Copy the bundled vectors to the app docs dir so the on-device embedder
  /// (Phase 3.3) can read them as a plain file. Used during integration.
  Future<File> writeToDiskForEmbedder() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/kb_vectors.bin');
    final bytes = await rootBundle.load('assets/kb/vectors.bin');
    return f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }
}