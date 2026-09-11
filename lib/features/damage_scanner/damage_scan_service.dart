import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'damage_scan_strings_loader.dart';

/// Damage category detected by the AI Damage Scanner (Module D).
enum DamageType {
  flood,
  fire,
  collapsedBuilding,
  fallenTree,
  blockedRoad,
  electricHazard,
  smoke,
  other,
  unknown;


  String label(AppLocalizations l10n) => switch (this) {
        DamageType.flood => l10n.damageTypeFlood,
        DamageType.fire => l10n.damageTypeFire,
        DamageType.collapsedBuilding => l10n.damageTypeCollapsedBuilding,
        DamageType.fallenTree => l10n.damageTypeFallenTree,
        DamageType.blockedRoad => l10n.damageTypeBlockedRoad,
        DamageType.electricHazard => l10n.damageTypeElectricHazard,
        DamageType.smoke => l10n.damageTypeSmoke,
        DamageType.other => l10n.damageTypeOther,
        DamageType.unknown => l10n.damageTypeUnknown,
      };
}

/// Severity bands the scanner emits.
enum Severity {
  low,
  medium,
  high,
  critical,
  unknown;


  String label(AppLocalizations l10n) => switch (this) {
        Severity.low => l10n.damageSeverityLow,
        Severity.medium => l10n.damageSeverityMedium,
        Severity.high => l10n.damageSeverityHigh,
        Severity.critical => l10n.damageSeverityCritical,
        Severity.unknown => l10n.damageSeverityUnknown,
      };

  Color get color => switch (this) {
        Severity.low => const Color(0xFF4CAF50),
        Severity.medium => const Color(0xFFFFA726),
        Severity.high => const Color(0xFFEF5350),
        Severity.critical => const Color(0xFFB71C1C),
        Severity.unknown => const Color(0xFF9E9E9E),
      };
}

/// Structured result of one damage-scan call.
class DamageScanResult {
  final DamageType damageType;
  final Severity severity;
  final double confidence; // 0.0 – 1.0
  final String recommendation;
  final String description;

  const DamageScanResult({
    required this.damageType,
    required this.severity,
    required this.confidence,
    required this.recommendation,
    required this.description,
  });

// fromJson defined later in this file.

  /// Empty / placeholder result when the model fails to analyse the image.
  factory DamageScanResult.unanalysable({DamageScanStrings? s}) {
    final strings = s ?? cachedDamageScan;
    return DamageScanResult(
      damageType: DamageType.unknown,
      severity: Severity.unknown,
      confidence: 0.0,
      recommendation: strings.unanalysable,
      description: strings.unanalysable,
    );
  }

  /// Parse a parsed JSON map into a [DamageScanResult].
  factory DamageScanResult.fromJson(Map<String, dynamic> j, {DamageScanStrings? s}) =>
      DamageScanResult(
        damageType: _parseDamageType(j['damageType'] as String?),
        severity: _parseSeverity(j['severity'] as String?),
        confidence: (j['confidence'] as num? ?? 0.0).toDouble(),
        recommendation: j['recommendation'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );

  /// Parse a raw JSON string into a [DamageScanResult].
  static DamageScanResult fromJsonString(String raw, {DamageScanStrings? s}) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return DamageScanResult.fromJson(m, s: s);
    } catch (_) {
      return DamageScanResult.unanalysable(s: s);
    }
  }

  static DamageType _parseDamageType(String? raw) {
    if (raw == null) return DamageType.unknown;
    final norm = raw.toLowerCase().replaceAll('_', '');
    for (final t in DamageType.values) {
      if (t.name.toLowerCase() == norm) return t;
    }
    return DamageType.unknown;
  }

  static Severity _parseSeverity(String? raw) {
    if (raw == null) return Severity.unknown;
    final norm = raw.toLowerCase();
    for (final s in Severity.values) {
      if (s.name.toLowerCase() == norm) return s;
    }
    return Severity.unknown;
  }
}

/// Build the structured-JSON prompt for the vision model. The
/// model returns JSON matching [DamageScanResult.fromJson].
String buildDamageScanPrompt({DamageScanStrings? s}) {
  final strings = s ?? cachedDamageScan;
  return '''${strings.systemRole}

${strings.instruction}
{
  "damageType": "flood | fire | collapsedBuilding | fallenTree | blockedRoad | electricHazard | smoke | other | unknown",
  "severity": "low | medium | high | critical | unknown",
  "confidence": 0.0,
${strings.schemaHint}
}''';
}

/// AI Damage Scanner service (Module D in docs/AI-FIRST-FEATURES.md).
///
/// Routes image analysis through [CloudAiService] — Gemma 4 E2B has
/// no vision on-device, but Gemini has vision. The service accepts
/// the image bytes + a base64-encoded inline_data payload and parses
/// the structured JSON response.
class DamageScanService {
  /// Build the structured-JSON prompt for the vision model.
  static String buildPrompt({DamageScanStrings? s}) => buildDamageScanPrompt(s: s);

  /// Build the Gemini multimodal request body.
  static Map<String, dynamic> buildRequestBody(Uint8List imageBytes, {DamageScanStrings? s}) {
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': buildPrompt(s: s)},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(imageBytes),
              }
            },
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1024,
        'thinkingConfig': {'thinkingBudget': 0},
        'responseMimeType': 'application/json',
      },
    };
  }

  /// Parse a JSON string into a [DamageScanResult]. Convenience for callers
  /// that already have a string (e.g. raw HTTP response body).
  static DamageScanResult fromJsonString(String raw, {DamageScanStrings? s}) =>
      parseResponse(raw, s: s);

  /// Parse a Gemini response JSON into a [DamageScanResult]. Tolerant
  /// of the model wrapping its JSON in markdown fences.
  static DamageScanResult parseResponse(String raw, {DamageScanStrings? s}) {
    final json = _extractJson(raw);
    if (json == null) return DamageScanResult.unanalysable(s: s);
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return DamageScanResult.fromJson(m);
    } catch (e, st) {
      debugPrint('[DamageScan] parse failed: $e\n$st');
      return DamageScanResult.unanalysable(s: s);
    }
  }

  /// Extract the first JSON object substring from [raw].
  static String? _extractJson(String raw) {
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    return m?.group(0);
  }
}

