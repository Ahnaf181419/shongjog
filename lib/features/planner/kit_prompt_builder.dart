import 'family_profile.dart';
import 'kit_strings_loader.dart';
import 'planner_strings_loader.dart' show fillTemplate;

/// Builds the prompt for the AI Emergency Kit Generator
/// (Module B in docs/AI-FIRST-FEATURES.md).
class KitPromptBuilder {
  KitPromptBuilder._();

  /// Per-person water target (litres/day).
  static const _waterPerPerson = 3;

  /// Build the generation prompt. Returns null for an empty profile.
  static String? buildPrompt(FamilyProfile p, {KitStrings? s}) {
    final strings = s ?? cachedKit;
    if (p.isEmpty) return null;

    final buf = StringBuffer();
    buf.writeln(strings.systemRole);
    buf.writeln();
    buf.writeln(fillTemplate(strings.familyLine, {'count': '${p.familySize}'}));
    if (p.childrenCount > 0) {
      buf.writeln(fillTemplate(strings.children, {'count': '${p.childrenCount}'}));
    }
    if (p.elderlyCount > 0) {
      buf.writeln(fillTemplate(strings.elderly, {'count': '${p.elderlyCount}'}));
    }
    if (p.hasPets) {
      buf.writeln(strings.pets);
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln(fillTemplate(strings.medical, {'conditions': p.medicalConditions.join(", ")}));
      buf.writeln(strings.medicalFollowup);
    }
    if (p.nearbyRiver || p.nearbyCoast) {
      buf.writeln(strings.waterZone);
    }
    buf.writeln();
    buf.write(strings.kitLabel);
    return buf.toString();
  }

  /// Deterministic kit for when the model is unavailable.
  static String fallbackKit(FamilyProfile p, {KitStrings? s}) {
    final strings = s ?? cachedKit;
    final waterTotal = p.familySize * _waterPerPerson;
    final waterBn = _toBangla('$waterTotal');
    final foodKg = p.familySize * 2;
    final foodBn = _toBangla('$foodKg');
    final buf = StringBuffer();
    buf.writeln(strings.fallbackTitle);
    buf.writeln();
    buf.writeln(fillTemplate(strings.fallbackWater, {
      'litres': waterBn,
      'perPerson': _toBangla('$_waterPerPerson'),
    }));
    buf.writeln(fillTemplate(strings.fallbackFood, {'kg': foodBn}));
    buf.writeln(strings.fallbackFlashlight);
    buf.writeln(strings.fallbackFirstAid);
    buf.writeln(strings.fallbackMedicine);
    buf.writeln(strings.fallbackDocuments);
    buf.writeln(strings.fallbackWhistle);
    if (p.childrenCount > 0) {
      buf.writeln(strings.fallbackBabyFood);
      buf.writeln(strings.fallbackDiapers);
    }
    if (p.elderlyCount > 0) {
      buf.writeln(strings.fallbackElderMedicine);
    }
    if (p.hasPets) {
      buf.writeln(strings.fallbackPetFood);
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln(fillTemplate(strings.fallbackMedicalSpecial, {
        'conditions': p.medicalConditions.join(", "),
      }));
    }
    if (p.nearbyRiver || p.nearbyCoast) {
      buf.writeln(strings.fallbackLifeJacket);
    }
    return buf.toString();
  }

  /// Convert ASCII digits to Bengali numerals (০-৯).
  static String _toBangla(String s) {
    const map = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }
}
