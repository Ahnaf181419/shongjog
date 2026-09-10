import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/planner.json';

class PlannerStrings {
  final String systemRole;
  final String task;
  final String familyHeader;
  final String memberTotal;
  final String children;
  final String elderly;
  final String hasPets;
  final String homeType;
  final String floorNumber;
  final String medicalConditions;
  final String nearbyRiver;
  final String nearbyCoast;
  final String includeTitle;
  final String includeItem1;
  final String includeItem2;
  final String includeItem3;
  final String includeItem4;
  final String includeItem5;
  final String planLabel;
  final String fallbackTitle;
  final String fallback1;
  final String fallback2;
  final String fallback3;
  final String fallback4WithChildren;
  final String fallback4NoChildren;
  final String fallback5WithElderly;
  final String fallback5NoElderly;
  final String fallback6;
  final String fallbackHelp;
  final String homeTypeApartment;
  final String homeTypeHouse;
  final String homeTypeTin;
  final String homeTypeMud;
  final String homeTypeOther;

  const PlannerStrings({
    required this.systemRole,
    required this.task,
    required this.familyHeader,
    required this.memberTotal,
    required this.children,
    required this.elderly,
    required this.hasPets,
    required this.homeType,
    required this.floorNumber,
    required this.medicalConditions,
    required this.nearbyRiver,
    required this.nearbyCoast,
    required this.includeTitle,
    required this.includeItem1,
    required this.includeItem2,
    required this.includeItem3,
    required this.includeItem4,
    required this.includeItem5,
    required this.planLabel,
    required this.fallbackTitle,
    required this.fallback1,
    required this.fallback2,
    required this.fallback3,
    required this.fallback4WithChildren,
    required this.fallback4NoChildren,
    required this.fallback5WithElderly,
    required this.fallback5NoElderly,
    required this.fallback6,
    required this.fallbackHelp,
    required this.homeTypeApartment,
    required this.homeTypeHouse,
    required this.homeTypeTin,
    required this.homeTypeMud,
    required this.homeTypeOther,
  });

  static PlannerStrings _fromMap(Map<String, dynamic> m) => PlannerStrings(
        systemRole: m['systemRole'] as String,
        task: m['task'] as String,
        familyHeader: m['familyHeader'] as String,
        memberTotal: m['memberTotal'] as String,
        children: m['children'] as String,
        elderly: m['elderly'] as String,
        hasPets: m['hasPets'] as String,
        homeType: m['homeType'] as String,
        floorNumber: m['floorNumber'] as String,
        medicalConditions: m['medicalConditions'] as String,
        nearbyRiver: m['nearbyRiver'] as String,
        nearbyCoast: m['nearbyCoast'] as String,
        includeTitle: m['includeTitle'] as String,
        includeItem1: m['includeItem1'] as String,
        includeItem2: m['includeItem2'] as String,
        includeItem3: m['includeItem3'] as String,
        includeItem4: m['includeItem4'] as String,
        includeItem5: m['includeItem5'] as String,
        planLabel: m['planLabel'] as String,
        fallbackTitle: m['fallbackTitle'] as String,
        fallback1: m['fallback1'] as String,
        fallback2: m['fallback2'] as String,
        fallback3: m['fallback3'] as String,
        fallback4WithChildren: m['fallback4WithChildren'] as String,
        fallback4NoChildren: m['fallback4NoChildren'] as String,
        fallback5WithElderly: m['fallback5WithElderly'] as String,
        fallback5NoElderly: m['fallback5NoElderly'] as String,
        fallback6: m['fallback6'] as String,
        fallbackHelp: m['fallbackHelp'] as String,
        homeTypeApartment: m['homeTypeApartment'] as String,
        homeTypeHouse: m['homeTypeHouse'] as String,
        homeTypeTin: m['homeTypeTin'] as String,
        homeTypeMud: m['homeTypeMud'] as String,
        homeTypeOther: m['homeTypeOther'] as String,
      );
}

PlannerStrings cachedPlanner = PlannerStrings(
  systemRole: '', task: '', familyHeader: '', memberTotal: '',
  children: '', elderly: '', hasPets: '', homeType: '', floorNumber: '',
  medicalConditions: '', nearbyRiver: '', nearbyCoast: '',
  includeTitle: '', includeItem1: '', includeItem2: '',
  includeItem3: '', includeItem4: '', includeItem5: '', planLabel: '',
  fallbackTitle: '', fallback1: '', fallback2: '', fallback3: '',
  fallback4WithChildren: '', fallback4NoChildren: '',
  fallback5WithElderly: '', fallback5NoElderly: '', fallback6: '', fallbackHelp: '',
  homeTypeApartment: '', homeTypeHouse: '', homeTypeTin: '', homeTypeMud: '', homeTypeOther: '',
);

Future<PlannerStrings> loadPlannerStrings(String? locale) async {
  return TextLoader.loadJson<PlannerStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, locale);
    return PlannerStrings._fromMap(block);
  });
}

Future<void> primePlannerCache(String? locale) async {
  cachedPlanner = await loadPlannerStrings(locale);
}

String fillTemplate(String tmpl, Map<String, String> vars) {
  var out = tmpl;
  vars.forEach((k, v) {
    out = out.replaceAll('{$k}', v);
  });
  return out;
}
