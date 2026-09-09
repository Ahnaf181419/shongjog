//
// Persona / rules / escalation + emergency keywords now live in
// assets/prompts/persona.json (bn+en) and load through
// lib/features/rag/persona_loader.dart. We keep this builder for the
// chat tier chain only: the structural shape of the user message
// (Tier 1, cloud) and the on-device prompt (Tier 2, device). All text
// itself comes from the PersonaBundle.

import 'package:shongjog/features/rag/persona_loader.dart';
import 'types.dart';

const int kMaxHistoryTurns = 4;

/// Returns true if the user query looks like a health/safety topic,
/// based on the persona's emergencyKeywords list.
bool isEmergencyQuery(String query, PersonaBundle persona) {
  final q = query.toLowerCase();
  return persona.emergencyKeywords.any((kw) => q.contains(kw.toLowerCase()));
}

/// Build the user-side message that goes on top of an existing
/// `systemInstruction` (Cloud AI path — Tier 1).
String buildUserMessage({
  required String query,
  required List<RetrievalHit> hits,
  required PersonaBundle persona,
}) {
  final buf = StringBuffer();
  if (hits.isNotEmpty) {
    buf
      ..writeln(persona.verifiedContextHeader)
      ..writeln(hits
          .map((h) => '[${h.chunk.source}] ${h.chunk.text}')
          .join('\n\n'))
      ..writeln();
  }
  buf.write(query);
  if (isEmergencyQuery(query, persona)) {
    buf
      ..writeln()
      ..writeln()
      ..write(persona.escalation);
  }
  return buf.toString();
}

/// Build the full prompt for the on-device path (Tier 2 — Gemma 4).
String buildPrompt({
  required String query,
  required List<RetrievalHit> hits,
  required PersonaBundle persona,
  List<ChatTurn> history = const [],
}) {
  final buf = StringBuffer()
    ..writeln(persona.persona)
    ..writeln(persona.rules)
    ..writeln();
  if (hits.isNotEmpty) {
    buf
      ..writeln(persona.verifiedContextHeaderWithCitation)
      ..writeln(hits
          .map((h) => '[Source: ${h.chunk.source}] ${h.chunk.text}')
          .join('\n\n'))
      ..writeln();
  }
  final capped = history.length > kMaxHistoryTurns
      ? history.sublist(history.length - kMaxHistoryTurns)
      : history;
  for (final turn in capped) {
    buf.writeln('${turn.isUser ? persona.userTurnLabel : persona.assistantTurnLabel}: ${turn.text}');
  }
  buf
    ..writeln('${persona.userTurnLabel}: $query')
    ..write('${persona.assistantTurnLabel}:');
  if (isEmergencyQuery(query, persona)) {
    buf
      ..writeln()
      ..writeln()
      ..write(persona.escalation);
  }
  return buf.toString();
}
