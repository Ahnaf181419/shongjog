/// Risk-input enums for Module C (AI Risk Assessment).
/// Pure-Dart + Bangla labels + fromString parsers — mirror the
/// FamilyProfile HomeType pattern.
library;

import 'planner_strings_loader.dart' show fillTemplate;
import 'risk_strings_loader.dart';

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
  static String? buildPrompt(RiskInputs r, {RiskStrings? s}) {
    final strings = s ?? cachedRisk;
    if (!r.hasContent &&
        r.homeMaterial == HomeMaterial.tinShed &&
        r.elevation == Elevation.mid) {
      return null;
    }

    final buf = StringBuffer();
    buf.writeln(strings.task);
    buf.writeln();
    buf.writeln(fillTemplate(strings.homeMaterial, {'material': r.homeMaterial.labelBn}));
    buf.writeln(fillTemplate(strings.floodHistory, {'history': r.previousFloods.labelBn}));
    buf.writeln(fillTemplate(strings.elevation, {'elevation': r.elevation.labelBn}));
    if (r.nearRiver) buf.writeln(strings.nearRiver);
    if (r.nearCoast) buf.writeln(strings.nearCoast);
    if (r.hasElderly) buf.writeln(strings.hasElderly);
    if (r.hasInfants) buf.writeln(strings.hasInfants);
    buf.writeln();
    buf.write(strings.riskLabel);
    return buf.toString();
  }

  /// Deterministic risk score + summary, 1-10.
  /// Higher = more risk. Weighted score with a Bangla explanation.
  static RiskResult fallbackScore(RiskInputs r, {RiskStrings? s}) {
    final strings = s ?? cachedRisk;
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

    final summary = _summaryForScore(score, r, strings);
    final improvements = _improvementsForScore(score, r, strings);

    return RiskResult(
      score: score,
      summary: summary,
      improvements: improvements,
    );
  }

  static String _summaryForScore(int score, RiskInputs r, RiskStrings s) {
    final bn = _bn(score);
    final hazards = <String>[];
    if (r.nearRiver) hazards.add('নদী');
    if (r.nearCoast) hazards.add('সমুদ্র');
    final hazardsStr = hazards.isEmpty ? s.noMajorThreat : hazards.join(' ও ');

    return fillTemplate(s.scoreOf, {
      'score': bn,
      'material': r.homeMaterial.labelBn,
      'hazards': hazardsStr,
    });
  }

  static String _improvementsForScore(int score, RiskInputs r, RiskStrings s) {
    final buf = StringBuffer();
    buf.writeln(s.improvementsTitle);
    if (r.homeMaterial == HomeMaterial.tinShed) {
      buf.writeln(s.improveRoof);
    }
    if (r.elevation == Elevation.low) {
      buf.writeln(s.improveElevation);
    }
    if (r.nearRiver || r.nearCoast) {
      buf.writeln(s.improveShelter);
    }
    if (r.hasElderly || r.hasInfants) {
      buf.writeln(s.improveVulnerable);
    }
    if (score <= 3) {
      buf.writeln(s.improveLow);
    } else if (score <= 6) {
      buf.writeln(s.improveMid);
    } else {
      buf.writeln(s.improveHigh);
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
