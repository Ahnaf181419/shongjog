import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

import '../../knowledge/kb_loader.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/rumour_checker.dart';
import '../../rag/types.dart';
import '../../rag/urgency_classifier.dart';
import '../cloud_ai/cloud_ai_service.dart';
import '../shelter/shelter_intent_detector.dart';
import '../shelter/shelter_model.dart';
import '../shelter/shelter_tool_dispatcher.dart';
import '../shelter/shelter_tool_result_formatter.dart';
import '../shelter/shelter_tool_schema.dart';
import 'local_llm.dart';

/// Orchestrates a single RAG query via 3-Tier intelligence:
/// TIER 1: On-device Gemma 4 (E2B/E4B) — the primary model, always tried first
/// TIER 2: Cloud AI (online fallback only)
/// TIER 3: RAG corpus
///
/// On-device Gemma runs **first, even when the device is online**. Cloud was
/// tier 1 previously, which meant a connected phone never executed Gemma at
/// all — the opposite of this app's premise (`docs/prd.md` §13: "Gemma 4 is
/// the primary and only LLM powering the app's generative AI") and of the
/// offline thesis the whole product rests on. Cloud is now strictly a safety
/// net for when the on-device model is missing, still downloading, or fails.
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
    this.embedder,
    this.shelterProvider,
    this.userLocationProvider,
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
    // ── Option 1: conversational shelter search ─────────────────────
    // If the query looks shelter-shaped AND we have shelters + a user
    // location, try the function-calling tool path. The model emits a
    // find_nearest_shelter tool call; we dispatch it via the pure-Dart
    // haversine ranker and format a Bangla map-result message.
    //
    // This runs BEFORE the cloud tier so shelter queries get an
    // instant, deterministic, offline answer instead of a network
    // round-trip. Falls through on any failure.
    if (ShelterIntentDetector.isShelterQuery(userQuery) &&
        shelterProvider != null &&
        userLocationProvider != null) {
      try {
        final shelterAnswer = await _tryShelterToolPath(userQuery);
        if (shelterAnswer != null) {
          if (onPath != null) onPath(GenerationPath.device);
          return shelterAnswer;
        }
      } catch (e) {
        debugPrint('[ChatRepo/ShelterPath] failed, falling through: $e');
      }
    }

    final hits = _retrieve(userQuery);

    // TIER 1: On-device Gemma 4 (E2B/E4B) — the primary model.
    // Route rumour-check queries through a dedicated prompt that asks
    // the model to verify the claim against the corpus.
    final isRumour = isRumourQuery(userQuery);
    final prompt = isRumour
        ? buildRumourCheckPrompt(query: userQuery, hits: hits, history: history)
        : buildPrompt(query: userQuery, hits: hits, history: history);

    // Adaptive thinking mode — classify urgency before generation.
    // Critical emergencies get thinking OFF (reflex, max speed); complex
    // queries get thinking ON (deliberation).
    final urgency = UrgencyClassifier.classify(userQuery);
    model?.setThinkingMode(urgency.enableThinking);

    if (model != null) {
      // Tagged logging for runtime triage — `debugPrint` is filtered out
      // in release by default; consumers can enable `-v` or wire
      // `debugPrint` into a file logger to read these on a phone.
      debugPrint('[ChatRepo/Tier1] entered for q="${userQuery.substring(0, userQuery.length.clamp(0, 40))}…" isReady=${model!.isReady}');
      try {
        final shouldTryDevice = model!.isReady || await model!.isAnyOnDisk();
        debugPrint('[ChatRepo/Tier1] shouldTryDevice=$shouldTryDevice');
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
                '[ChatRepo/Tier1] device path produced no usable text '
                '(raw ${rawAnswer.length} chars, all control tokens) '
                '— falling through to corpus');
          } else {
            debugPrint('[ChatRepo/Tier1] device path success len=${answer.length} (raw ${rawAnswer.length})');
            if (onPath != null) onPath(GenerationPath.device);
            return answer;
          }
        }
      } catch (e, st) {
        debugPrint('[ChatRepo/Tier1] device path FAILED: $e');
        debugPrint('[ChatRepo/Tier1] stack: $st');
        // Fall through to the cloud tier, then the corpus. Silently
        // degrading is better UX than a hard error bubble — the user gets
        // *something* useful and can retry or call 999.
      }
    }

    // TIER 2: Cloud AI — fallback only, reached when the on-device model is
    // absent, still downloading, or produced nothing usable.
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
          debugPrint('Tier 2 Cloud AI failed entirely: $e');
          // Silent fallthrough to the corpus.
        }
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

  /// Option 1 path: ask the model to emit a `find_nearest_shelter`
  /// tool call, dispatch it with the pure-Dart ranker, and format a
  /// Bangla map-result message. Returns null to signal "fall through
  /// to the normal tiers".
  ///
  /// Two ways this returns null:
  /// - No model, or model not ready/on disk → the device path isn't
  ///   available; the normal tiers handle it.
  /// - The model ran but didn't emit a shelter tool call (e.g. it
  ///   answered in prose). Fall through and let the normal path show
  ///   that prose answer.
  Future<String?> _tryShelterToolPath(String userQuery) async {
    if (model == null) return null;
    final shouldTryDevice = model!.isReady || await model!.isAnyOnDisk();
    if (!shouldTryDevice) return null;

    final pos = await userLocationProvider!();
    if (pos == null) return null;
    final shelters = shelterProvider!();
    if (shelters.isEmpty) return null;

    // Ask the model to emit a tool call. The prompt is tight: we tell
    // it exactly which tool is available and that the user wants the
    // nearest shelter. The model's job is to confirm intent + extract
    // a count; the dispatcher does the real ranking.
    final toolPrompt = StringBuffer()
      ..writeln('The user asked: "$userQuery"')
      ..writeln('Use the find_nearest_shelter tool to answer.')
      ..writeln('If they specified a number, pass it as count; '
          'otherwise omit count to use the default of 3.');
    final rawJson = await model!.generateStructured(
      prompt: toolPrompt.toString(),
      tools: const [findNearestShelterTool],
    );
    if (rawJson == null || rawJson.isEmpty) return null;

    // Parse the JSON envelope the SDK emits.
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final args = ShelterToolDispatcher.extractArgsFromJson(parsed);
    if (args == null) return null;

    final ranked = ShelterToolDispatcher.dispatch(
      args: args,
      userLat: pos.lat,
      userLon: pos.lon,
      shelters: shelters,
    );
    if (ranked.isEmpty) return null;
    return ShelterToolResultFormatter.toBanglaMessage(ranked);
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

/// Function type for embedding a query into a Float32List.
typedef EmbedderFn = Future<Float32List> Function(String text);

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
