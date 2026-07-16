/// Rumour & misinformation checker.
///
/// Takes a claim, retrieves relevant context from the KB, and builds a
/// prompt that asks Gemma to: confirm / correct / not-covered, with source.
///
/// The purest offline argument in the whole app: you cannot fact-check a
/// rumour by searching the web when the tower is down. Only a local model
/// with a verified corpus can.
library;

import 'types.dart';

/// Detects whether a query is a rumour-check request.
///
/// Queries starting with these prefixes are routed through the rumour
/// checker instead of the standard RAG path:
/// - "গুজব:" (rumour:)
/// - "কেউ বললো" (someone said)
/// - "শুনেছি" (I heard)
/// - "সত্য কি" / "ঠিক কি" (is it true / is it correct)
final RegExp _rumourPrefix = RegExp(
  r'^(গুজব:|কেউ বললো|শুনেছি|সত্য কি|ঠিক কি|সঠিক কি|গুজব)',
);

/// Returns true if the query looks like a rumour-check request.
bool isRumourQuery(String query) {
  return _rumourPrefix.hasMatch(query.trim());
}

/// System instruction for the rumour-check prompt.
const _rumourSystem = '''
You are Shongjog — a Bangladeshi emergency companion fact-checking a rumour.

Your task: check the claim against the verified context provided. Respond in Bangla.

Output format:
1. **রায় (Verdict):** সত্য / আংশিক সত্য / ভুল / নিশ্চিত নই
2. **ব্যাখ্যা:** কেন — সরল ভাষায়, প্রমাণ সহ
3. **সঠিক তথ্য:** ভুল হলে সঠিক কী করতে হবে
4. **সূত্র:** [WHO/BDRCS/CDC/IFRC] — যদি context এ থাকে

Rules:
- সবসময় বাংলায় উত্তর দিন
- শুধুমাত্র প্রদত্ত context ব্যবহার করুন — নিজে তথ্য তৈরি করবেন না
- ভুল তথ্য স্পষ্টভাবে চিহ্নিত করুন: "না, এটি ভুল"
- Context এ না থাকলে "নিশ্চিত নই" বলুন, ৯৯৯ কল করার পরামর্শ দিন
- কখনো বিপজ্জনক পরামর্শ দেবেন না
''';

/// Builds the rumour-check prompt.
///
/// Takes the original query (including the rumour prefix), retrieves
/// relevant chunks, and assembles a prompt that instructs the model to
/// verify the claim against the corpus.
String buildRumourCheckPrompt({
  required String query,
  required List<RetrievalHit> hits,
}) {
  // Strip the rumour prefix to extract the actual claim.
  final claim = query.replaceAll(_rumourPrefix, '').trim();

  final buf = StringBuffer()
    ..writeln(_rumourSystem)
    ..writeln();

  if (hits.isNotEmpty) {
    buf
      ..writeln('=== যাচাইকৃত তথ্য (Verified context) ===')
      ..writeln(
          hits.map((h) => '[${h.chunk.source}] ${h.chunk.text}').join('\n\n'))
      ..writeln();
  }

  buf
    ..writeln('দাবি (Claim): $claim')
    ..writeln()
    ..write('উপরের তথ্যের ভিত্তিতে এই দাবি যাচাই করুন।');

  // Always append 999 reminder for safety.
  buf
    ..writeln()
    ..writeln()
    ..write('জরুরি প্রয়োজনে ৯৯৯ এ কল করুন।');

  return buf.toString();
}
