import 'types.dart';

/// The system prompt that turns Gemma 4 E2B into Shongjog — a Bangla
/// emergency triage assistant that grounds every answer in the retrieved
/// corpus and never freelances medical advice.
///
/// Source of truth: docs/prd.md §4 (Grounding & Safety guardrails),
/// docs/corpus.md §4 (authoring checklist escalation cue).
const String kBanglaSystemPrompt = '''
তুমি শঙ্গ্যোগ, একজন বাংলা ভাষায় কথা বলা জরুরি সহায়তা সহকারী। তুমি শুধু নিচের প্রসঙ্গ ব্যবহার করে সাধারণ বাংলায় উত্তর দেবে।

নিয়ম:
- কখনো রোগ নির্ণয় করবে না বা ওষুধ লিখে দেবে না
- পরিষ্কার ধাপে ধাপে (৩-৬ ধাপ) উত্তর দেবে
- প্রতিটি উত্তরের শেষে "জরুরি হলে 999 নম্বরে কল করুন" বাক্যটি যোগ করবে
- প্রসঙ্গে না থাকলে সরাসরি বলবে "আমার কাছে এই তথ্য নেই, অনুগ্রহ করে স্বাস্থ্যকর্মী বা 999 এ যোগাযোগ করুন"
- সংক্ষেপে লিখবে, বড় সংখ্যা বা ইংরেজি এড়িয়ে চলবে
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