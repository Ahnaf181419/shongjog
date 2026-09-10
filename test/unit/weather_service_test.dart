import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/weather/weather_service.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations bnL10n;
  late AppLocalizations enL10n;

  setUpAll(() async {
    bnL10n = await AppLocalizations.delegate.load(const Locale('bn'));
    enL10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('WeatherSnapshot.conditionLabel', () {
    test('returns bn label for code 1-2 (partly cloudy)', () {
      final snap = WeatherSnapshot.fromOpenMeteo(_weather(code: 2));
      expect(snap.conditionLabel(bnL10n), 'হালকা মেঘলা');
    });

    test('returns bn label for code 0 (clear)', () {
      final snap = WeatherSnapshot.fromOpenMeteo(_weather(code: 0));
      expect(snap.conditionLabel(bnL10n), 'পরিষ্কার');
    });

    test('returns en label for code 3 (cloudy)', () {
      final snap = WeatherSnapshot.fromOpenMeteo(_weather(code: 3));
      expect(snap.conditionLabel(enL10n), 'Cloudy');
    });
  });

  test('iconKey covers the full WMO code range', () {
    final codes = [0, 1, 2, 3, 45, 51, 61, 71, 80, 82, 95, 99, 200];
    for (final c in codes) {
      final snap = WeatherSnapshot.fromOpenMeteo(_weather(code: c));
      expect(snap.iconKey, isNotEmpty, reason: 'iconKey empty for code $c');
    }
  });
}

Map<String, dynamic> _weather({required int code}) => {
      'current': {
        'weather_code': code,
        'temperature_2m': 28.5,
        'wind_speed_10m': 5.0,
      },
    };
