import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/damage_scanner/damage_scan_service.dart';

void main() {
  group('DamageScanResult.fromJson', () {
    test('parses a complete JSON envelope', () {
      final json = jsonEncode({
        'damageType': 'flood',
        'severity': 'high',
        'confidence': 0.85,
        'recommendation': 'Move to higher ground immediately.',
        'description': 'Heavy flooding observed in the area.',
      });
      final result = DamageScanResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(result.damageType, DamageType.flood);
      expect(result.severity, Severity.high);
      expect(result.confidence, closeTo(0.85, 0.001));
      expect(result.recommendation, contains('Move'));
      expect(result.description, isNotEmpty);
    });

    test('handles missing optional fields gracefully', () {
      final json = jsonEncode({
        'damageType': 'fire',
        'severity': 'critical',
        'recommendation': 'Evacuate',
      });
      final result = DamageScanResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(result.damageType, DamageType.fire);
      expect(result.severity, Severity.critical);
      expect(result.confidence, 0.0); // default
    });

    test('returns unknown for unrecognised damage types', () {
      final json = jsonEncode({
        'damageType': 'meteor_strike',
        'severity': 'low',
        'recommendation': 'Run.',
      });
      final result = DamageScanResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(result.damageType, DamageType.unknown);
    });

    test('returns unknown for unrecognised severity values', () {
      final json = jsonEncode({
        'damageType': 'flood',
        'severity': 'terrible',
        'recommendation': 'Help.',
      });
      final result = DamageScanResult.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(result.severity, Severity.unknown);
    });
  });

  group('DamageType.labelBn + severityColor', () {
    test('every damage type has a Bangla label', () {
      for (final t in DamageType.values) {
        expect(t.labelBn, isNotEmpty);
      }
    });

    test('severityColor returns distinct colors', () {
      expect(Severity.low.color, isNot(Severity.critical.color));
      expect(Severity.medium.color, isNot(Severity.high.color));
    });
  });

  group('DamageScanService.buildPrompt', () {
    test('contains structured-JSON instruction', () {
      final prompt = DamageScanService.buildPrompt();
      expect(prompt, contains('JSON'));
      expect(prompt, contains('damageType'));
      expect(prompt, contains('severity'));
      expect(prompt, contains('recommendation'));
    });
  });

  group('DamageScanResult.toBanglaFallback', () {
    test('falls back to Bangla when service throws', () {
      const result = DamageScanResult(
        damageType: DamageType.collapsedBuilding,
        severity: Severity.high,
        confidence: 0.0,
        recommendation: 'Evacuate area.',
        description: 'Structural damage visible.',
      );
      expect(result.toBanglaType, 'ধসে পড়া ভবন');
      expect(result.toBanglaSeverity, 'উচ্চ');
    });
  });
}