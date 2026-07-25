import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  String get labelBn => switch (this) {
        DamageType.flood => 'বন্যা',
        DamageType.fire => 'আগুন',
        DamageType.collapsedBuilding => 'ধসে পড়া ভবন',
        DamageType.fallenTree => 'পড়ে যাওয়া গাছ',
        DamageType.blockedRoad => 'অবরুদ্ধ রাস্তা',
        DamageType.electricHazard => 'বৈদ্যুতিক বিপদ',
        DamageType.smoke => 'ধোঁয়া',
        DamageType.other => 'অন্যান্য',
        DamageType.unknown => 'অজানা',
      };

  static DamageType fromString(String s) {
    final lower = s.toLowerCase();
    for (final t in values) {
      if (lower.contains(t.name.toLowerCase())) return t;
    }
    return DamageType.unknown;
  }
}

enum Severity {
  low,
  medium,
  high,
  critical,
  unknown;

  /// Color used by the UI gauge (red ≥high, orange medium, green low).
  int get color => switch (this) {
        Severity.low => 0xFF66BB6A,      // green
        Severity.medium => 0xFFFFA726,   // orange
        Severity.high => 0xFFEF5350,     // red
        Severity.critical => 0xFFB71C1C, // dark red
        Severity.unknown => 0xFF9E9E9E,  // grey
      };

  String get labelBn => switch (this) {
        Severity.low => 'নিম্ন',
        Severity.medium => 'মাঝারি',
        Severity.high => 'উচ্চ',
        Severity.critical => 'অত্যন্ত উচ্চ',
        Severity.unknown => 'অজানা',
      };

  static Severity fromString(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('critical')) return Severity.critical;
    if (lower.contains('high')) return Severity.high;
    if (lower.contains('medium') || lower.contains('med')) {
      return Severity.medium;
    }
    if (lower.contains('low')) return Severity.low;
    return Severity.unknown;
  }
}

/// Structured result from a damage scan.
class DamageScanResult {
  final DamageType damageType;
  final Severity severity;
  final double confidence; // 0.0 - 1.0
  final String recommendation;
  final String description;

  const DamageScanResult({
    required this.damageType,
    required this.severity,
    required this.confidence,
    required this.recommendation,
    required this.description,
  });

  /// Bangla display strings.
  String get toBanglaType => damageType.labelBn;
  String get toBanglaSeverity => severity.labelBn;

  /// Parses the model's JSON response. Tolerant of extra wrapping
  /// (e.g. markdown fences, prose around the JSON) — extracts the
  /// first JSON object from the string.
  static DamageScanResult fromJson(Map<String, dynamic> json) {
    return DamageScanResult(
      damageType: DamageType.fromString(
          json['damageType']?.toString() ?? 'unknown'),
      severity:
          Severity.fromString(json['severity']?.toString() ?? 'unknown'),
      confidence: _parseDouble(json['confidence']),
      recommendation: json['recommendation']?.toString() ??
          'অতিরিক্ত তথ্যের জন্য আশ্রয় ট্যাব ব্যবহার করুন।',
      description: json['description']?.toString() ?? '',
    );
  }

  /// Parse a JSON string. Extracts the first JSON object and parses it.
  static DamageScanResult fromJsonString(String raw) {
    final cleaned = _extractJson(raw);
    if (cleaned == null) {
      return const DamageScanResult(
        damageType: DamageType.unknown,
        severity: Severity.unknown,
        confidence: 0.0,
        recommendation: 'ছবি বিশ্লেষণ করা যায়নি।',
        description: '',
      );
    }
    try {
      final m = jsonDecode(cleaned);
      if (m is Map<String, dynamic>) return fromJson(m);
      if (m is List && m.isNotEmpty && m.first is Map<String, dynamic>) {
        return fromJson((m.first as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('[DamageScan] JSON parse failed: $e');
    }
    return const DamageScanResult(
      damageType: DamageType.unknown,
      severity: Severity.unknown,
      confidence: 0.0,
      recommendation: 'ছবি বিশ্লেষণ করা যায়নি।',
      description: '',
    );
  }

  static double _parseDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Extract the first JSON object substring from [raw]. Strips
  /// markdown fences + surrounding prose.
  static String? _extractJson(String raw) {
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    return m?.group(0);
  }
}

/// AI Damage Scanner service (Module D in docs/AI-FIRST-FEATURES.md).
///
/// Routes image analysis through [CloudAiService] — Gemma 4 E2B has
/// no vision on-device, but Gemini has vision. The service accepts
/// the image bytes + a base64-encoded inline_data payload and parses
/// the structured JSON response.
///
/// Returns null on offline / failure / invalid key — the UI then shows
/// a clear "needs internet + API key" message rather than a spinner.
class DamageScanService {
  /// Build the structured-JSON prompt for the vision model. The
  /// model returns JSON matching [DamageScanResult.fromJson].
  static String buildPrompt() {
    return '''তুমি একটি দুর্যোগ ক্ষয়ক্ষতি বিশ্লেষক। ছবিতে দেখা ক্ষয়ক্ষতির ধরন ও তীব্রতা মূল্যায়ন করো।

ফলাফল শুধুমাত্র নিচের JSON ফরম্যাটে দাও, অন্য কিছু না:
{
  "damageType": "flood | fire | collapsedBuilding | fallenTree | blockedRoad | electricHazard | smoke | other | unknown",
  "severity": "low | medium | high | critical | unknown",
  "confidence": 0.0,
  "recommendation": "বাংলায় সুপারিশ",
  "description": "বাংলায় সংক্ষিপ্ত বর্ণনা"
}''';
  }

  /// Build the Gemini multimodal request body. Pure helper so we can
  /// unit-test the wire format without making a real HTTP call.
  static Map<String, dynamic> buildRequestBody(Uint8List imageBytes) {
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': buildPrompt()},
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
      },
    };
  }

  /// Parse a Gemini response JSON into a [DamageScanResult]. Tolerant
  /// of the model wrapping its JSON in markdown fences.
  static DamageScanResult parseResponse(String rawJson) {
    return DamageScanResult.fromJsonString(rawJson);
  }
}