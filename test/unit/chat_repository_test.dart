import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/core/tool.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/cloud_ai/api_key_ring.dart';
import 'package:shongjog/features/cloud_ai/cloud_ai_service.dart';
import 'package:shongjog/features/chat/chat_repository.dart';
import 'package:shongjog/features/chat/local_llm.dart';
import 'package:shongjog/rag/embedder.dart';
import 'package:shongjog/rag/embedding_retriever.dart';
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
    this.onGenerate,
  });
  final bool ready;
  final bool onDisk;
  final String? generateResult;
  final Object? generateError;
  final void Function(String prompt)? onGenerate;

  @override
  bool get isReady => ready;

  @override
  Future<bool> isAnyOnDisk() async => onDisk;

  @override
  void setThinkingMode(bool? enable) {}

  @override
  Future<String> generate(String prompt) async {
    onGenerate?.call(prompt);
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
  TestWidgetsFlutterBinding.ensureInitialized();
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
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো');
      expect(answer, contains('ORS'));
      expect(answer, contains('পানি'));
    });

    test('returns snakebite text for snake query', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask(null, 'সাপে কামড়েছে');
      expect(answer, contains('সাপ'));
    });

    test('returns water text for water query', () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask(null, 'বিশুদ্ধ পানি কিভাবে বানাবো');
      expect(answer, contains('পানি'));
      expect(answer, contains('ফুটিয়ে'));
    });

    test('returns "no answer" message when retrieval finds nothing',
        () async {
      final repo = ChatRepository(kb: testKb);
      final answer = await repo.ask(null, 'আবহাওয়া কেমন');
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
      final answer = await repo.ask(null, 'কিছু জিজ্ঞাসা');
      expect(answer, contains('৯৯৯'));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Regression: when the local model is "ready" but generate() throws
  //  (e.g. flutter_gemma plugin init failure on a stale model.bin, or
  //  OOM during load), ChatRepository MUST surface that failure via
  //  onPath — NOT silently fall through to the corpus chunk.
  //
  //  Before the original fix, the on-device tier (now Tier-2; was Tier-1
  //  before the cloud-first flip) was wrapped in a try/catch with
  //  `debugPrint` and the bubble chip reported `কোরপাস` ("answer came
  //  from RAG lookup") when in fact the answer came from a corpus chunk
  //  because the local model crashed. The user saw a misleading corpus
  //  answer and assumed the device model was broken.
  //
  //  None of these tests configure a `cloudAi`, so with the cloud-first
  //  ordering the Cloud tier is skipped and the device tier runs as
  //  before. The assertions below pin that behavior.
  // ════════════════════════════════════════════════════════════════
  group('ChatRepository device-failure surfaces via corpus fallback', () {
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
        null, 'ORS কিভাবে বানাবো',
        onPath: paths.add,
      );
      expect(answer, 'device answer');
      expect(paths, [GenerationPath.device]);
    });

    test(
        'when the local model says it is ready but generate() throws, '
        'ChatRepository falls through to the corpus tier instead of '
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
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
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
    //  the ENTIRE string. The on-device tier (Tier-2 after the cloud-first
    //  flip) used to return that empty string as a successful device
    //  answer, rendering a blank bubble that looks exactly like a crash.
    //
    //  Correct behavior: treat "cleaned to nothing" as no answer and fall
    //  through to the corpus.
    // ══════════════════════════════════════════════════════════════
    test(
        'when the model emits only control tokens, the device tier falls '
        'through to corpus instead of returning a blank bubble', () async {
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
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
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
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'ORS বানাতে ১ লিটার পানি নিন।');
      expect(paths, [GenerationPath.device]);
    });
  });

  group('ChatRepository history passthrough', () {
    test('history is included in the prompt sent to the local model', () async {
      String? capturedPrompt;
      final repo = ChatRepository(
        kb: testKb,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult: 'answer',
          onGenerate: (prompt) => capturedPrompt = prompt,
        ),
      );
      await repo.ask(
        null,
        'আবার বলো',
        history: const [
          ChatTurn(text: 'তোমার নাম কি', isUser: true),
          ChatTurn(text: 'শঞ্জোগ', isUser: false),
        ],
      );
      expect(capturedPrompt, contains('User: তোমার নাম কি'));
      expect(capturedPrompt, contains('Assistant: শঞ্জোগ'));
      expect(capturedPrompt, contains('User: আবার বলো'));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Semantic retrieval (EmbeddingGemma seam). The retriever is a real
  //  EmbeddingRetriever over a deterministic fake embedder — exercises
  //  the actual index-build + cosine path ChatRepository will run with
  //  the plugin embedder, just with hand-placed vectors.
  // ════════════════════════════════════════════════════════════════
  group('ChatRepository semantic retrieval', () {
    test('embedding hits feed the prompt as verified context', () async {
      String? capturedPrompt;
      final embedding = EmbeddingRetriever(
        embedder: _SemanticFakeEmbedder(Float32List.fromList([1, 0])),
        chunks: testKb.chunks,
      );
      final repo = ChatRepository(
        kb: testKb,
        embedding: embedding,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult: 'semantic answer',
          onGenerate: (p) => capturedPrompt = p,
        ),
      );
      final answer = await repo.ask(null, 'ডায়রিয়ায় কী করবো');
      expect(answer, 'semantic answer');
      // The ORS chunk (nearest to the fake query vector) is the context.
      expect(capturedPrompt, contains('[Source: WHO] ORS তৈরির সহজ উপায়'));
    });

    test('a failing embedder falls back to keyword retrieval', () async {
      final embedding = EmbeddingRetriever(
        embedder: _SemanticFakeEmbedder(Float32List.fromList([1, 0]))
          ..throwOn = StateError('embedder OOM'),
        chunks: testKb.chunks,
      );
      final repo = ChatRepository(kb: testKb, embedding: embedding);
      // No model: with the embedder dead, the keyword path must still
      // retrieve the ORS chunk and answer from the corpus tier.
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো');
      expect(answer, contains('ORS'));
    });

    test('empty semantic hits fall back to keyword retrieval', () async {
      // Floor above 1.0 rejects even perfect cosine matches, forcing the
      // semantic path to return no hits — the keyword path must still
      // find ORS and answer from the corpus tier.
      final embedding = EmbeddingRetriever(
        embedder: _SemanticFakeEmbedder(Float32List.fromList([1, 0])),
        chunks: testKb.chunks,
        floor: 1.2,
      );
      final repo = ChatRepository(kb: testKb, embedding: embedding);
      final answer = await repo.ask(null, 'ORS কিভাবে বানাবো');
      expect(answer, contains('ORS'));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Cloud-first tier order
  //
  //  After the flip, the chain is Cloud → Device → Corpus → Canned, gated
  //  on `connectivityProvider.isOnline`. These tests drive a real
  //  CloudAiService through a MockClient and assert both the answer and
  //  the GenerationPath reported via onPath.
  //
  //  Connectivity is set in setUp (online) and reset in tearDown
  //  (offline) — the same pattern as cloud_ai_key_rotation_test.dart —
  //  so a failing assertion cannot leak online state into the next group.
  // ════════════════════════════════════════════════════════════════
  group('ChatRepository tier order — Cloud first when online', () {
    setUp(() => connectivityProvider.debugSetOnline(true));
    tearDown(() => connectivityProvider.debugSetOnline(false));

    test(
        'online + cloud configured → Cloud is tried first, on-device model '
        'is never invoked, no cloud failure surfaces', () async {
      final cloud = cloudAiWithAnswer('cloud answer');
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        cloudAi: cloud.service,
        model: _FakeLlm(
          // If the device is ever called in this scenario the test must
          // fail — generateResult is intentionally set so a successful
          // device call would surface as 'device answer' below.
          ready: true,
          onDisk: true,
          generateResult: 'device answer',
        ),
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'cloud answer');
      expect(paths, [GenerationPath.cloud]);
      expect(cloud.requestCount(), 1,
          reason: 'online + key configured → exactly one Cloud request');
    });

    test(
        'online + cloud throws → falls through to on-device when device '
        'is ready', () async {
      final cloud = cloudAiThrowingWithError();
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        cloudAi: cloud,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult: 'device answer',
        ),
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'device answer');
      expect(paths, [GenerationPath.device]);
    });

    test(
        'online + cloud throws + device not ready → falls through to '
        'corpus', () async {
      final cloud = cloudAiThrowingWithError();
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        cloudAi: cloud,
        // No model — Tier 2 skipped.
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, contains('ORS'));
      expect(paths, [GenerationPath.corpus]);
    });

    test(
        'offline + device ready → on-device is used, cloud is NEVER called '
        '(no wasted network request on an airplane-mode phone)', () async {
      connectivityProvider.debugSetOnline(false);
      final cloud = cloudAiWithAnswer('cloud answer');
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        cloudAi: cloud.service,
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult: 'device answer',
        ),
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'device answer');
      expect(paths, [GenerationPath.device]);
      expect(cloud.requestCount(), 0,
          reason: 'offline devices must not waste a Cloud request');
    });

    test(
        'offline + cloud configured + device not ready → corpus, no '
        'network call', () async {
      connectivityProvider.debugSetOnline(false);
      final cloud = cloudAiWithAnswer('cloud answer');
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        cloudAi: cloud.service,
        // No model.
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, contains('ORS'));
      expect(paths, [GenerationPath.corpus]);
      expect(cloud.requestCount(), 0);
    });

    test(
        'online + no cloudAi configured → falls straight to on-device', () async {
      final paths = <GenerationPath>[];
      final repo = ChatRepository(
        kb: testKb,
        // No cloudAi.
        model: _FakeLlm(
          ready: true,
          onDisk: true,
          generateResult: 'device answer',
        ),
      );
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, 'device answer');
      expect(paths, [GenerationPath.device]);
    });

    test(
        'offline + no cloudAi + no device → corpus (the existing no-model '
        'baseline must still work)', () async {
      connectivityProvider.debugSetOnline(false);
      final paths = <GenerationPath>[];
      final repo = ChatRepository(kb: testKb);
      final answer =
          await repo.ask(null, 'ORS কিভাবে বানাবো', onPath: paths.add);
      expect(answer, contains('ORS'));
      expect(paths, [GenerationPath.corpus]);
    });
  });
}

