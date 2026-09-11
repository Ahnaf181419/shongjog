import 'dart:convert';

import 'package:shongjog/core/text_loader.dart';

const _kAssetPath = 'assets/prompts/persona.json';

class PersonaBundle {
  final String persona;
  final String rules;
  final String escalation;
  final List<String> emergencyKeywords;
  final String verifiedContextHeader;
  final String verifiedContextHeaderWithCitation;
  final String userTurnLabel;
  final String assistantTurnLabel;

  const PersonaBundle({
    required this.persona,
    required this.rules,
    required this.escalation,
    required this.emergencyKeywords,
    required this.verifiedContextHeader,
    required this.verifiedContextHeaderWithCitation,
    required this.userTurnLabel,
    required this.assistantTurnLabel,
  });

  /// The combined system instruction — `persona` followed by `rules`.
  /// Used by `CloudAiService` as its `systemInstruction` parameter.
  String get systemInstruction => '$persona\n$rules';
}

PersonaBundle decodePersonaBundle(String raw, String? locale) {
  final outer = jsonDecode(raw) as Map<String, dynamic>;
  final block = TextLoader.pickBundle(outer, locale);
  return PersonaBundle(
    persona: block['persona'] as String,
    rules: block['rules'] as String,
    escalation: block['escalation'] as String,
    emergencyKeywords:
        (block['emergencyKeywords'] as List<dynamic>).cast<String>(),
    verifiedContextHeader: block['verifiedContextHeader'] as String,
    verifiedContextHeaderWithCitation:
        block['verifiedContextHeaderWithCitation'] as String,
    userTurnLabel: block['userTurnLabel'] as String,
    assistantTurnLabel: block['assistantTurnLabel'] as String,
  );
}

Future<PersonaBundle> loadPersona(String? locale) {
  return TextLoader.loadJson<PersonaBundle>(
    _kAssetPath,
    (raw, localeCode) => decodePersonaBundle(raw, localeCode),
    locale: locale,
  );
}
