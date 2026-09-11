import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/risk.json';

class RiskStrings {
  final String task;
  final String homeMaterial;
  final String floodHistory;
  final String elevation;
  final String nearRiver;
  final String nearCoast;
  final String hasElderly;
  final String hasInfants;
  final String riskLabel;
  final String noMajorThreat;
  final String scoreOf;
  final String improvementsTitle;
  final String improveRoof;
  final String improveElevation;
  final String improveShelter;
  final String improveVulnerable;
  final String improveLow;
  final String improveMid;
  final String improveHigh;

  const RiskStrings({
    required this.task,
    required this.homeMaterial,
    required this.floodHistory,
    required this.elevation,
    required this.nearRiver,
    required this.nearCoast,
    required this.hasElderly,
    required this.hasInfants,
    required this.riskLabel,
    required this.noMajorThreat,
    required this.scoreOf,
    required this.improvementsTitle,
    required this.improveRoof,
    required this.improveElevation,
    required this.improveShelter,
    required this.improveVulnerable,
    required this.improveLow,
    required this.improveMid,
    required this.improveHigh,
  });

  RiskStrings._empty()
      : task = '',
        homeMaterial = '',
        floodHistory = '',
        elevation = '',
        nearRiver = '',
        nearCoast = '',
        hasElderly = '',
        hasInfants = '',
        riskLabel = '',
        noMajorThreat = '',
        scoreOf = '',
        improvementsTitle = '',
        improveRoof = '',
        improveElevation = '',
        improveShelter = '',
        improveVulnerable = '',
        improveLow = '',
        improveMid = '',
        improveHigh = '';

  static RiskStrings _fromMap(Map<String, dynamic> m) => RiskStrings(
        task: m['task'] as String,
        homeMaterial: m['homeMaterial'] as String,
        floodHistory: m['floodHistory'] as String,
        elevation: m['elevation'] as String,
        nearRiver: m['nearRiver'] as String,
        nearCoast: m['nearCoast'] as String,
        hasElderly: m['hasElderly'] as String,
        hasInfants: m['hasInfants'] as String,
        riskLabel: m['riskLabel'] as String,
        noMajorThreat: m['noMajorThreat'] as String,
        scoreOf: m['scoreOf'] as String,
        improvementsTitle: m['improvementsTitle'] as String,
        improveRoof: m['improveRoof'] as String,
        improveElevation: m['improveElevation'] as String,
        improveShelter: m['improveShelter'] as String,
        improveVulnerable: m['improveVulnerable'] as String,
        improveLow: m['improveLow'] as String,
        improveMid: m['improveMid'] as String,
        improveHigh: m['improveHigh'] as String,
      );
}

RiskStrings cachedRisk = RiskStrings._empty();

Future<RiskStrings> loadRiskStrings(String? locale) async {
  return TextLoader.loadJson<RiskStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, localeCode);
    return RiskStrings._fromMap(block);
  }, locale: locale);
}

Future<void> primeRiskCache(String? locale) async {
  cachedRisk = await loadRiskStrings(locale);
}