/// Fake embedder for the ChatRepository group: document embeddings are
/// fixed basis vectors picked by chunk id; queries return [queryVector].
class _SemanticFakeEmbedder implements Embedder {
  _SemanticFakeEmbedder(this.queryVector);

  final Float32List queryVector;
  Object? throwOn;

  @override
  Future<int> dim() async => queryVector.length;

  @override
  Future<Float32List> embed(String text,
      {EmbedTask task = EmbedTask.query}) async {
    if (throwOn != null) throw throwOn!;
    if (task == EmbedTask.query) return queryVector;
    // Document text is 'Topic: {topic}. …' — match on the topic token.
    if (text.startsWith('Topic: ors')) return Float32List.fromList([1, 0]);
    return Float32List.fromList([0, 1]);
  }
}

/// Build a real [CloudAiService] wired to a [MockClient] that responds to
/// any `generateContent` request with [cloudAnswer]. Returns the service and
/// a request-counting function so the tier-order tests can assert exactly
/// how many HTTP calls the repository made through this fake.
///
/// Uses `http.Response.bytes` with utf-8 encoding so Bangla text survives
/// the mock boundary (the `String` constructor encodes as latin1, which
/// cannot represent Bangla and throws "Contains invalid characters").
({CloudAiService service, int Function() requestCount}) cloudAiWithAnswer(
  String cloudAnswer,
) {
  var count = 0;
  final client = MockClient((req) async {
    count++;
    final body = utf8.encode(jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': cloudAnswer},
            ],
          },
        },
      ],
    }));
    return http.Response.bytes(body, 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
  return (
    service: CloudAiService(
      keys: ApiKeyRing.single('test-key'),
      httpClient: client,
    ),
    requestCount: () => count,
  );
}

/// Build a real [CloudAiService] whose transport always returns HTTP 500,
/// forcing the Cloud tier to throw and exercise the on-device fallthrough.
/// 500 (not a key-fatal 429/403) keeps the key ring out of the picture — the
/// goal is to prove the repository's own catch-and-fallthrough behavior, not
/// the rotation policy.
CloudAiService cloudAiThrowingWithError() {
  final client = MockClient((req) async {
    return http.Response.bytes(
      utf8.encode('{"error":{"code":500,"message":"boom"}}'),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return CloudAiService(
    keys: ApiKeyRing.single('test-key'),
    httpClient: client,
  );
}
