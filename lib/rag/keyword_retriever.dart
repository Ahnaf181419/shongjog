import 'types.dart';

/// Keyword-based retriever — works fully offline with no embedding model.
///
/// Scores each chunk by keyword overlap with the query:
///   - Each `keywords_bn` entry found in the query → +1.0 (strong signal)
///   - Topic word found in query → +0.5 (medium signal)
///   - Each query word found in chunk text → +0.1 (weak signal)
///
/// This is the primary retrieval path until an on-device embedder is
/// available (Phase 3.3 blocker: flutter_gemma 0.5.1 has no embedder API).
/// For N≈23 chunks, this is sub-millisecond and surprisingly accurate.
class KeywordRetriever {
  final List<Chunk> chunks;

  const KeywordRetriever({required this.chunks});

  /// Return the top-k chunks by keyword-overlap score.
  ///
  /// Only chunks with score > 0 are returned. If nothing matches, the
  /// caller falls back to the canned low-confidence response.
  List<RetrievalHit> topK(String query, {int k = 3}) {
    if (chunks.isEmpty) return const [];

    final q = query.toLowerCase();
    final queryWords = _tokenize(q);

    final scores = List<double>.filled(chunks.length, 0.0);

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      var score = 0.0;

      for (final kw in chunk.keywordsBn) {
        final kwLower = kw.toLowerCase();
        if (q.contains(kwLower)) {
          score += 1.0;
        }
      }

      if (q.contains(chunk.topic.toLowerCase())) {
        score += 0.5;
      }

      final textLower = chunk.text.toLowerCase();
      for (final w in queryWords) {
        if (w.length > 2 && textLower.contains(w)) {
          score += 0.1;
        }
      }

      scores[i] = score;
    }

    final ranked = List<int>.generate(chunks.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    final hits = <RetrievalHit>[];
    for (final idx in ranked.take(k)) {
      if (scores[idx] > 0) {
        hits.add(RetrievalHit(chunks[idx], scores[idx]));
      }
    }
    return hits;
  }

  /// Split Bangla/English text into lowercase word tokens.
  static List<String> _tokenize(String text) {
    return text
        .split(RegExp(r"""[\s।॥,;:.!?()\[\]{}"'\/\\]+"""))
        .where((w) => w.isNotEmpty)
        .toList();
  }
}
