import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/persona_prompt.dart';
import '../../rag/types.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Orchestrates a single RAG query via 3-Tier intelligence:
/// TIER 1: Cloud AI (online)
/// TIER 2: Local LLM (offline)
/// TIER 3: RAG corpus
class ChatRepository {
  final KnowledgeBase kb;
  final ModelManager? modelManager;
  final CloudAiService? cloudAi;

  /// Optional embedder for cosine retrieval. When null, keyword-only.
  final EmbedderFn? embedder;

  ChatRepository({
    required this.kb,
    this.modelManager,
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
    final prompt = buildPrompt(query: userQuery, hits: hits);
    if (modelManager != null) {
      try {
        if (modelManager!.isReady || await modelManager!.isAnyOnDisk()) {
          final answer = await modelManager!.generate(prompt);
          if (onPath != null) onPath(GenerationPath.device);
          return answer;
        }
      } catch (e) {
        debugPrint('Tier 2 Local Model generation failed: $e');
        // Silent fallthrough to corpus
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
