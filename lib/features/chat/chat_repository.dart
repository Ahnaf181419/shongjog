import 'dart:typed_data';

import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/types.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Orchestrates a single RAG query: retrieve → prompt → generate.
///
/// Retrieval uses keyword matching (always available, fully offline).
/// If an embedder is provided, cosine retrieval is used as a secondary
/// signal to re-rank keyword hits.
///
/// Generation: Cloud AI when online (with fallback), on-device Gemma when
/// offline, canned safety response if retrieval returns nothing.
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

  /// Run a full RAG query and return the Bangla answer, or a canned
  /// low-confidence response if retrieval returns nothing above floor.
  Future<String> ask(String userQuery, {void Function()? onFallback}) async {
    final hits = _retrieve(userQuery);

    if (hits.isEmpty) {
      return 'আমার কাছে এই প্রশ্নের উত্তর নেই। অনুগ্রহ করে স্বাস্থ্যকর্মী বা '
          '999 নম্বরে যোগাযোগ করুন।';
    }

    final prompt = buildPrompt(query: userQuery, hits: hits);

    if (cloudAi != null) {
      final isOnline = await cloudAi!.isOnline;
      if (isOnline) {
        try {
          return await cloudAi!.generate(prompt);
        } catch (e) {
          if (onFallback != null) onFallback();
        }
      }
    }

    if (modelManager != null) {
      try {
        return await modelManager!.generate(prompt);
      } catch (e) {
        return 'AI মডেল চালু করা যায়নি। অনুগ্রহ করে ৯৯৯ এ কল করুন।';
      }
    }

    return hits.first.chunk.text;
  }

  /// Retrieve relevant chunks using keyword matching, optionally re-ranked
  /// by cosine similarity when an embedder is available.
  List<RetrievalHit> _retrieve(String query) {
    final keywordHits = kb.keywordRetriever.topK(query, k: 5);
    // Cosine re-ranking is deferred: `flutter_gemma` 0.5.x has no embedder
    // API, and we deliberately do not call a network embedder (offline
    // thesis). When a local embed lands, replace the body of this branch
    // with:  embed(query) → score each hit → re-sort by descending cosine.
    // See docs/POST-HACKATHON.md §1 for the embedder roadmap.
    return keywordHits.take(3).toList();
  }
}

/// Function type for embedding a query into a Float32List.
/// Allows swapping embedder implementations without changing ChatRepository.
typedef EmbedderFn = Future<Float32List> Function(String text);
