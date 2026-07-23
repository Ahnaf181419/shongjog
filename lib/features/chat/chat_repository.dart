import 'package:flutter/foundation.dart';

import '../../knowledge/kb_loader.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/rumour_checker.dart';
import '../../rag/types.dart';
import '../../rag/urgency_classifier.dart';
import '../cloud_ai/cloud_ai_service.dart';
import 'local_llm.dart';

/// Orchestrates a single RAG query via 3-Tier intelligence:
/// TIER 1: Cloud AI (online)
/// TIER 2: Local LLM (offline)
/// TIER 3: RAG corpus
class ChatRepository {
  final KnowledgeBase kb;

  /// The on-device LLM contract (see [LocalLlm]). In production this is
  /// [modelManager] (which `implements LocalLlm` via duck typing on the
  /// three members `isReady`, `isAnyOnDisk`, `generate`); in tests it
  /// is a 30-line fake. Either way the repository never depends on
  /// ModelManager's larger surface (download state, variant switching,
  /// ChangeNotifier plumbing).
  final LocalLlm? model;

  final CloudAiService? cloudAi;

  /// Optional embedder for cosine retrieval. When null, keyword-only.
  final EmbedderFn? embedder;

  ChatRepository({
    required this.kb,
    this.model,
    this.cloudAi,
    this.embedder,
  });

  /// Run a full query and return the Bangla answer without throwing exceptions
  /// to the UI. It gracefully falls back through the tiers.
  ///
  /// [history] is the prior conversation turns (oldest first).
  Future<String> ask(
    String userQuery, {
    List<ChatTurn> history = const [],
    void Function(GenerationPath path)? onPath,
  }) async {
    final hits = _retrieve(userQuery);

    // TIER 1: Cloud AI (online)
    if (cloudAi != null) {
      final isOnline = await cloudAi!.isOnline;
      if (isOnline) {
        try {
          final userMessage = buildUserMessage(query: userQuery, hits: hits);
          final answer = await cloudAi!.generateWithHistory(
            userMessage: userMessage,
            history: history,
          );
          if (onPath != null) onPath(GenerationPath.cloud);
          return answer;
        } catch (e) {
          debugPrint('Tier 1 Cloud AI failed entirely: $e');
          // Silent fallthrough to local model
        }
      }
    }

    // TIER 2: Local LLM (offline)
    // Route rumour-check queries through a dedicated prompt that asks
    // the model to verify the claim against the corpus.
    final isRumour = isRumourQuery(userQuery);
    final prompt = isRumour
        ? buildRumourCheckPrompt(query: userQuery, hits: hits)
        : buildPrompt(query: userQuery, hits: hits);

    // Adaptive thinking mode — classify urgency before generation.
    // Critical emergencies get thinking OFF (reflex, max speed); complex
    // queries get thinking ON (deliberation).
    final urgency = UrgencyClassifier.classify(userQuery);
    model?.setThinkingMode(urgency.enableThinking);

    if (model != null) {
      // Tagged logging for runtime triage — `debugPrint` is filtered out
      // in release by default; consumers can enable `-v` or wire
      // `debugPrint` into a file logger to read these on a phone.
      debugPrint('[ChatRepo/Tier2] entered for q="${userQuery.substring(0, userQuery.length.clamp(0, 40))}…" isReady=${model!.isReady}');
      try {
        final shouldTryDevice = model!.isReady || await model!.isAnyOnDisk();
        debugPrint('[ChatRepo/Tier2] shouldTryDevice=$shouldTryDevice');
        if (shouldTryDevice) {
          final rawAnswer = await model!.generate(prompt);
          // Post-process: the SDK has no stopStrings API on the
          // .litertlm path, so after a valid answer the model can
          // emit a second "User:" turn and start rambling. Truncate
          // at the first turn-marker artifact.
          final answer = ChatRepository.truncateAtTurnMarker(rawAnswer);
          debugPrint('[ChatRepo/Tier2] device path success len=${answer.length} (raw ${rawAnswer.length})');
          if (onPath != null) onPath(GenerationPath.device);
          return answer;
        }
      } catch (e, st) {
        debugPrint('[ChatRepo/Tier2] device path FAILED: $e');
        debugPrint('[ChatRepo/Tier2] stack: $st');
        // Fall through to Tier-3 corpus. Silently degrading to a
        // useful corpus answer is better UX than a hard error
        // bubble — the user gets *something* useful and can retry
        // or call 999.
      }
    }

    // TIER 3: RAG corpus (always available)
    if (hits.isNotEmpty) {
      if (onPath != null) onPath(GenerationPath.corpus);
      return hits.first.chunk.text;
    }

    // Absolute fallback
    if (onPath != null) onPath(GenerationPath.canned);
    return 'আমার কাছে এই প্রশ্নের উত্তর নেই। ৯৯৯ এ কল করুন।';
  }

  /// Retrieve relevant chunks using keyword matching.
  List<RetrievalHit> _retrieve(String query) {
    final keywordHits = kb.keywordRetriever.topK(query, k: 5);
    return keywordHits.take(3).toList();
  }

  /// Clean the raw model output of internal-control tokens that should
  /// never be visible to the user.
  ///
  /// Three classes of artifact are stripped (cut at the EARLIEST
  /// occurrence so a real answer that appears before any of them
  /// survives):
  ///
  /// 1. **`\nUser:` / `<start_of_turn>` / `\nassistant\n`** — turn
  ///    markers. After a valid answer the model emits a second
  ///    turn and rambles; we cut everything from the first marker
  ///    onward. This is what the LiteRT-LM SDK can't fix for us
  ///    (no `stopStrings` API on the .litertlm path).
  ///
  /// 2. **`<|channel|>...<|channel|>` blocks** — LiteRT-LM's
  ///    internal channel tokens. With `enableThinking: true` the
  ///    engine leaks the model's internal "thought" channel into
  ///    the visible response as raw text. The user sees gibberish
  ///    like `<|channel|>thought Thinking<|channel|><|channel|>...`.
  ///    We strip everything from the first channel marker onward.
  ///
  /// 3. **`\nAssistant\b`** — bilingual safety (the model
  ///    reinjects the role marker in Bangla: `\nঅassistent:`).
  ///
  /// Exposed as `static` so the unit test exercises the real
  /// production code path, not a private copy.
  @visibleForTesting
  static String truncateAtTurnMarker(String raw) {
    if (raw.isEmpty) return raw;
    // Single regex with alternation so we get the global earliest
    // match in one pass instead of looping.
    final cutPattern = RegExp(
      r'\nUser:' // legacy prompt format
      r'|<start_of_turn>' // SDK chat template
      r'|<\|?channel\|>' // LiteRT-LM thinking channel leak
      r'|\nAssistant\b' // model reinjects role marker (en)
      r'|\n[উA]ssistant:', // bilingual safety
      caseSensitive: false,
    );
    final m = cutPattern.firstMatch(raw);
    final cutAt = m?.start ?? raw.length;
    return raw.substring(0, cutAt).trimRight();
  }
}

/// Function type for embedding a query into a Float32List.
typedef EmbedderFn = Future<Float32List> Function(String text);

/// Which generation path answered a given query.
enum GenerationPath {
  cloud,
  device,
  corpus,
  canned;

  String get labelBn {
    switch (this) {
      case GenerationPath.cloud:
        return 'ক্লাউড';
      case GenerationPath.device:
        return 'ডিভাইস';
      case GenerationPath.corpus:
        return 'কোরপাস';
      case GenerationPath.canned:
        return '৯৯৯';
    }
  }
}
