import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/retriever.dart';
import 'package:shongjog/rag/types.dart';

Float32List _vec(List<double> v) => Float32List.fromList(v);

void main() {
  group('BruteForceRetriever', () {
    test('topK returns chunks ordered by cosine similarity, above floor', () {
      final chunks = [
        Chunk(
            id: 'a',
            topic: 'water',
            source: 'x',
            text: 'A',
            keywordsBn: const []),
        Chunk(
            id: 'b', topic: 'ors', source: 'x', text: 'B', keywordsBn: const []),
        Chunk(
            id: 'c',
            topic: 'snakebite',
            source: 'x',
            text: 'C',
            keywordsBn: const []),
      ];
      // L2-normalized so dot == cosine.
      final vecs = Float32List.fromList([
        1.0, 0.0, 0.0, // a
        0.0, 1.0, 0.0, // b
        0.7071, 0.7071, 0.0, // c — closer to b than a
      ]);
      final r = BruteForceRetriever(chunks: chunks, vectors: vecs);
      final q = _vec([0.0, 1.0, 0.0]); // identical to b
      final top = r.topK(q, k: 2);
      expect(top.first.chunk.id, 'b');
      expect(top[1].chunk.id, 'c');
    });

    test('floor filters out low-similarity hits', () {
      final chunks = [
        Chunk(
            id: 'a',
            topic: 'water',
            source: 'x',
            text: 'A',
            keywordsBn: const []),
        Chunk(
            id: 'b', topic: 'ors', source: 'x', text: 'B', keywordsBn: const []),
      ];
      final vecs = Float32List.fromList([
        1.0, 0.0, // a
        0.0, 1.0, // b
      ]);
      final r = BruteForceRetriever(chunks: chunks, vectors: vecs);
      final q = _vec([1.0, 0.0]); // matches a (1.0), not b (0.0)
      final top = r.topK(q, k: 3, floor: 0.5);
      expect(top.length, 1);
      expect(top.first.chunk.id, 'a');
      expect(top.first.score, greaterThan(0.5));
    });

    test('empty index returns empty hits', () {
      final r =
          BruteForceRetriever(chunks: const [], vectors: Float32List(0));
      final top = r.topK(_vec([1.0, 0.0]), k: 3);
      expect(top, isEmpty);
    });

    test('parseCorpus round-trips Chunk fields', () {
      const json = '''
      [
        {"id":"ors_recipe","topic":"ors","source":"WHO","text":"ORS তৈরি","keywords_bn":["ORS","ডায়রিয়া"]},
        {"id":"snakebite","topic":"snakebite","source":"CDC","text":"সাপের কামড়","keywords_bn":["সাপ"]}
      ]
      ''';
      final chunks = parseCorpus(json);
      expect(chunks.length, 2);
      expect(chunks[0].id, 'ors_recipe');
      expect(chunks[0].topic, 'ors');
      expect(chunks[0].keywordsBn, ['ORS', 'ডায়রিয়া']);
      expect(chunks[1].text, 'সাপের কামড়');
    });
  });
}