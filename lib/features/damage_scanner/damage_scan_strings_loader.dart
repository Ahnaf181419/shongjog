import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/damage_scan.json';

class DamageScanStrings {
  final String systemRole;
  final String instruction;
  final String schemaHint;
  final String shelterHint;
  final String unanalysable;
  final String damageTypeFlood;
  final String damageTypeFire;
  final String damageTypeCollapsedBuilding;
  final String damageTypeFallenTree;
  final String damageTypeBlockedRoad;
  final String damageTypeElectricHazard;
  final String damageTypeSmoke;
  final String damageTypeOther;
  final String damageTypeUnknown;
  final String severityLow;
  final String severityMedium;
  final String severityHigh;
  final String severityCritical;
  final String severityUnknown;

  const DamageScanStrings({
    required this.systemRole,
    required this.instruction,
    required this.schemaHint,
    required this.shelterHint,
    required this.unanalysable,
    required this.damageTypeFlood,
    required this.damageTypeFire,
    required this.damageTypeCollapsedBuilding,
    required this.damageTypeFallenTree,
    required this.damageTypeBlockedRoad,
    required this.damageTypeElectricHazard,
    required this.damageTypeSmoke,
    required this.damageTypeOther,
    required this.damageTypeUnknown,
    required this.severityLow,
    required this.severityMedium,
    required this.severityHigh,
    required this.severityCritical,
    required this.severityUnknown,
  });

  DamageScanStrings._empty()
      : systemRole = '',
        instruction = '',
        schemaHint = '',
        shelterHint = '',
        unanalysable = '',
        damageTypeFlood = '',
        damageTypeFire = '',
        damageTypeCollapsedBuilding = '',
        damageTypeFallenTree = '',
        damageTypeBlockedRoad = '',
        damageTypeElectricHazard = '',
        damageTypeSmoke = '',
        damageTypeOther = '',
        damageTypeUnknown = '',
        severityLow = '',
        severityMedium = '',
        severityHigh = '',
        severityCritical = '',
        severityUnknown = '';

  static DamageScanStrings _fromMap(Map<String, dynamic> m) => DamageScanStrings(
        systemRole: m['systemRole'] as String,
        instruction: m['instruction'] as String,
        schemaHint: m['schemaHint'] as String,
        shelterHint: m['shelterHint'] as String,
        unanalysable: m['unanalysable'] as String,
        damageTypeFlood: m['damageType_flood'] as String,
        damageTypeFire: m['damageType_fire'] as String,
        damageTypeCollapsedBuilding: m['damageType_collapsedBuilding'] as String,
        damageTypeFallenTree: m['damageType_fallenTree'] as String,
        damageTypeBlockedRoad: m['damageType_blockedRoad'] as String,
        damageTypeElectricHazard: m['damageType_electricHazard'] as String,
        damageTypeSmoke: m['damageType_smoke'] as String,
        damageTypeOther: m['damageType_other'] as String,
        damageTypeUnknown: m['damageType_unknown'] as String,
        severityLow: m['severity_low'] as String,
        severityMedium: m['severity_medium'] as String,
        severityHigh: m['severity_high'] as String,
        severityCritical: m['severity_critical'] as String,
        severityUnknown: m['severity_unknown'] as String,
      );
}

DamageScanStrings cachedDamageScan = DamageScanStrings._empty();

Future<DamageScanStrings> loadDamageScanStrings(String? locale) async {
  return TextLoader.loadJson<DamageScanStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, localeCode);
    return DamageScanStrings._fromMap(block);
  }, locale: locale);
}
