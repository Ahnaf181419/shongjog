import '../../l10n/app_localizations.dart';

/// Pure-Dart seeder for the chat history. Returns 3 pre-answered
/// Q&A pairs to be inserted on first run so the chat never looks
/// empty in a judge's hands.
///
/// Idempotent at the consumer level: the caller (chat_screen) only
/// seeds if the store is empty AND the seed flag isn't set.
class DemoSeeder {
  /// Built-in seed Q&A. Content matches what the existing KB
  /// already returns; the answers here are written directly so
  /// the demo runs even before the model is loaded.
  static List<({String question, String answer})> seeds(AppLocalizations l10n) => [
        (question: l10n.demoSeedQ1Question, answer: l10n.demoSeedQ1Answer),
        (question: l10n.demoSeedQ2Question, answer: l10n.demoSeedQ2Answer),
        (question: l10n.demoSeedQ3Question, answer: l10n.demoSeedQ3Answer),
      ];
}
