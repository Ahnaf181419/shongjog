import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/shelter_intent_detector.dart';

void main() {
  group('ShelterIntentDetector.isShelterQuery', () {
    test('true for a direct Bangla shelter request', () {
      expect(
        ShelterIntentDetector.isShelterQuery(
            'আমি পটুয়াখালীতে আছি, কোন শেল্টার সবচেয়ে কাছে?'),
        isTrue,
      );
    });

    test('true for "nearest shelter" in English', () {
      expect(
        ShelterIntentDetector.isShelterQuery('where is the nearest shelter?'),
        isTrue,
      );
    });

    test('true for cyclone + safe place', () {
      expect(
        ShelterIntentDetector.isShelterQuery(
            'ঘূর্ণিঝড় আসছে, কোথায় নিরাপদ জায়গা?'),
        isTrue,
      );
    });

    test('true for "আশ্রয়কেন্দ্র"', () {
      expect(
        ShelterIntentDetector.isShelterQuery('নিকটস্থ আশ্রয়কেন্দ্র কোনটি?'),
        isTrue,
      );
    });

    test('false for an unrelated health query', () {
      expect(
        ShelterIntentDetector.isShelterQuery('আমার পেট খারাপ, কী করব?'),
        isFalse,
      );
    });

    test('false for a general greeting', () {
      expect(
        ShelterIntentDetector.isShelterQuery('হ্যালো, কেমন আছো?'),
        isFalse,
      );
    });

    test('false for empty query', () {
      expect(ShelterIntentDetector.isShelterQuery(''), isFalse);
    });

    test('case-insensitive for English keywords', () {
      expect(
        ShelterIntentDetector.isShelterQuery('SHELTER near me'),
        isTrue,
      );
    });
  });
}
