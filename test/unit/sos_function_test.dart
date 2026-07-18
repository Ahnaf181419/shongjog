import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/sos_function_schema.dart';

void main() {
  group('sosReportTool Tool', () {
    test('name is submit_sos_report', () {
      expect(sosReportTool.name, 'submit_sos_report');
    });

    test('has all 6 parameter properties', () {
      final props = sosReportTool.parameters['properties'] as Map;
      expect(props.containsKey('location'), isTrue);
      expect(props.containsKey('hazard_type'), isTrue);
      expect(props.containsKey('casualty_count'), isTrue);
      expect(props.containsKey('injuries'), isTrue);
      expect(props.containsKey('immediate_needs'), isTrue);
      expect(props.containsKey('access_notes'), isTrue);
    });

    test('hazard_type property lists common Bangla emergencies', () {
      final props = sosReportTool.parameters['properties'] as Map;
      final hazard = props['hazard_type'] as Map;
      expect(hazard['description'], contains('বন্যা'));
    });

    test('immediate_needs is an array of strings', () {
      final props = sosReportTool.parameters['properties'] as Map;
      final needs = props['immediate_needs'] as Map;
      expect(needs['type'], 'array');
      expect((needs['items'] as Map)['type'], 'string');
    });
  });

  group('buildSosSmsBody', () {
    test('includes all filled fields with labels', () {
      final body = buildSosSmsBody({
        'location': 'ঢাকা',
        'hazard_type': 'বন্যা',
        'casualty_count': 3,
        'injuries': 'পোড়া',
        'immediate_needs': ['অ্যাম্বুলেন্স'],
        'access_notes': 'প্রধান সড়ক বন্ধ',
      });
      expect(body, contains('স্থান: ঢাকা'));
      expect(body, contains('ধরন: বন্যা'));
      expect(body.contains('৩ জন') || body.contains('3 জন'), isTrue);
      expect(body, contains('আঘাত: পোড়া'));
      expect(body, contains('প্রয়োজন: অ্যাম্বুলেন্স'));
      expect(body, contains('প্রবেশপথ: প্রধান সড়ক বন্ধ'));
      expect(body, contains('শঙ্গজগ'));
    });

    test('omits empty/null fields', () {
      final body = buildSosSmsBody({
        'location': 'কক্সবাজার',
      });
      expect(body, contains('কক্সবাজার'));
      expect(body, isNot(contains('ধরন:')));
      expect(body, isNot(contains('আঘাত:')));
    });

    test('handles empty immediate_needs array', () {
      final body = buildSosSmsBody({
        'immediate_needs': <String>[],
      });
      expect(body, isNot(contains('প্রয়োজন:')));
    });

    test('handles completely empty map', () {
      final body = buildSosSmsBody({});
      expect(body, contains('শঙ্গজগ SOS রিপোর্ট:'));
    });
  });
}