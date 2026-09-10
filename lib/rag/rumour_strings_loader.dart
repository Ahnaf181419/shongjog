import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/rumour.json';

class RumourStrings {
  final String systemInstruction;
  final String verifiedContextHeader;
  final List<String> rumourPrefixes;
  final String claimLabel;
  final String verifyInstruction;
  final String emergencyCallReminder;

  RumourStrings._empty()
      : systemInstruction = '',
        verifiedContextHeader = '',
        rumourPrefixes = const [],
        claimLabel = '',
        verifyInstruction = '',
        emergencyCallReminder = '';

  static RumourStrings _fromMap(Map<String, dynamic> m) => RumourStrings._fromList(
        systemInstruction: m['systemInstruction'] as String,
        verifiedContextHeader: m['verifiedContextHeader'] as String,
        rumourPrefixes: (m['rumourPrefixes'] as List).cast<String>(),
        claimLabel: m['claimLabel'] as String,
        verifyInstruction: m['verifyInstruction'] as String,
        emergencyCallReminder: m['emergencyCallReminder'] as String,
      );

  RumourStrings._fromList({
    required this.systemInstruction,
    required this.verifiedContextHeader,
    required this.rumourPrefixes,
    required this.claimLabel,
    required this.verifyInstruction,
    required this.emergencyCallReminder,
  });
}

RumourStrings cachedRumour = RumourStrings._empty();

Future<RumourStrings> loadRumourStrings(String? locale) async {
  return TextLoader.loadJson<RumourStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, locale);
    return RumourStrings._fromMap(block);
  });
}

Future<void> primeRumourCache(String? locale) async {
  cachedRumour = await loadRumourStrings(locale);
}
