import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_tool_result_formatter.dart';

void main() {
  group('ShelterToolResultFormatter.toBanglaMessage', () {
    test('empty list returns a helpful fallback', () {
      final msg = ShelterToolResultFormatter.toBanglaMessage(const []);
      expect(msg, contains('কোনো শেল্টার'));
      expect(msg, contains('৯৯৯'));
    });

    test('single shelter includes name + distance + capacity', () {
      final ranked = [
        RankedShelter(
          const Shelter(
            name: 'Test Shelter',
            nameBn: 'টেস্ট শেল্টার',
            lat: 0,
            lon: 0,
            capacity: 1200,
            source: 'test',
          ),
          3.4,
        ),
      ];
      final msg = ShelterToolResultFormatter.toBanglaMessage(ranked);
      // Bangla name present.
      expect(msg, contains('টেস্ট শেল্টার'));
      // Distance rounded to 1 decimal + Bengali km suffix.
      expect(msg, contains('৩.৪'));
      expect(msg, contains('কিমি'));
      // Capacity.
      expect(msg, contains('১২০০'));
    });

    test('multiple shelters are numbered with Bengali digits', () {
      final ranked = [
        RankedShelter(
          const Shelter(
              name: 'A', nameBn: 'এ', lat: 0, lon: 0, capacity: 100, source: 't'),
          1.0,
        ),
        RankedShelter(
          const Shelter(
              name: 'B', nameBn: 'বি', lat: 0, lon: 0, capacity: 200, source: 't'),
          2.5,
        ),
      ];
      final msg = ShelterToolResultFormatter.toBanglaMessage(ranked);
      // Bengali digits ১. and ২. as list markers.
      expect(msg, contains('১.'));
      expect(msg, contains('২.'));
      // Both names.
      expect(msg, contains('এ'));
      expect(msg, contains('বি'));
    });

    test('missing capacity is omitted (not shown as 0)', () {
      final ranked = [
        RankedShelter(
          const Shelter(
              name: 'X', nameBn: 'এক্স', lat: 0, lon: 0, capacity: null, source: 't'),
          5.0,
        ),
      ];
      final msg = ShelterToolResultFormatter.toBanglaMessage(ranked);
      expect(msg, contains('এক্স'));
      expect(msg, contains('৫.০'));
      // Should NOT contain the capacity line at all.
      expect(msg.contains('ধারণক্ষমতা'), isFalse);
    });

    test('includes a tap-to-view-map hint', () {
      final ranked = [
        RankedShelter(
          const Shelter(
              name: 'A', nameBn: 'এ', lat: 0, lon: 0, capacity: 1, source: 't'),
          1.0,
        ),
      ];
      final msg = ShelterToolResultFormatter.toBanglaMessage(ranked);
      expect(msg.toLowerCase(), contains('মানচিত্র'));
    });
  });

  group('ShelterToolResultFormatter.toBanglaDigits', () {
    test('converts ASCII digits to Bengali numerals', () {
      expect(ShelterToolResultFormatter.toBanglaDigits('3.4'), '৩.৪');
      expect(ShelterToolResultFormatter.toBanglaDigits('1200'), '১২০০');
      expect(ShelterToolResultFormatter.toBanglaDigits('0'), '০');
    });

    test('leaves non-digit characters untouched', () {
      expect(ShelterToolResultFormatter.toBanglaDigits('km 12.5'),
          'km ১২.৫');
    });
  });
}
