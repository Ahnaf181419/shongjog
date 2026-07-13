import 'dart:typed_data';

/// EmbeddingGemma client — embeds a Bangla query into a 768-dim L2-normalized
/// vector for brute-force cosine retrieval.
///
/// This is the adapter layer (docs/architecture.md §3): it wraps the
/// flutter_gemma embedder API and hands a plain [Float32List] inward to the
/// pure retriever. Phase 3.3 confirms the exact flutter_gemma embedder API
/// surface and pins the model path; this stub lets Phase 3.2 (ChatRepository)
/// compile against the interface.
abstract class Embedder {
  Future<Float32List> embed(String text);
}