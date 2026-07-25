/// Risk-input enums for Module C (AI Risk Assessment).
/// Pure-Dart + Bangla labels + fromString parsers — mirror the
/// FamilyProfile HomeType pattern.
library;

enum HomeMaterial {
  tinShed,
  halfPucka,
  pucka,
  apartment;

  String get labelBn => switch (this) {
        HomeMaterial.tinShed => 'টিনের ঘর',
        HomeMaterial.halfPucka => 'আধা পাকা',
        HomeMaterial.pucka => 'পাকা',
        HomeMaterial.apartment => 'অ্যাপার্টমেন্ট',
      };

  static HomeMaterial fromString(String s) => switch (s) {
        'টিনের ঘর' => HomeMaterial.tinShed,
        'আধা পাকা' => HomeMaterial.halfPucka,
        'পাকা' => HomeMaterial.pucka,
        'অ্যাপার্টমেন্ট' => HomeMaterial.apartment,
        _ => HomeMaterial.tinShed,
      };
}

enum FloodHistory {
  none,
  minor,
  major;

  String get labelBn => switch (this) {
        FloodHistory.none => 'কখনো না',
        FloodHistory.minor => 'মাঝারি',
        FloodHistory.major => 'প্রধান',
      };

  static FloodHistory fromString(String s) => switch (s) {
        'কখনো না' => FloodHistory.none,
        'মাঝারি' => FloodHistory.minor,
        'প্রধান' => FloodHistory.major,
        _ => FloodHistory.none,
      };
}

enum Elevation {
  low,
  mid,
  high;

  String get labelBn => switch (this) {
        Elevation.low => 'নিচু',
        Elevation.mid => 'মাঝারি',
        Elevation.high => 'উঁচু',
      };

  static Elevation fromString(String s) => switch (s) {
        'নিচু' => Elevation.low,
        'মাঝারি' => Elevation.mid,
        'উঁচু' => Elevation.high,
        _ => Elevation.mid,
      };
}

/// Risk inputs collected from the questionnaire.
class RiskInputs {
  final HomeMaterial homeMaterial;
  final FloodHistory previousFloods;
  final Elevation elevation;
  final bool nearRiver;
  final bool nearCoast;
  final bool hasElderly;
  final bool hasInfants;

  const RiskInputs({
    this.homeMaterial = HomeMaterial.tinShed,
    this.previousFloods = FloodHistory.none,
    this.elevation = Elevation.mid,
    this.nearRiver = false,
    this.nearCoast = false,
    this.hasElderly = false,
    this.hasInfants = false,
  });

  static const empty = RiskInputs();

  /// Has the user filled in any meaningful data beyond the defaults?
  bool get hasContent =>
      previousFloods != FloodHistory.none ||
      nearRiver ||
      nearCoast ||
      hasElderly ||
      hasInfants;
}

/// Risk score + Bangla explanation.
class RiskResult {
  final int score;       // 1-10 (10 = highest risk)
  final String summary;  // Bangla one-sentence explanation
  final String improvements; // suggestions

  const RiskResult({
    required this.score,
    required this.summary,
    required this.improvements,
  });
}

/// AI Risk Assessment prompt + deterministic fallback (Module C).
class RiskPromptBuilder {
  RiskPromptBuilder._();

  /// Build the model prompt. Returns null if all defaults (nothing to assess).
  static String? buildPrompt(RiskInputs r) {
    if (!r.hasContent &&
        r.homeMaterial == HomeMaterial.tinShed &&
        r.elevation == Elevation.mid) {
      // Empty / pure-default state: nothing useful to assess.
      return null;
    }

    final buf = StringBuffer();
    buf.writeln('তুমি শঙ্গজগ। এই বাড়ি ও পরিবারের জন্য একটি '
        'ঝুঁকি মূল্যায়ন করো। ১-১০ এর মধ্যে একটি ঝুঁকি স্কোর '
        'দাও (১০ = সর্বোচ্চ ঝুঁকি) এবং একটি ছোট ব্যাখ্যা ও '
        'উন্নতির পরামর্শ দাও। বাংলায়, বাংলা সংখ্যা ব্যবহার করো।');
    buf.writeln();
    buf.writeln('• ঘরের ধরন: ${r.homeMaterial.labelBn}');
    buf.writeln('• পূর্ববর্তী বন্যার ইতিহাস: ${r.previousFloods.labelBn}');
    buf.writeln('• উচ্চতা: ${r.elevation.labelBn}');
    if (r.nearRiver) buf.writeln('• নিকটবর্তী নদী আছে');
    if (r.nearCoast) buf.writeln('• সমুদ্রতীরের কাছে');
    if (r.hasElderly) buf.writeln('• পরিবারে প্রবীণ আছে');
    if (r.hasInfants) buf.writeln('• পরিবারে শিশু আছে');
    buf.writeln();
    buf.write('ঝুঁকি মূল্যায়ন:');
    return buf.toString();
  }

