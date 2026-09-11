import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../knowledge/kb_loader.dart';
import '../../rag/embedding_retriever.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/rumour_checker.dart';
import '../../rag/types.dart';
import '../../rag/urgency_classifier.dart';
import '../cloud_ai/cloud_ai_service.dart';
import '../rag/persona_loader.dart';
import '../shelter/shelter_intent_detector.dart';
import '../shelter/shelter_model.dart';
import '../shelter/shelter_tool_dispatcher.dart';
import '../shelter/shelter_tool_result_formatter.dart';
import 'local_llm.dart';

/// Orchestrates a single RAG query via a connectivity-gated tier chain:
///
/// TIER 1: Cloud AI — tried when `cloudAi != null` AND the device is online.
/// TIER 2: On-device Gemma 4 (E2B/E4B) — offline fallback; also tried when
///         online but Cloud has no key / fails / times out.
/// TIER 3: RAG corpus — always available.
/// TIER 4: Canned "৯৯৯" message — absolute last resort.
///
/// Cloud is tried first on connected devices because it answers faster
/// (~2.5s vs. ~5-10s cold-start for on-device Gemma, plus 30-90s per
/// generation) and produces higher-quality, non-degenerate responses. The
/// on-device model is still the offline thesis of the app — it is the
/// safety net when the network is down, when no API key is configured, or
/// when Cloud AI fails (quota spent, key blocked, request times out).
///
/// See `docs/prd.md` §13 for the corresponding policy statement.
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

  /// Optional semantic retriever (EmbeddingGemma 300M). When null — or
  /// when it fails at runtime — retrieval is keyword-only, exactly as
  /// before this seam existed.
  final EmbeddingRetriever? embedding;

  /// Optional shelter list for the conversational shelter-search feature
  /// (Option 1 in docs/AI-MAP-FEATURES.md). When null, shelter-intent
  /// queries fall through to the normal RAG path.
  final List<Shelter> Function()? shelterProvider;

  /// Optional user-location provider for shelter ranking. Returns the
  /// user's GPS as a `(lat, lon)` record, or null when unavailable.
  final Future<({double lat, double lon})?> Function()? userLocationProvider;

  ChatRepository({
    required this.kb,
    this.model,
    this.cloudAi,
    this.embedding,
    this.shelterProvider,
    this.userLocationProvider,
  });


  /// Run a full query and return the Bangla answer without throwing exceptions
  /// to the UI. It gracefully falls back through the tiers.
  ///
  /// [history] is the prior conversation turns (oldest first).
  Future<String> ask(Locale? locale,
    String userQuery, {
    List<ChatTurn> history = const [],
    void Function(GenerationPath path)? onPath,
  }) async {
    // ── Option 1: conversational shelter search ─────────────────────
    // If the query looks shelter-shaped AND we have shelters + a user
    // location, answer it with the pure-Dart haversine ranker and the
    // Bangla map-result formatter — no model involved at any point.
    //
    // This runs before every other tier because it is both the fastest
    // path (microseconds, no inference, no network) and the most
    // reliable: nothing here can time out, hallucinate, or come back
    // empty. Falls through on any failure.
    if (ShelterIntentDetector.isShelterQuery(userQuery) &&
        shelterProvider != null &&
        userLocationProvider != null) {
      try {
        final shelterAnswer = await _tryShelterToolPath(userQuery, locale: locale);
        if (shelterAnswer != null) {
          if (onPath != null) onPath(GenerationPath.device);
          return shelterAnswer;
        }
      } catch (e) {
        debugPrint('[ChatRepo/ShelterPath] failed, falling through: $e');
      }
    }

    final localeCode = locale?.languageCode ?? 'bn';
    final hits = await _retrieve(userQuery, localeCode: localeCode);

    // Persona bundle — load once per `ask()`. Source of truth for the
    // chat-tier chain's prompt text lives in assets/prompts/persona.json
    // via lib/features/rag/persona_loader.dart.
    final persona = await loadPersona(locale?.languageCode);

    // TIER 1: Cloud AI — primary when `cloudAi` is configured and the device
    // is online. We check `isOnline` here (not just key availability) so a
    // phone in airplane mode skips Cloud entirely and goes straight to
    // on-device Gemma — no wasted 10s timeout per model in the fallback chain.
    if (cloudAi != null && await cloudAi!.isOnline) {
      debugPrint('[ChatRepo/Tier1] cloud path entered for q="${userQuery.substring(0, userQuery.length.clamp(0, 40))}…"');
      try {
        final userMessage = buildUserMessage(
          query: userQuery,
          hits: hits,
          persona: persona,
          localeCode: localeCode,
        );
        final answer = await cloudAi!.generateWithHistory(
          userMessage: userMessage,
          history: history,
          locale: locale?.languageCode,
        );
        debugPrint('[ChatRepo/Tier1] cloud path success len=${answer.length}');
        if (onPath != null) onPath(GenerationPath.cloud);
        return answer;
      } catch (e, st) {
        debugPrint('[ChatRepo/Tier1] cloud path FAILED: $e');
        debugPrint('[ChatRepo/Tier1] stack: $st');
        // Silent fallthrough to the on-device tier. Better UX than a hard
        // error bubble — the user gets *something* useful and can retry or
        // call 999.
      }
    }

    // TIER 2: On-device Gemma 4 (E2B/E4B) — offline fallback. Reached when
    // Cloud has no key, the device is offline, or Cloud failed above.
    // Route rumour-check queries through a dedicated prompt that asks
    // the model to verify the claim against the corpus.
    final isRumour = await isRumourQuery(userQuery, locale: locale?.languageCode);
    final prompt = isRumour
        ? buildRumourCheckPrompt(
            query: userQuery, hits: hits, history: history, locale: localeCode)
        : buildPrompt(
            query: userQuery,
            hits: hits,
            history: history,
            persona: persona,
            localeCode: localeCode,
          );

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
          // A cleaned-to-nothing answer means the model produced only
          // control tokens (e.g. a `<|channel|>thought …` leak starting at
          // index 0, which truncateAtTurnMarker correctly cuts entirely).
          // Returning it here would render a blank bubble and look like a
          // crash. Fall through to the corpus instead — a grounded corpus
          // answer is strictly better than empty.
          if (answer.trim().isEmpty) {
            debugPrint(
                '[ChatRepo/Tier2] device path produced no usable text '
                '(raw ${rawAnswer.length} chars, all control tokens) '
                '— falling through to corpus');
          } else {
            debugPrint('[ChatRepo/Tier2] device path success len=${answer.length} (raw ${rawAnswer.length})');
            if (onPath != null) onPath(GenerationPath.device);
            return answer;
          }
        }
      } catch (e, st) {
        debugPrint('[ChatRepo/Tier2] device path FAILED: $e');
        debugPrint('[ChatRepo/Tier2] stack: $st');
        // Fall through to the corpus tier. Silently degrading is better
        // UX than a hard error bubble — the user gets *something* useful
        // and can retry or call 999.
      }
    }

    // TIER 3: RAG corpus (always available)
    if (hits.isNotEmpty) {
      if (onPath != null) onPath(GenerationPath.corpus);
      return hits.first.chunk.displayText(localeCode);
    }

    // Absolute fallback — localized via ARB.
    if (onPath != null) onPath(GenerationPath.canned);
    final code = locale?.languageCode ?? 'bn';
    final l10n = await AppLocalizations.delegate.load(Locale(code));
    return l10n.chatNoAnswer;
  }

  /// Retrieve relevant chunks: semantic-first when an embedder is wired,
  /// keyword fallback otherwise (and on any embedding failure — a broken
  /// embedder must never take the corpus path down with it).
  Future<List<RetrievalHit>> _retrieve(String query, {String localeCode = 'bn'}) async {
    final semantic = embedding;
    // The on-device embedding index is bn-only; only the keyword retriever
    // is locale-aware today. Skip the embedding path in en mode.
    if (semantic != null && localeCode != 'en') {
      try {
        if (await semantic.ensureIndex()) {
          final hits = await semantic.topK(query, k: 3);
          if (hits.isNotEmpty) return hits;
        }
      } catch (e) {
        debugPrint(
            '[ChatRepo/Embedding] semantic retrieval failed, falling back to keywords: $e');
      }
    }
    final keywordHits =
        kb.keywordRetriever.topK(query, k: 5, localeCode: localeCode);
    return keywordHits.take(3).toList();
  }

  /// Option 1 path: run the `find_nearest_shelter` tool directly and format
  /// a Bangla map-result message. Returns null to signal "fall through to
  /// the normal tiers" (no GPS fix, or no shelters loaded).
  ///
  /// **This used to invoke the model, and no longer does.** The old flow
  /// loaded the model, opened a session, and ran a full generation to have
  /// it emit a `find_nearest_shelter` tool call — whose only payload the
  /// dispatcher ever read was an optional integer `count`, clamped to 1–10
  /// and defaulting to 3. [ShelterIntentDetector.isShelterQuery] had already
  /// established the intent deterministically before we got here, and both
  /// the ranking (haversine) and the formatting are pure Dart. So the entire
  /// inference existed to extract one small number.
  ///
  /// It was also worse than a no-op when it missed: if the model answered in
  /// prose rather than emitting a tool call, this returned null and [ask]
  /// went on to run a *second* full generation — two complete inferences,
  /// 30–50s on a mid-range phone, to answer "where is the nearest shelter",
  /// which is the single most time-critical question this app fields.
  ///
  /// [ShelterToolDispatcher.parseRequestedCount] reads the count off the
  /// query directly, in microseconds, and cannot fail to produce an answer.
  /// The tool schema stays exported for the model-facing paths that still
  /// use it and for the dispatcher's envelope tests.
  Future<String?> _tryShelterToolPath(String userQuery, {Locale? locale}) async {
    final pos = await userLocationProvider!();
    if (pos == null) return null;
    final shelters = shelterProvider!();
    if (shelters.isEmpty) return null;

    final count = ShelterToolDispatcher.parseRequestedCount(userQuery);
    final ranked = ShelterToolDispatcher.dispatch(
      args: count == null ? const {} : {'count': count},
      userLat: pos.lat,
      userLon: pos.lon,
      shelters: shelters,
    );
    if (ranked.isEmpty) return null;
    return ShelterToolResultFormatter.toMessage(
      ranked,
      localeCode: locale?.languageCode ?? 'bn',
    );
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
  /// Exposed as a public static so it can be called from the shelter
  /// map screen (AI brief row) as well as from unit tests.
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

/// Which generation path answered a given query.
enum GenerationPath {
  cloud,
  device,
  corpus,
  canned;

  String label(BuildContext context) {
    switch (this) {
      case GenerationPath.cloud:
        return AppLocalizations.of(context).chatPathCloud;
      case GenerationPath.device:
        return AppLocalizations.of(context).chatPathDevice;
      case GenerationPath.corpus:
        return AppLocalizations.of(context).chatPathCorpus;
      case GenerationPath.canned:
        return AppLocalizations.of(context).chatPathCanned;
    }
  }
}
