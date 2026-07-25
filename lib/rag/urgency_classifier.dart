/// Urgency classifier — routes queries by clinical urgency to decide
/// whether Gemma should use thinking mode (deliberation) or not (reflex).
///
/// Critical emergencies (choking, arterial bleeding, drowning) need an
/// answer in seconds — thinking OFF for max speed. Ambiguous/multi-symptom
/// queries benefit from reasoning — thinking ON.
///
/// Pure-Dart, no dependencies. Keyword-based, deterministic.
library;

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// Three urgency tiers.
enum UrgencyLevel {
  /// Life-threatening, seconds matter (choking, cardiac, severe bleeding).
  /// Thinking OFF — reflex path, maximum generation speed.
  critical,

  /// Serious but not immediately life-threatening (snakebite, fever).
  /// Thinking ON — deliberate reasoning.
  urgent,

  /// Informational / preparedness. Thinking ON.
  routine,
}

/// Result of classifying a query.
class UrgencyResult {
  final UrgencyLevel level;
  final bool enableThinking;

  /// Human-readable Bangla label for the urgency badge.
  final String labelBn;

  const UrgencyResult._(this.level, this.enableThinking, this.labelBn);

  static const critical =
      UrgencyResult._(UrgencyLevel.critical, false, 'জরুরি');
  static const urgent =
      UrgencyResult._(UrgencyLevel.urgent, true, 'তাগিদপূর্ণ');
  static const routine =
      UrgencyResult._(UrgencyLevel.routine, true, 'সাধারণ');
}

extension UrgencyLevelLabel on UrgencyLevel {
  String label(BuildContext context) => switch (this) {
    UrgencyLevel.critical => AppLocalizations.of(context).urgencyCritical,
    UrgencyLevel.urgent => AppLocalizations.of(context).urgencyUrgent,
    UrgencyLevel.routine => AppLocalizations.of(context).urgencyNormal,
  };
}

/// Classifies a Bangla emergency query into an urgency tier.
///
/// Uses keyword matching against curated lists. The classifier is
/// intentionally conservative: when in doubt, route to `urgent` (thinking
/// on) rather than `critical` — wrong speed is better than wrong answer.
class UrgencyClassifier {
  /// Keywords that indicate a critical, seconds-matter emergency.
  /// Thinking mode is turned OFF for these — the model must answer fast.
  static const _criticalKeywords = [
    // Breathing / cardiac
    'শ্বাস নিতে পারছে', 'শ্বাসকষ্ট', 'নিঃশ্বাস', 'হার্ট', 'বুকে ব্যথা',
    'হৃদযন্ত্র', 'cardiac', 'choking', 'अचকिंग',
    // Drowning (immediate)
    'ডুবে', 'পানিতে ডুবে', 'ডুবে গেছে', 'নিশ্বাস বন্ধ',
    // Severe bleeding
    'রক্ত গড়াচ্ছে', 'প্রচুর রক্ত', 'ধমনী',
    // Unconscious
    'জ্ঞান হারিয়ে', 'অজ্ঞান', 'নড়ছে না',
  ];

  /// Keywords that indicate a serious but not seconds-critical situation.
  static const _urgentKeywords = [
    'সাপ', 'সাপে', 'কামড়', 'কামড়া', 'বিষ',
    'জ্বর', 'বমি', 'ডায়রিয়া', 'পেটে', 'রক্ত',
    'গর্ভবতী', 'গর্ভে', 'প্রসব',
    'শিশু', 'বাচ্চা',
    'কাটা', 'পোড়া', 'আগুন',
    'বন্যা', 'ঘূর্ণিঝড়', 'দুর্যোগ',
    'অসুস্থ', 'ব্যথা',
    'emergency', 'fever', 'bleeding', 'snake',
  ];

  /// Classify a query and return the urgency + thinking-mode recommendation.
  static UrgencyResult classify(String query) {
    final q = query.toLowerCase();

    // Check critical first — these override urgent.
    for (final kw in _criticalKeywords) {
      if (q.contains(kw.toLowerCase())) {
        return UrgencyResult.critical;
      }
    }

    // Then check urgent.
    for (final kw in _urgentKeywords) {
      if (q.contains(kw.toLowerCase())) {
        return UrgencyResult.urgent;
      }
    }

    // Default: routine.
    return UrgencyResult.routine;
  }
}