  /// Deterministic risk score + summary, 1-10.
  /// Higher = more risk. Weighted score with a Bangla explanation.
  static RiskResult fallbackScore(RiskInputs r) {
    var score = 1;

    // Home material (1-4 points)
    score += switch (r.homeMaterial) {
      HomeMaterial.tinShed => 4,
      HomeMaterial.halfPucka => 3,
      HomeMaterial.pucka => 1,
      HomeMaterial.apartment => 1,
    };

    // Flood history (0-3)
    score += switch (r.previousFloods) {
      FloodHistory.none => 0,
      FloodHistory.minor => 2,
      FloodHistory.major => 3,
    };

    // Elevation (0-3)
    score += switch (r.elevation) {
      Elevation.high => 0,
      Elevation.mid => 1,
      Elevation.low => 3,
    };

    // Nearby hazards
    if (r.nearRiver) score += 2;
    if (r.nearCoast) score += 2;

    // Vulnerable population
    if (r.hasElderly) score += 1;
    if (r.hasInfants) score += 1;

    // Clamp 1-10.
    score = score.clamp(1, 10);

    final summary = _summaryForScore(score, r);
    final improvements = _improvementsForScore(score, r);

    return RiskResult(
      score: score,
      summary: summary,
      improvements: improvements,
    );
  }

  static String _summaryForScore(int score, RiskInputs r) {
    final bn = _bn(score);
    final hazards = <String>[];
    if (r.nearRiver) hazards.add('নদী');
    if (r.nearCoast) hazards.add('সমুদ্র');
    final hazardsStr = hazards.isEmpty
        ? 'কোনো বড় হুমকি নেই'
        : hazards.join(' ও ');

    return 'আপনার ঝুঁকি স্কোর: $bn/১০। '
        '${r.homeMaterial.labelBn} এবং $hazardsStr।';
  }

  static String _improvementsForScore(int score, RiskInputs r) {
    final buf = StringBuffer();
    buf.writeln('উন্নতির পরামর্শ:');
    if (r.homeMaterial == HomeMaterial.tinShed) {
      buf.writeln('• ঘরের ছাউনি শক্তিশালী করুন বা পাকা ঘরে স্থানান্তরিত হন।');
    }
    if (r.elevation == Elevation.low) {
      buf.writeln('• উঁচু স্থানে স্থানান্তরের পরিকল্পনা রাখুন।');
    }
    if (r.nearRiver || r.nearCoast) {
      buf.writeln('• নদী/সমুদ্র থেকে কমপক্ষে ১ কিমি দূরে নিরাপদ আশ্রয় চিহ্নিত করুন।');
    }
    if (r.hasElderly || r.hasInfants) {
      buf.writeln('• ঝুঁকিপূর্ণ সময়ে প্রবীণ/শিশুদের জন্য বিশেষ সরঞ্জাম প্রস্তুত রাখুন।');
    }
    if (score <= 3) {
      buf.writeln('• আপনার ঝুঁকি কম — নিয়মিত প্রস্তুতি অব্যাহত রাখুন।');
    } else if (score <= 6) {
      buf.writeln('• আপনার ঝুঁকি মাঝারি — দুর্যোগ প্রস্তুতি পরিকল্পনা তৈরি করুন।');
    } else {
      buf.writeln('• আপনার ঝুঁকি উচ্চ — জরুরি স্থানান্তরের পরিকল্পনা করুন।');
    }
    return buf.toString();
  }

  /// Convert int to Bengali digits string.
  static String _bn(int n) => n.toString().split('').map((c) {
    const m = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return m[c] ?? c;
  }).join();
}