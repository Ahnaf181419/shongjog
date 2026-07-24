import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/environment/marine_service.dart';

void main() {
  group('MarineService', () {
    test('returns null when offline', () async {
      final result =
          await MarineService.fetch(lat: 21.4, lon: 92.0, isOnline: false);
      expect(result, isNull);
    });
  });

  group('MarineSnapshot.fromOpenMeteo', () {
    const payload = {
      'time': ['2026-07-24', '2026-07-25', '2026-07-26'],
      'wave_height_max': [1.5, 3.2, 5.0],
      'wave_direction_dominant': [180.0, 135.0, 90.0],
      'wind_wave_height_max': [1.0, 2.0, 4.0],
    };

    test('parses up to 3 days', () {
      final snap = MarineSnapshot.fromOpenMeteo(payload);
      expect(snap.days.length, 3);
    });

    test('truncates to 3 days if the API returns more', () {
      final snap = MarineSnapshot.fromOpenMeteo({
        ...payload,
        'time': ['2026-07-24', '2026-07-25', '2026-07-26', '2026-07-27'],
        'wave_height_max': [1.5, 3.2, 5.0, 6.0],
        'wave_direction_dominant': [180, 135, 90, 45],
        'wind_wave_height_max': [1, 2, 4, 5],
      });
      expect(snap.days.length, 3);
    });

    test('today() returns the first day', () {
      final snap = MarineSnapshot.fromOpenMeteo(payload);
      expect(snap.today, isNotNull);
      expect(snap.today!.waveHeightMaxM, 1.5);
    });

    test('missing fields default to 0 without throwing', () {
      final snap = MarineSnapshot.fromOpenMeteo({
        'time': ['2026-07-24'],
      });
      expect(snap.days.length, 1);
      expect(snap.days.first.waveHeightMaxM, 0);
      expect(snap.days.first.waveDirectionDeg, 0);
    });
  });

  group('MarineDay.severity (wave-height thresholds)', () {
    MarineDay day(double h) => MarineDay(
          date: DateTime(2026),
          waveHeightMaxM: h,
          waveDirectionDeg: 0,
          windWaveHeightMaxM: 0,
        );

    test('< 1.2 m is calm', () {
      expect(day(0).severity, WaveSeverity.calm);
      expect(day(1.1).severity, WaveSeverity.calm);
    });

    test('1.2–2.5 m is moderate', () {
      expect(day(1.2).severity, WaveSeverity.moderate);
      expect(day(2.5).severity, WaveSeverity.moderate);
    });

    test('2.6–4.0 m is rough', () {
      expect(day(2.6).severity, WaveSeverity.rough);
      expect(day(4.0).severity, WaveSeverity.rough);
    });

    test('> 4.0 m is very rough', () {
      expect(day(4.1).severity, WaveSeverity.veryRough);
      expect(day(10).severity, WaveSeverity.veryRough);
    });
  });

  group('WaveSeverity.labelBn', () {
    test('every severity has a non-empty Bangla label', () {
      for (final s in WaveSeverity.values) {
        expect(s.labelBn.isNotEmpty, isTrue);
        final hasBangla =
            s.labelBn.codeUnits.any((u) => u >= 0x0980 && u <= 0x09FF);
        expect(hasBangla, isTrue);
      }
    });
  });
}
