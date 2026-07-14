import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/chat_repository.dart';
import 'package:shongjog/rag/keyword_retriever.dart';
import 'package:shongjog/rag/types.dart';
import 'package:shongjog/knowledge/kb_loader.dart';

void main() {
  late KnowledgeBase testKb;

  setUp(() {
    const chunks = [
      Chunk(
        id: 'ors_recipe',
        topic: 'ors',
        source: 'WHO',
        text: 'ORS তৈরির সহজ উপায়: ১ লিটার পরিষ্কার পানি নিন।',
        keywordsBn: ['ORS', 'ডায়রিয়া', 'পানিশূন্যতা'],
      ),
      Chunk(
        id: 'snakebite',
        topic: 'snakebite',
        source: 'WHO',
        text: 'সাপে কামড়ালে যা করবেন না।',
        keywordsBn: ['সাপ', 'কামড়'],
      ),
      Chunk(
        id: 'water_purification',
        topic: 'water',
        source: 'CDC',
        text: 'পানি ফুটিয়ে পরিশুদ্ধ করুন।',
        keywordsBn: ['পানি', 'ফুটানো', 'পরিশুদ্ধ'],
      ),
    ];
    testKb = KnowledgeBase(
      chunks: chunks,
      keywordRetriever: const KeywordRetriever(chunks: chunks),
    );
  });

  group('ChatRepository fallback path (no model, no cloud)', () {
    test('returns retrieved chunk text when no model available', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask('ORS কিভাবে বানাবো');
      expect(answer, contains('ORS'));
      expect(answer, contains('পানি'));
    });

    test('returns snakebite text for snake query', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask('সাপে কামড়েছে');
      expect(answer, contains('সাপ'));
    });

    test('returns water text for water query', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask('বিশুদ্ধ পানি কিভাবে বানাবো');
      expect(answer, contains('পানি'));
      expect(answer, contains('ফুটিয়ে'));
    });

    test('returns "no answer" message when retrieval finds nothing', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask('আবহাওয়া কেমন');
      expect(answer, contains('999'));
    });
  });

  group('ChatRepository with empty KB', () {
    test('returns "no answer" for any query', () async {
      const emptyKb = KnowledgeBase(
        chunks: [],
        keywordRetriever: KeywordRetriever(chunks: []),
      );
      final repo = ChatRepository(kb: emptyKb);
      final answer = await repo.ask('কিছু জিজ্ঞাসা');
      expect(answer, contains('999'));
    });
  });
}
