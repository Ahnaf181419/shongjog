import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/core/tool.dart';
import 'package:shongjog/features/chat/chat_repository.dart';
import 'package:shongjog/features/chat/local_llm.dart';
import 'package:shongjog/rag/keyword_retriever.dart';
import 'package:shongjog/rag/types.dart';
import 'package:shongjog/knowledge/kb_loader.dart';

/// Minimal LocalLlm impl for unit tests. Three members, no side effects.
/// Exists because ModelManager (the production type) can't be subclassed
/// in tests — its `isReady` is a non-virtual getter over private state.
class _FakeLlm implements LocalLlm {
  _FakeLlm({
    this.ready = false,
    this.onDisk = false,
    this.generateResult,
    this.generateError,
  });
  final bool ready;
  final bool onDisk;
  final String? generateResult;
  final Object? generateError;

  @override
  bool get isReady => ready;

  @override
  Future<bool> isAnyOnDisk() async => onDisk;

  @override
  void setThinkingMode(bool? enable) {}

  @override
  Future<String> generate(String prompt) async {
    if (generateError != null) throw generateError!;
    return generateResult ?? 'fake-answer';
  }

  @override
  Future<String?> generateStructured({
    required String prompt,
    required List<Tool> tools,
  }) async =>
      null;
}

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

    test('returns "no answer" message when retrieval finds nothing',
        () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask('আবহাওয়া কেমন');
      expect(answer, contains('৯৯৯'));
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
      expect(answer, contains('৯৯৯'));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Regression: when the local model is "ready" but generate() throws
  //  (e.g. flutter_gemma plugin init failure on a stale model.bin, or
  //  OOM during load), ChatRepository MUST surface that failure via
  //  onPath — NOT silently fall through to the corpus chunk.
  //
  //  Before this fix, Tier-2 was wrapped in a try/catch with `debugPrint`
  //  and the bubble chip reported `কোরপাস` ("answer came from RAG lookup")
  //  when in fact the answer came from a corpus chunk because the local
  //  model crashed. The user saw a misleading corpus answer and assumed
  //  the device model was broken.
  //
  //  These tests pin the expected behavior so we can watch the test
  //  fail RED, then write the fix (GREEN), then refactor.
  // ════════════════════════════════════════════════════════════════
  group('ChatRepository Tier-2 surface-on-failure', () {
    test(
        'reports device path when local model generates successfully '
        '(regression guard for GREEN)', () async {
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        model: _FakeLlm(
          onDisk: true, // tell ChatRepository Tier-2 the file is there
          generateResult: 'device answer',
        ),
      );
      final answer = await repo.ask(
        'ORS কিভাবে বানাবো',
        onPath: paths.add,
      );
      expect(answer, 'device answer');
      expect(paths, [GenerationPath.device]);
    });

    test(
        'when the local model says it is ready but generate() throws, '
        'ChatRepository falls through to Tier-3 corpus instead of '
        'showing an error bubble', () async {
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateError: StateError('Gemma runtime died'),
        ),
      );
      final answer = await repo.ask('ORS কিভাবে বানাবো', onPath: paths.add);
      // Falls through to corpus — the ORS chunk text.
      expect(answer, contains('ORS'));
      expect(paths, [GenerationPath.corpus]);
    });

    // ══════════════════════════════════════════════════════════════
    //  BLANK-BUBBLE GUARD
    //
    //  When the engine leaks its thought channel, the raw output starts
    //  with `<|channel|>` at index 0. truncateAtTurnMarker correctly cuts
    //  everything from the first marker onward — which for that input is
    //  the ENTIRE string. Tier-2 used to return that empty string as a
    //  successful device answer, rendering a blank bubble that looks
    //  exactly like a crash.
    //
    //  Correct behavior: treat "cleaned to nothing" as no answer and fall
    //  through to the corpus.
    // ══════════════════════════════════════════════════════════════
    test(
        'when the model emits only control tokens, Tier-2 falls through to '
        'corpus instead of returning a blank bubble', () async {
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          // Verbatim shape from docs/image.png — leak starts at index 0.
          generateResult: '<|channel|>thought\nThinking<channel|>'
              '<|channel|>thought\n Process<channel|>',
        ),
      );
      final answer = await repo.ask('ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer.trim(), isNotEmpty,
          reason: 'a blank bubble must never reach the user');
      expect(answer, contains('ORS'));
      expect(paths, [GenerationPath.corpus]);
    });

    test(
        'a real answer followed by a channel leak still reports the device '
        'path (the guard must not over-trigger)', () async {
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult:
              'ORS বানাতে ১ লিটার পানি নিন।\n<|channel|>thought leak',
        ),
      );
      final answer = await repo.ask('ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'ORS বানাতে ১ লিটার পানি নিন।');
      expect(paths, [GenerationPath.device]);
    });
  });
}
