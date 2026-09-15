import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/situation_summary.json';

class SituationSummaryStrings {
  final String systemRole;
  final String bulletCommon;
  final String bulletPriority;
  final String bulletAction;
  final String reportHeader;
  final String reportEntry;
  final String summaryLabel;
  final String fallbackEmpty;
  final String fallbackTitle;
  final String fallbackTotal;
  final String fallbackSos;
  final String fallbackChat;
  final String fallbackSosPriority;
  final String fallbackRoutine;

  const SituationSummaryStrings({
    required this.systemRole,
    required this.bulletCommon,
    required this.bulletPriority,
    required this.bulletAction,
    required this.reportHeader,
    required this.reportEntry,
    required this.summaryLabel,
    required this.fallbackEmpty,
    required this.fallbackTitle,
    required this.fallbackTotal,
    required this.fallbackSos,
    required this.fallbackChat,
    required this.fallbackSosPriority,
    required this.fallbackRoutine,
  });

  SituationSummaryStrings._empty()
      : systemRole = '',
        bulletCommon = '',
        bulletPriority = '',
        bulletAction = '',
        reportHeader = '',
        reportEntry = '',
        summaryLabel = '',
        fallbackEmpty = '',
        fallbackTitle = '',
        fallbackTotal = '',
        fallbackSos = '',
        fallbackChat = '',
        fallbackSosPriority = '',
        fallbackRoutine = '';

  static SituationSummaryStrings _fromMap(Map<String, dynamic> m) =>
      SituationSummaryStrings(
        systemRole: m['systemRole'] as String,
        bulletCommon: m['bulletCommon'] as String,
        bulletPriority: m['bulletPriority'] as String,
        bulletAction: m['bulletAction'] as String,
        reportHeader: m['reportHeader'] as String,
        reportEntry: m['reportEntry'] as String,
        summaryLabel: m['summaryLabel'] as String,
        fallbackEmpty: m['fallbackEmpty'] as String,
        fallbackTitle: m['fallbackTitle'] as String,
        fallbackTotal: m['fallbackTotal'] as String,
        fallbackSos: m['fallbackSos'] as String,
        fallbackChat: m['fallbackChat'] as String,
        fallbackSosPriority: m['fallbackSosPriority'] as String,
        fallbackRoutine: m['fallbackRoutine'] as String,
      );
}

SituationSummaryStrings cachedSituationSummary = SituationSummaryStrings._empty();

Future<SituationSummaryStrings> loadSituationSummaryStrings(String? locale) async {
  return TextLoader.loadJson<SituationSummaryStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, localeCode);
    return SituationSummaryStrings._fromMap(block);
  }, locale: locale);
}
