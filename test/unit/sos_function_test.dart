import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/sos_function_schema.dart';

void main() {
  group('sosReportTool', () {
    test('has the correct name', () {
      expect(sosReportTool.name, 'submit_sos_report');
    });

    test('has a non-empty description', () {
      expect(sosReportTool.description, isNotEmpty);
    });

    test('has all required parameter properties', () {
      final props = sosReportTool.parameters['properties'] as Map<String, dynamic>;
      expect(props.containsKey('location'), isTrue);
      expect(props.containsKey('hazard_type'), isTrue);
      expect(props.containsKey('casualty_count'), isTrue);
      expect(props.containsKey('injuries'), isTrue);
      expect(props.containsKey('immediate_needs'), isTrue);
      expect(props.containsKey('access_notes'), isTrue);
    });
  });

  group('buildSosSmsBody', () {
    test('includes all fields when provided', () {
      final body = buildSosSmsBody({
        'location': 'ঢাকা, মিরপুর',
        'hazard_type': 'অগ্নিকাণ্ড',
        'casualty_count': 3,
        'injuries': 'পোড়া',
        'immediate_needs': ['অ্যাম্বুলেন্স', 'উদ্ধার'],
        'access_notes': 'মূল সড়ক বন্ধ',
      });
      expect(body, contains('ঢাকা, মিরপুর'));
      expect(body, contains('অগ্নিকাণ্ড'));
      expect(body, contains('3 জন')); // Latin digits — acceptable for SMS
      expect(body, contains('পোড়া'));
      expect(body, contains('অ্যাম্বুলেন্স'));
      expect(body, contains('মূল সড়ক বন্ধ'));
    });

    test('omits null fields', () {
      final body = buildSosSmsBody({
        'location': 'চট্টগ্রাম',
        'hazard_type': null,
      });
      expect(body, contains('চট্টগ্রাম'));
      expect(body, isNot(contains('ধরন:')));
    });

    test('handles empty map', () {
      final body = buildSosSmsBody({});
      expect(body, contains('শঙ্গজগ'));
    });

    test('handles empty immediate_needs array', () {
      final body = buildSosSmsBody({
        'immediate_needs': <String>[],
      });
      expect(body, isNot(contains('প্রয়োজন:')));
    });
  });
}
