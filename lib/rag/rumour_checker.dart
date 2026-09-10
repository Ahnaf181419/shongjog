/// Rumour & misinformation checker.
///
/// Takes a claim, retrieves relevant context from the KB, and builds a
/// prompt that asks Gemma to: confirm / correct / not-covered, with source.
///
/// The purest offline argument in the whole app: you cannot fact-check a
/// rumour by searching the web when the tower is down. Only a local model
/// with a verified corpus can.
library;

import 'prompt_builder.dart' show kMaxHistoryTurns;
import 'rumour_strings_loader.dart';
import 'types.dart';

RegExp _rumourPrefixFrom(List<String> prefixes) {
  final escaped = prefixes.map(RegExp.escape).join('|');
  return RegExp('^($escaped)');
}

/// Detects whether a query is a rumour-check request.
///
/// Queries starting with these prefixes are routed through the rumour
/// checker instead of the standard RAG path.
Future<bool> isRumourQuery(String query, {RumourStrings? s}) async {
  final strings = s ??
      (cachedRumour.rumourPrefixes.isEmpty
          ? await loadRumourStrings(null)
          : cachedRumour);
  final re = _rumourPrefixFrom(strings.rumourPrefixes);
  return re.hasMatch(query.trim());
}

/// Builds the rumour-check prompt.
String buildRumourCheckPrompt({
  required String query,
  required List<RetrievalHit> hits,
  List<ChatTurn> history = const [],
  RumourStrings? s,
}) {
  final strings = s ?? cachedRumour;
  final re = _rumourPrefixFrom(strings.rumourPrefixes);

  // Strip the rumour prefix to extract the actual claim.
  final claim = query.replaceAll(re, '').trim();

  final buf = StringBuffer()
    ..writeln(strings.systemInstruction)
    ..writeln();

  if (hits.isNotEmpty) {
    buf
      ..writeln(strings.verifiedContextHeader)
      ..writeln(
          hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n'))
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
    ..writeln(strings.claimLabel.replaceAll('{claim}', claim))
    ..writeln()
    ..write(strings.verifyInstruction);

  // Always append 999 reminder for safety.
  buf
    ..writeln()
    ..writeln()
    ..write(strings.emergencyCallReminder);

  return buf.toString();
}
