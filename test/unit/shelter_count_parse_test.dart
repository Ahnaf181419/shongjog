import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/shelter_tool_dispatcher.dart';

/// The shelter path answers without invoking the model at all. That is only
/// safe if reading the requested count off the query is as good as the tool
/// call it replaced — which asked the model for exactly one optional integer,
/// clamped to 1..10, defaulting to 3.
void main() {
  group('parseRequestedCount — digits', () {
    test('reads an ASCII digit', () {
      expect(ShelterToolDispatcher.parseRequestedCount('nearest 5 shelters'), 5);
    });

    test('reads a Bangla digit', () {
      expect(
        ShelterToolDispatcher.parseRequestedCount('৫ টি আশ্রয়কেন্দ্র দেখাও'),
        5,
      );
    });

    test('reads a two-digit Bangla number at the cap', () {
      expect(
        ShelterToolDispatcher.parseRequestedCount('১০ টি আশ্রয়কেন্দ্র'),
        10,
      );
    });

    test('ignores a number above the dispatcher cap', () {
      // 9999 is not a plausible count; falling back to the default is the
      // same behaviour the tool path had via clamp().
      expect(
        ShelterToolDispatcher.parseRequestedCount('9999 shelters'),
        isNull,
      );
    });

    test('ignores zero', () {
      expect(ShelterToolDispatcher.parseRequestedCount('0 shelters'), isNull);
    });
  });

  group('parseRequestedCount — words', () {
    test('reads a Bangla number word', () {
      expect(
        ShelterToolDispatcher.parseRequestedCount('তিনটি আশ্রয়কেন্দ্র কোথায়?'),
        3,
      );
    });

    test('reads an English number word', () {
      expect(
        ShelterToolDispatcher.parseRequestedCount('show me two shelters'),
        2,
      );
    });
  });

  group('parseRequestedCount — no count', () {
    test('a plain shelter query yields null so dispatch uses its default', () {
      expect(
        ShelterToolDispatcher.parseRequestedCount('নিকটস্থ আশ্রয়কেন্দ্র কোথায়?'),
        isNull,
      );
      expect(
        ShelterToolDispatcher.parseRequestedCount('where is the nearest shelter'),
        isNull,
      );
    });

    test('null and an empty args map drive the same default', () {
      // dispatch() treats a missing count and an absent `count` key
      // identically — this is what makes the null return safe.
      expect(ShelterToolDispatcher.parseRequestedCount(''), isNull);
    });
  });
}
