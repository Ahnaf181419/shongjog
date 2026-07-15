import 'types.dart';
import 'prompt_builder.dart';

// Re-export the canonical prompt builder from prompt_builder.dart.
export 'prompt_builder.dart' show buildPrompt, buildUserMessage, kSystemInstruction;

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
bool _isEmergencyQuery(String query) {
  final q = query.toLowerCase();
  return _kEmergencyKeywords.any((kw) => q.contains(kw));
}

/// Build a complete prompt with system context, RAG hits, and user query.
///
/// If [personalizationSummary] is provided, it's injected into the system
/// prompt to give the AI context about user preferences and history.
///
/// This is the enhanced prompt builder that supports personalization.
/// For basic usage without personalization, use [buildPrompt] directly.
String buildPersonaPrompt({
  required String query,
  required List<RetrievalHit> hits,
  String? personalizationSummary,
}) {
  final buf = StringBuffer()
    ..writeln(kSystemInstruction)
    ..writeln();

  // Personalization summary — injected between rules and context.
  if (personalizationSummary != null && personalizationSummary.isNotEmpty) {
    buf
      ..writeln('ব্যবহারকারী সম্পর্কে:')
      ..writeln(personalizationSummary)
      ..writeln();
  }

  // Context section — only when there are actual KB hits.
  if (hits.isNotEmpty) {
    buf
      ..writeln('=== Verified context ===')
      ..writeln(hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n'))
      ..writeln();
  }

  buf
    ..writeln('User: $query')
    ..write('Assistant:');

  // Emergency escalation — only for health/safety queries.
  if (_isEmergencyQuery(query)) {
    buf
      ..writeln()
      ..writeln()
      ..write('দরকার হলে ৯৯৯ এ কল করুন।');
  }

  return buf.toString();
}
