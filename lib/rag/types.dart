import 'dart:convert';

/// A verified guidance chunk from the on-device knowledge base.
///
/// Source of truth: docs/architecture.md §7 (data model), docs/corpus.md §3.
class Chunk {
  final String id;
  final String topic;
  final String source;
  final String text;
  final List<String> keywordsBn;

  const Chunk({
    required this.id,
    required this.topic,
    required this.source,
    required this.text,
    required this.keywordsBn,
  });

  factory Chunk.fromJson(Map<String, dynamic> j) => Chunk(
        id: j['id'] as String,
        topic: j['topic'] as String,
        source: j['source'] as String,
        text: j['text'] as String,
        keywordsBn: (j['keywords_bn'] as List).cast<String>(),
      );
}

/// A retrieval result: a chunk plus its cosine similarity score.
class RetrievalHit {
  final Chunk chunk;
  final double score;
  const RetrievalHit(this.chunk, this.score);
}

/// Parse a corpus JSON array string into a list of [Chunk]s.
List<Chunk> parseCorpus(String jsonString) => (jsonDecode(jsonString) as List)
    .map((e) => Chunk.fromJson(e as Map<String, dynamic>))
    .toList(growable: false);