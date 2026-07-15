import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/keyword_retriever.dart';
import 'package:shongjog/rag/types.dart';

void main() {
  late List<Chunk> chunks;

  setUp(() {
    chunks = [
      const Chunk(
        id: 'ors_recipe',
        topic: 'ors',
        source: 'WHO',
        text: 'ORS তৈরির সহজ উপায়: ১ লিটার পরিষ্কার পানি নিন।',
        keywordsBn: ['ORS', 'ডায়রিয়া', 'পানিশূন্যতা', 'চিনি', 'লবণ'],
      ),
      const Chunk(
        id: 'snakebite_donts',
        topic: 'snakebite',
        source: 'WHO',
        text: 'সাপে কামড়ালে যা করবেন না।',
        keywordsBn: ['সাপ', 'কামড়', 'কাটবেন না', 'চুষবেন না', 'বরফ'],
      ),
      const Chunk(
        id: 'water_boil',
        topic: 'water',
        source: 'WHO',
        text: 'পানি ফুটিয়ে পরিশুদ্ধ করুন।',
        keywordsBn: ['পানি', 'ফুটানো', 'পরিশুদ্ধ', 'বোতল'],
      ),
    ];
  });

  test('returns matching chunk for keyword query', () {
    final r = KeywordRetriever(chunks: chunks);
    final hits = r.topK('ORS কিভাবে বানাবো', k: 3);
    expect(hits, isNotEmpty);
    expect(hits.first.chunk.id, 'ors_recipe');
  });

  test('returns snakebite chunk for snake query', () {
    final r = KeywordRetriever(chunks: chunks);
    final hits = r.topK('সাপে কামড়েছে', k: 3);
    expect(hits, isNotEmpty);
    expect(hits.first.chunk.id, 'snakebite_donts');
  });

  test('returns water chunk for water query', () {
    final r = KeywordRetriever(chunks: chunks);
    final hits = r.topK('বিশুদ্ধ পানি কিভাবে বানাবো', k: 3);
    expect(hits, isNotEmpty);
    expect(hits.first.chunk.id, 'water_boil');
  });

  test('returns empty list for unrelated query', () {
    final r = KeywordRetriever(chunks: chunks);
    final hits = r.topK('আবহাওয়া কেমন', k: 3);
    expect(hits, isEmpty);
  });

  test('respects k limit', () {
    final r = KeywordRetriever(chunks: chunks);
    final hits = r.topK('ORS পানি সাপ', k: 2);
    expect(hits.length, lessThanOrEqualTo(2));
  });

  test('empty chunks returns empty', () {
    final r = KeywordRetriever(chunks: const []);
    final hits = r.topK('anything', k: 3);
    expect(hits, isEmpty);
  });
}
