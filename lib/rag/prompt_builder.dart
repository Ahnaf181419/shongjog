import 'types.dart';

/// Persona block — identity + voice rules combined for strong adherence.
const String _kPersona = '''
You are Shongjog — a genuinely warm, lively, and helpful Bangladeshi AI companion.
You talk like a real friend, not an assistant. Be natural, be human.

Voice rules:
- Use contractions, natural rhythm, and real warmth — not corporate politeness or robotic disclaimers.
- Sound like a knowledgeable friend who genuinely cares, not a textbook or a help desk.
- Never start with "As an AI…" or "Here is…" or "Sure, I can help with that!" — just answer directly.
- Never end with generic sign-offs like "Let me know if you have more questions!" — end naturally, like a real conversation.
- Concise by default. Warmer and more detailed when the person seems stressed or needs support.
- For casual chat, be light and friendly. For emergencies, be calm and clear — still warm, but focused.
- Match the user's energy: if they're casual, be casual. If they're worried, be reassuring.
''';

/// Behavioural rules — language and content guidelines.
const String _kRules = '''
Rules:
- Always reply in the same language the user used — Bangla, English, or Banglish. Match their language and tone naturally.
- Keep responses concise and conversational. Use bullet points or numbered steps ONLY when the user is asking for step-by-step emergency or health safety instructions. For casual chat, reply in natural flowing text.
- Use verified knowledge-base information when available. If no context is provided, answer from general knowledge.
- Never fabricate medical dosages or treatment steps not in the provided context. If unsure, say so plainly instead of guessing.

Safety rules (CRITICAL):
- If the query is about a life-threatening emergency (choking, drowning, severe bleeding, cardiac), give the MOST URGENT step FIRST — no preamble.
- Always include the 999 escalation when the situation is dangerous.
- If you don't know or the context doesn't cover it, say "আমি নিশ্চিত নই" — never guess on medical advice.
- Correct dangerous myths explicitly: "না, এটি ভুল" — never affirm a harmful practice.
- Use Bengali numerals (০-৯) in all numbered steps, dosages, and quantities.
''';

/// Combined system instruction for cloud AI (persona + rules).
/// Used by CloudAiService as the `systemInstruction` parameter.
const String kSystemInstruction = '$_kPersona\n$_kRules';

/// Emergency keywords used to decide whether to append the 999 escalation line.
const List<String> _kEmergencyKeywords = [
  'জরুরি', 'স্বাস্থ্য', 'রোগ', 'চিকিৎসা', 'বিপদ', 'আঘাত', 'ক্ষতি',
  'জ্বর', 'পেটে', 'বমি', 'ডায়রিয়া', 'রক্ত', 'শ্বাস', 'বুকে',
  'মাথা', 'ব্যথা', 'কাশি', 'সর্দি', 'এলার্জি', 'পোড়া', 'কাটা',
  'দুর্ঘটনা', 'প্রাণ', 'মৃত্যু', '999',
  'emergency', 'health', 'doctor', 'hospital', 'pain', 'fever', 'bleeding',
  'accident', 'allergic', 'breathing', 'chest', 'stroke', 'poison',
];

/// Returns true if the user query is likely about an emergency or health topic.
bool isEmergencyQuery(String query) {
  final q = query.toLowerCase();
  return _kEmergencyKeywords.any((kw) => q.contains(kw));
}

/// Builds the user-facing message with optional RAG context and emergency line.
///
/// This is used by ChatRepository for the cloud AI path where the system
/// instruction is sent separately via `systemInstruction`.
String buildUserMessage({
  required String query,
  required List<RetrievalHit> hits,
}) {
  final buf = StringBuffer();

  if (hits.isNotEmpty) {
    buf
      ..writeln('=== Verified context ===')
      ..writeln(hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n'))
      ..writeln();
  }

  buf.write(query);

  if (isEmergencyQuery(query)) {
    buf
      ..writeln()
      ..writeln()
      ..write('দরকার হলে ৯৯৯ এ কল করুন।');
  }

  return buf.toString();
}

/// Builds the full prompt sent to the on-device LLM.
///
/// When [hits] is empty, the context section is omitted entirely —
/// this prevents the model from adopting a stiff "citing a source"
/// register for general knowledge answers.
///
/// The 999 escalation line is appended only for emergency/health
/// queries.
///
/// **Note on chat template:** the on-device `.task` runtime is
/// `com.google.mediapipe:tasks-genai:0.10.21`. Although the model
/// file ships under the `litert-community/gemma-4-*` namespace,
/// the HF Gemma 4 IT chat template (`<|turn>role\n` markers
/// emitted by `chat_template.jinja`) is NOT the wire format the
/// MediaPipe session expects. Earlier we attempted to drive the
/// model directly with `<|turn>` markers and bypassed the SDK's
/// `isChat:true` wrap, but this produced a hard exception on a
/// real device ("ত্রুটি হয়েছে" error bubble). The SDK's built-in
/// `transformToChatPrompt` uses `<start_of_turn>user\n…` and is
/// what the bundled `.task` was benchmarked against. We therefore
/// leave the legacy `User:` / `Assistant:` formatting inside the
/// body and let the SDK wrap it with the working `<start_of_turn>`
/// markers via `getResponse(prompt: ..., isChat: true)` in
/// `ModelManager.generate`. The `User:` / `Assistant:` literals
/// inside the body are decoration only; if the SDK exposes a
/// future flag to control them, we'll switch then.
/// Maximum prior turns to include in the on-device prompt.
/// The context window is 1024 tokens; persona + rules + context + 4 turns
/// stays well within budget for short Bangla exchanges.
const int kMaxHistoryTurns = 4;

String buildPrompt({
  required String query,
  required List<RetrievalHit> hits,
  List<ChatTurn> history = const [],
}) {
  final buf = StringBuffer()
    ..writeln(_kPersona)
    ..writeln(_kRules)
    ..writeln();

  // Context section — only when there are actual KB hits.
  // Include source attribution so the model can cite provenance.
  if (hits.isNotEmpty) {
    buf
      ..writeln('=== Verified context (cite the source in your answer) ===')
      ..writeln(hits.map((h) => '[Source: ${h.chunk.source}] ${h.chunk.text}').join('\n\n'))
      ..writeln();
  }

  // Conversation history — capped to stay within context window.
  final capped = history.length > kMaxHistoryTurns
      ? history.sublist(history.length - kMaxHistoryTurns)
      : history;
  for (final turn in capped) {
    final role = turn.isUser ? 'User' : 'Assistant';
    buf.writeln('$role: ${turn.text}');
  }

  buf
    ..writeln('User: $query')
    ..write('Assistant:');

  // Emergency escalation — only for health/safety queries.
  if (isEmergencyQuery(query)) {
    buf
      ..writeln()
      ..writeln()
      ..write('দরকার হলে ৯৯৯ এ কল করুন।');
  }

  return buf.toString();
}
