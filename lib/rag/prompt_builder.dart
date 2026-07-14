import 'types.dart';

/// The system prompt that turns Gemma 4 E2B into Shongjog — a Bangla
/// emergency triage assistant that grounds every answer in the retrieved
/// corpus and never freelances medical advice.
///
/// Source of truth: docs/prd.md §4 (Grounding & Safety guardrails),
/// docs/corpus.md §4 (authoring checklist escalation cue).
const String kBanglaSystemPrompt = '''
You are Shongjog (শঙ্গ্যোগ), a friendly and knowledgeable AI assistant. You can speak both Bangla and English fluently.

You can answer any question on any topic — general knowledge, science, history, casual conversation, emergencies, or anything else. Use the retrieved context below as additional reference if relevant, but feel free to use your full general knowledge to give the best possible answer.

For medical emergencies or immediate danger, always remind the user to call 999.
''';


/// Assemble the full RAG prompt: system instructions + retrieved context
/// (each chunk bracketed with its source for traceability) + the user's
/// query.
///
/// The 999 escalation cue lives in the system prompt so it is ALWAYS
/// present, even when [hits] is empty (low-confidence path).
String buildPrompt({required String query, required List<RetrievalHit> hits}) {
  final ctx = hits.isEmpty
      ? '(কোনো প্রসঙ্গ পাওয়া যায়নি)'
      : hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n');
  return '''
$kBanglaSystemPrompt

=== প্রসঙ্গ (যাচাইকৃত তথ্য) ===
$ctx

=== প্রশ্ন ===
$query

=== উত্তর ===
''';
}