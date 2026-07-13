import 'dart:typed_data';

/// EmbeddingGemma client — embeds a Bangla query into a 768-dim
/// L2-normalized vector for brute-force cosine retrieval.
///
/// This is the adapter layer (docs/architecture.md §3): it wraps whichever
/// embedder surface Phase 0 spike A confirms, and hands a plain
/// [Float32List] inward to the pure [BruteForceRetriever].
///
/// STATUS (skeleton phase): flutter_gemma 0.5.1 does NOT expose an embedder
/// API — only the generative [InferenceModel]. The three resolution paths
/// the spike must choose between:
///   1. flutter_gemma 1.2.3+ — bump the constraint; newer versions may add
///      embedder support.
///   2. MediaPipe tasks-genai — the same `com.google.mediapipe:tasks-genai`
///      artifact flutter_gemma already pulls in exposes embedder tasks via
///      a platform channel.
///   3. A separate Dart-native embedder package.
///
/// Until the spike resolves, this concrete implementation throws. The
/// abstract [Embedder] interface (returned to by ChatRepository) is stable;
/// only this file changes when the embedder lands.
class EmbedderImpl implements Embedder {
  @override
  Future<Float32List> embed(String text) async {
    throw UnimplementedError(
      'EmbedderImpl not yet wired — Phase 0 spike A must confirm the '
      'embedder API surface (flutter_gemma 0.5.1 has none). See '
      'docs/architecture.md §13 open question #1.',
    );
  }
}

/// Abstract interface — pure, no Flutter or package deps. The retriever
/// and ChatRepository code against this, so the concrete impl can swap
/// without touching inner layers.
abstract class Embedder {
  Future<Float32List> embed(String text);
}