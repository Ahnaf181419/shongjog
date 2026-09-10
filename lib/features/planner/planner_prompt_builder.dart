import 'family_profile.dart';
import 'planner_strings_loader.dart';

/// Builds the Bangla prompt for the AI Family Disaster Planner
/// (Module A in docs/AI-FIRST-FEATURES.md).
///
/// Pure Dart — the prompt is deterministic and unit-tested. The model
/// generates the plan text; this class supplies the structured context.
/// All user-facing strings now live in `assets/prompts/planner.json`.
class PlannerPromptBuilder {
  PlannerPromptBuilder._();

  /// Build the generation prompt. Returns null when the profile is
  /// empty (no family data to personalise against).
  static String? buildPlan(FamilyProfile p, {PlannerStrings? s}) {
    final strings = s ?? cachedPlanner;
    if (p.isEmpty) return null;

    final homeTypeName = _homeTypeName(p, strings);

    final buf = StringBuffer();
    buf.writeln(strings.systemRole);
    buf.writeln(strings.task);
    buf.writeln();
    buf.writeln(strings.familyHeader);
    buf.writeln(fillTemplate(strings.memberTotal, {'count': '${p.familySize}'}));
    if (p.childrenCount > 0) {
      buf.writeln(fillTemplate(strings.children, {'count': '${p.childrenCount}'}));
    }
    if (p.elderlyCount > 0) {
      buf.writeln(fillTemplate(strings.elderly, {'count': '${p.elderlyCount}'}));
    }
    if (p.hasPets) {
      buf.writeln(strings.hasPets);
    }
    buf.writeln(fillTemplate(strings.homeType, {'homeType': homeTypeName}));
    if (p.homeType == HomeType.apartment && p.floorNumber != null) {
      buf.writeln(fillTemplate(strings.floorNumber, {'floor': '${p.floorNumber}'}));
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln(fillTemplate(strings.medicalConditions, {'conditions': p.medicalConditions.join(", ")}));
    }
    if (p.nearbyRiver) {
      buf.writeln(strings.nearbyRiver);
    }
    if (p.nearbyCoast) {
      buf.writeln(strings.nearbyCoast);
    }
    buf.writeln();
    buf.writeln(strings.includeTitle);
    buf.writeln(strings.includeItem1);
    buf.writeln(strings.includeItem2);
    buf.writeln(strings.includeItem3);
    buf.writeln(strings.includeItem4);
    buf.writeln(strings.includeItem5);
    buf.writeln();
    buf.write(strings.planLabel);

    return buf.toString();
  }

  /// Deterministic fallback plan for when the model is unavailable.
  /// Always returns a useful plan — never empty.
  static String fallbackPlan(FamilyProfile p, {PlannerStrings? s}) {
    final strings = s ?? cachedPlanner;
    final buf = StringBuffer();
    buf.writeln(strings.fallbackTitle);
    buf.writeln();
    buf.writeln(strings.fallback1);
    buf.writeln(strings.fallback2);
    buf.writeln(strings.fallback3);

    if (p.childrenCount > 0) {
      buf.writeln(strings.fallback4WithChildren);
    } else {
      buf.writeln(strings.fallback4NoChildren);
    }
    if (p.elderlyCount > 0) {
      buf.writeln(strings.fallback5WithElderly);
    } else {
      buf.writeln(strings.fallback5NoElderly);
    }
    buf.writeln(strings.fallback6);
    buf.writeln();
    buf.write(strings.fallbackHelp);
    return buf.toString();
  }

  static String _homeTypeName(FamilyProfile p, PlannerStrings s) {
    switch (p.homeType) {
      case HomeType.apartment:
        return s.homeTypeApartment;
      case HomeType.pucka:
        return s.homeTypeHouse;
      case HomeType.tinShed:
        return s.homeTypeTin;
      case HomeType.unknown:
        return s.homeTypeOther;
    }
  }
}
