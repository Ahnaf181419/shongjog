import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/embedder.dart';
import 'package:shongjog/rag/embedding_retriever.dart';
import 'package:shongjog/rag/types.dart';

/// Deterministic fake: documents are mapped to basis vectors by topic
/// substring, queries return [queryVector]. Counts every call so cache
/// behavior is assertable.
class _FakeEmbedder implements Embedder {
  int calls = 0;
  Float32List queryVector;
  Object? throwOn;

  _FakeEmbedder(this.queryVector);

  @override
  Future<Float32List> embed(String text,
      {EmbedTask task = EmbedTask.query}) async {
    calls++;
    if (throwOn != null) throw throwOn!;
    if (task == EmbedTask.query) return queryVector;
    if (text.contains('ors')) return Float32List.fromList([1, 0, 0]);
    if (text.contains('snakebite')) return Float32List.fromList([0, 1, 0]);
    return Float32List.fromList([0, 0, 1]); // water
  }
}

const _chunks = [
  Chunk(id: 'ors', topic: 'ors', source: 'WHO', text: 'ORS text', keywordsBn: ['ORS']),
  Chunk(id: 'snake', topic: 'snakebite', source: 'WHO', text: 'snake text', keywordsBn: ['সাপ']),
  Chunk(id: 'water', topic: 'water', source: 'CDC', text: 'water text', keywordsBn: ['পানি']),
];

void main() {
  group('EmbeddingRetriever index build', () {
    test('ensureIndex embeds every chunk once and ranks by cosine', () async {
      final fake = _FakeEmbedder(Float32List.fromList([0, 1, 0])); // query ≈ snakebite
      final r = EmbeddingRetriever(embedder: fake, chunks: _chunks);
      expect(await r.ensureIndex(), isTrue);
      expect(fake.calls, 3); // three documents
      final hits = await r.topK('সাপে কামড়');
      expect(fake.calls, 4); // + one query
      expect(hits.first.chunk.id, 'snake');
      expect(hits.first.score, closeTo(1.0, 1e-5));
      expect(r.isReady, isTrue);
    });

    test('hits below the floor are dropped', () async {
      // Floor of 1.5 rejects even a perfect cosine match of 1.0.
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(embedder: fake, chunks: _chunks, floor: 1.5);
      await r.ensureIndex();
      final hits = await r.topK('ORS');
      expect(hits, isEmpty);
    });

    test('topK before ensureIndex throws StateError', () async {
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(embedder: fake, chunks: _chunks);
      expect(() => r.topK('x'), throwsStateError);
    });

    test('empty corpus reports not-ready', () async {
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(embedder: fake, chunks: const []);
      expect(await r.ensureIndex(), isFalse);
    });

    test('a failed build resets so a retry can succeed', () async {
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]))
        ..throwOn = StateError('embedder exploded');
      final r = EmbeddingRetriever(embedder: fake, chunks: _chunks);
      await expectLater(r.ensureIndex(), throwsStateError);
      fake.throwOn = null; // embedder recovers (e.g. retry after OOM)
      expect(await r.ensureIndex(), isTrue);
    });

    test('concurrent ensureIndex calls share one build', () async {
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(embedder: fake, chunks: _chunks);
      final results = await Future.wait(
          [r.ensureIndex(), r.ensureIndex(), r.ensureIndex()]);
      expect(results, everyElement(isTrue));
      expect(fake.calls, 3); // not 9
    });
  });

  group('EmbeddingRetriever disk cache', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('shongjog_embed_test');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('second retriever loads the cache without re-embedding', () async {
      final cacheFile = File('${tmp.path}/v.bin');
      final a = EmbeddingRetriever(
        embedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        chunks: _chunks,
        cacheFile: cacheFile,
      );
      expect(await a.ensureIndex(), isTrue);

      final fakeB = _FakeEmbedder(Float32List.fromList([0, 0, 1]));
      final b = EmbeddingRetriever(
        embedder: fakeB,
        chunks: _chunks,
        cacheFile: cacheFile,
      );
      expect(await b.ensureIndex(), isTrue);
      expect(fakeB.calls, 0); // cache hit — no document embeds
      final hits = await b.topK('পানি');
      expect(fakeB.calls, 1); // just the query
      expect(hits.first.chunk.id, 'water');
    });

    test('stale cache (chunk count changed) is rebuilt', () async {
      final cacheFile = File('${tmp.path}/v.bin');
      final a = EmbeddingRetriever(
        embedder: _FakeEmbedder(Float32List.fromList([1, 0, 0])),
        chunks: _chunks,
        cacheFile: cacheFile,
      );
      expect(await a.ensureIndex(), isTrue);

      final fakeB = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final b = EmbeddingRetriever(
        embedder: fakeB,
        chunks: _chunks.take(2).toList(), // corpus shrank
        cacheFile: cacheFile,
      );
      expect(await b.ensureIndex(), isTrue);
      expect(fakeB.calls, 2); // rebuilt the smaller index
    });

    test('corrupt cache falls back to a rebuild', () async {
      final cacheFile = File('${tmp.path}/v.bin');
      cacheFile.writeAsBytesSync([1, 2, 3, 4]); // garbage, no header
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(
        embedder: fake,
        chunks: _chunks,
        cacheFile: cacheFile,
      );
      expect(await r.ensureIndex(), isTrue);
      expect(fake.calls, 3);
    });

    test('missing cache file simply builds', () async {
      final fake = _FakeEmbedder(Float32List.fromList([1, 0, 0]));
      final r = EmbeddingRetriever(
        embedder: fake,
        chunks: _chunks,
        cacheFile: File('${tmp.path}/nonexistent.bin'),
      );
      expect(await r.ensureIndex(), isTrue);
      expect(fake.calls, 3);
    });
  });
}
