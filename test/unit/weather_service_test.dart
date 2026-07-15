import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/weather/weather_service.dart';

/// Pure-Dart test for the Open-Meteo JSON -> WeatherSnapshot parser.
///
/// The widget side (WeatherCard) renders weather from a snapshot; the
/// snapshot must round-trip the canned response correctly. These tests
/// feed a hand-crafted JSON that mirrors Open-Meteo's actual shape so
/// regressions in either URL contract or parser are caught here.
void main() {
  group('WeatherSnapshot.fromOpenMeteo', () {
    test('parses 4-day forecast into daily list', () {
      final json = <String, dynamic>{
        'current': {
          'temperature_2m': 31.2,
          'relative_humidity_2m': 64,
          'precipitation': 0.0,
          'weather_code': 2,
          'wind_speed_10m': 9.5,
        },
        'daily': {
          'time': ['2026-07-15', '2026-07-16', '2026-07-17', '2026-07-18'],
          'temperature_2m_max': [33.4, 32.1, 30.5, 31.2],
          'temperature_2m_min': [26.1, 25.4, 24.8, 25.5],
          'weather_code': [2, 61, 95, 3],
          'precipitation_probability_max': [40, 70, 90, 55],
        },
      };

      final snap = WeatherSnapshot.fromOpenMeteo(json);

      expect(snap.tempC, 31.2);
      expect(snap.humidityPct, 64);
      expect(snap.windKph, 9.5);
      expect(snap.weatherCode, 2);
      expect(snap.conditionBn, 'হালকা মেঘলা');
      expect(snap.iconKey, 'partly_cloudy');

      // Today's mirrors of the first daily entry.
      expect(snap.tempMaxC, 33.4);
      expect(snap.tempMinC, 26.1);
      expect(snap.precipProbabilityPct, 40);

      // Full daily list.
      expect(snap.daily.length, 4);
      expect(snap.daily[0].maxC, 33.4);
      expect(snap.daily[1].weatherCode, 61);
      expect(snap.daily[2].maxC, 30.5);
      expect(snap.daily[3].minC, 25.5);

      // Date parses from the YYYY-MM-DD string.
      expect(snap.daily[0].date.year, 2026);
      expect(snap.daily[0].date.month, 7);
      expect(snap.daily[0].date.day, 15);
    });

    test('falls back to zeros when current block is missing', () {
      final json = <String, dynamic>{
        'daily': {
          'time': ['2026-07-15'],
          'temperature_2m_max': [33.0],
          'temperature_2m_min': [26.0],
          'weather_code': [0],
          'precipitation_probability_max': [10],
        },
      };
      final snap = WeatherSnapshot.fromOpenMeteo(json);
      expect(snap.tempC, 0);
      expect(snap.humidityPct, 0);
      expect(snap.conditionBn, 'পরিষ্কার');
      expect(snap.tempMaxC, 33.0);
      expect(snap.daily.length, 1);
    });

    test('returns empty daily list when daily block is missing', () {
      final json = <String, dynamic>{
        'current': {
          'temperature_2m': 20.0,
          'weather_code': 3,
        },
      };
      final snap = WeatherSnapshot.fromOpenMeteo(json);
      expect(snap.daily, isEmpty);
      expect(snap.tempC, 20.0);
      expect(snap.tempMaxC, 0);
      expect(snap.tempMinC, 0);
    });

    test('WMO codes map to correct Bangla conditions', () {
      for (final entry in const [
        (0, 'পরিষ্কার'),
        (1, 'হালকা মেঘলা'),
        (3, 'মেঘাচ্ছন্ন'),
        (45, 'কুয়াশা'),
        (61, 'বৃষ্টি'),
        (65, 'ভারী বৃষ্টি'),
        (71, 'তুষারপাত'),
        (95, 'ঝড়ো হাওয়া'),
        (96, 'বজ্রসহ ঝড়'),
      ]) {
        final json = <String, dynamic>{
          'current': {'temperature_2m': 0, 'weather_code': entry.$1},
        };
        expect(WeatherSnapshot.fromOpenMeteo(json).conditionBn, entry.$2,
            reason: 'WMO code ${entry.$1} should map to ${entry.$2}');
      }
    });
  });
}
