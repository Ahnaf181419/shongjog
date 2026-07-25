import 'family_profile.dart';

/// Builds the Bangla prompt for the AI Family Disaster Planner
/// (Module A in docs/AI-FIRST-FEATURES.md).
///
/// Pure Dart — the prompt is deterministic and unit-tested. The model
/// generates the plan text; this class supplies the structured context.
class PlannerPromptBuilder {
  PlannerPromptBuilder._();

  /// Build the generation prompt. Returns null when the profile is
  /// empty (no family data to personalise against).
  static String? buildPlan(FamilyProfile p) {
    if (p.isEmpty) return null;

    final buf = StringBuffer();
    buf.writeln('তুমি শঙ্গজগ, একজন উষ্ণ বাংলা দুর্যোগ সহায়ক।');
    buf.writeln('নিচের পরিবারের তথ্যের ভিত্তিতে একটি ব্যক্তিগতকৃত '
        'দুর্যোগ প্রস্তুতি পরিকল্পনা তৈরি করো। বাংলায় উত্তর দাও। '
        'বাংলা সংখ্যা (০-৯) ব্যবহার করো।');
    buf.writeln();
    buf.writeln('পরিবারের তথ্য:');
    buf.writeln('• মোট সদস্য: ${p.familySize} জন');
    if (p.childrenCount > 0) {
      buf.writeln('• শিশু: ${p.childrenCount} জন');
    }
    if (p.elderlyCount > 0) {
      buf.writeln('• প্রবীণ: ${p.elderlyCount} জন');
    }
    if (p.hasPets) {
      buf.writeln('• পোষা প্রাণী আছে');
    }
    buf.writeln('• ঘরের ধরন: ${p.homeType.labelBn}');
    if (p.homeType == HomeType.apartment && p.floorNumber != null) {
      buf.writeln('• ফ্ল্যাটের তলা: ${p.floorNumber}');
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln('• চিকিৎসা অবস্থা: ${p.medicalConditions.join(", ")}');
    }
    if (p.nearbyRiver) {
      buf.writeln('• নিকটবর্তী নদী আছে');
    }
    if (p.nearbyCoast) {
      buf.writeln('• সমুদ্রতীরের কাছে');
    }
    buf.writeln();
    buf.writeln('যা যা অন্তর্ভুক্ত করো:');
    buf.writeln('১. জরুরি পদক্ষেপ (ঘূর্ণিঝড়/বন্যা আসার আগে ও সময়)');
    buf.writeln('২. স্থানান্তর পরিকল্পনা (কোথায় যাবেন, কীভাবে)');
    buf.writeln('৩. বিশেষ সতর্কতা (শিশু, প্রবীণ, পোষা প্রাণী, চিকিৎসা)');
    buf.writeln('৪. জরুরি যোগাযোগের তালিকা');
    buf.writeln('৫. প্রস্তুতির সময়রেখা');
    buf.writeln();
    buf.write('পরিকল্পনা:');

    return buf.toString();
  }

  /// Deterministic fallback plan for when the model is unavailable.
  /// Always returns a useful plan — never empty.
  static String fallbackPlan(FamilyProfile p) {
    final buf = StringBuffer();
    buf.writeln('সাধারণ দুর্যোগ প্রস্তুতি পরিকল্পনা:');
    buf.writeln();
    buf.writeln('১. নিরাপদ শূন্যস্থান চিহ্নিত করুন (নিকটস্থ সাইক্লোন শেল্টার)।');
    buf.writeln('২. জরুরি কিট প্রস্তুত রাখুন (পানি, খাবার, ওষুধ, ফ্ল্যাশলাইট)।');
    buf.writeln('৩. গুরুত্বপূর্ণ কাগজপত্র জলরোধী ব্যাগে রাখুন।');

    if (p.childrenCount > 0) {
      buf.writeln('৪. শিশুদের জন্য বিশেষ খাবার ও কাপড় প্রস্তুত রাখুন।');
    } else {
      buf.writeln('৪. প্রতিটি সদস্যের জন্য পর্যাপ্ত খাবার ও পানি রাখুন।');
    }
    if (p.elderlyCount > 0) {
      buf.writeln('৫. প্রবীণদের ওষুধ ও বিশেষ যত্নের তালিকা তৈরি করুন।');
    } else {
      buf.writeln('৫. প্রতিটি সদস্যের দায়িত্ব নির্ধারণ করুন।');
    }
    buf.writeln('৬. স্থানান্তরের রুট আগে থেকে জেনে রাখুন।');
    buf.writeln();
    buf.write('জরুরি সাহায্যের জন্য ৯৯৯ এ কল করুন।');
    return buf.toString();
  }
}
