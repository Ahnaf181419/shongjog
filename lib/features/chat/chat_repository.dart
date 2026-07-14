import '../../core/model_manager.dart';
import '../../knowledge/kb_loader.dart';
import '../../rag/embedder.dart';
import '../../rag/prompt_builder.dart';
import '../cloud_ai/cloud_ai_service.dart';

/// Orchestrates a single RAG query: embed → retrieve → prompt → generate.
///
/// Source of truth: docs/architecture.md §5 (pipeline). The low-confidence
/// canned response (hits empty) is the safety net — the model never
/// freelances when retrieval fails (docs/prd.md §4 guardrail).
class ChatRepository {
  final KnowledgeBase kb;
  final Embedder embedder;
  final ModelManager modelManager;
  final CloudAiService cloudAi;

  ChatRepository({
    required this.kb,
    required this.embedder,
    required this.modelManager,
    required this.cloudAi,
  });

  /// Run a full RAG query and return the Bangla answer, or a canned
  /// low-confidence response if retrieval returns nothing above floor.
  Future<String> ask(String userQuery, {void Function()? onFallback}) async {
    final qVec = await embedder.embed(userQuery);
    final hits = kb.retriever.topK(qVec, k: 3, floor: 0.35);
    if (hits.isEmpty) {
      return 'আমার কাছে এই প্রশ্নের উত্তর নেই। অনুগ্রহ করে স্বাস্থ্যকর্মী বা '
          '999 নম্বরে যোগাযোগ করুন।';
    }
    final prompt = buildPrompt(query: userQuery, hits: hits);
    
    // Cloud AI layer logic
    final isOnline = await cloudAi.isOnline;
    if (isOnline) {
      try {
        final answer = await cloudAi.generate(prompt);
        return answer;
      } catch (e) {
        if (onFallback != null) onFallback();
        return modelManager.generate(prompt);
      }
    } else {
      if (onFallback != null) onFallback();
      return modelManager.generate(prompt);
    }
  }
}