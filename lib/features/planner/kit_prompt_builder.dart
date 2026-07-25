import 'family_profile.dart';

/// Builds the prompt for the AI Emergency Kit Generator
/// (Module B in docs/AI-FIRST-FEATURES.md).
class KitPromptBuilder {
  KitPromptBuilder._();

  /// Per-person water target (litres/day).
  static const _waterPerPerson = 3;

  /// Build the generation prompt. Returns null for an empty profile.
  static String? buildPrompt(FamilyProfile p) {
    if (p.isEmpty) return null;

    final buf = StringBuffer();
    buf.writeln('তুমি শঙ্গজগ। এই পরিবারের জন্য একটি ব্যক্তিগতকৃত '
        'জরুরি কিটের তালিকা তৈরি করো। বাংলায়, বাংলা সংখ্যা ব্যবহার করো। '
        'প্রতিটি আইটেমের পাশে আনুমানিক পরিমাণ লেখো।');
    buf.writeln();
    buf.writeln('পরিবার: ${p.familySize} জন।');
    if (p.childrenCount > 0) {
      buf.writeln('• শিশু আছে: ${p.childrenCount} জন — শিশু খাবার, ফর্মুলা, ডায়াপার।');
    }
    if (p.elderlyCount > 0) {
      buf.writeln('• প্রবীণ আছে: ${p.elderlyCount} জন — চিকিৎসা সরঞ্জাম।');
    }
    if (p.hasPets) {
      buf.writeln('• পোষা প্রাণী আছে — পোষা খাবার অন্তর্ভুক্ত করো।');
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln('• চিকিৎসা অবস্থা: ${p.medicalConditions.join(", ")}।');
      buf.writeln('  এই অবস্থার জন্য প্রয়োজনীয় আইটেম অন্তর্ভুক্ত করো।');
    }
    if (p.nearbyRiver || p.nearbyCoast) {
      buf.writeln('• জলমগ্ন এলাকা — লাইফ জ্যাকেট ও শুকনো ব্যাগ অন্তর্ভুক্ত করো।');
    }
    buf.writeln();
    buf.write('কিটের তালিকা:');
    return buf.toString();
  }

  /// Deterministic kit for when the model is unavailable.
  static String fallbackKit(FamilyProfile p) {
    final waterTotal = p.familySize * _waterPerPerson;
    final waterBn = _toBangla('$waterTotal');
    final foodKg = p.familySize * 2;
    final foodBn = _toBangla('$foodKg');
    final buf = StringBuffer();
    buf.writeln('জরুরি কিটের তালিকা:');
    buf.writeln();
    buf.writeln('• পানি: $waterBn লিটার/দিন (প্রতিজন $_waterPerPerson লিটার)');
    buf.writeln('• শুকনো খাবার: $foodBn কেজি');
    buf.writeln('• ফ্ল্যাশলাইট + ব্যাটারি');
    buf.writeln('• ফার্স্ট এইড বক্স');
    buf.writeln('• ওষুধ (নিয়মিত)');
    buf.writeln('• গুরুত্বপূর্ণ কাগজপত্র (জলরোধী ব্যাগে)');
    buf.writeln('• হুইসেল');
    if (p.childrenCount > 0) {
      buf.writeln('• শিশু খাবার/ফর্মুলা');
      buf.writeln('• ডায়াপার');
    }
    if (p.elderlyCount > 0) {
      buf.writeln('• প্রবীণ ওষুধের অতিরিক্ত সরবরাহ');
    }
    if (p.hasPets) {
      buf.writeln('• পোষা প্রাণীর খাবার');
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln('• বিশেষ চিকিৎসা সরঞ্জাম: ${p.medicalConditions.join(", ")}');
    }
    if (p.nearbyRiver || p.nearbyCoast) {
      buf.writeln('• লাইফ জ্যাকেট');
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