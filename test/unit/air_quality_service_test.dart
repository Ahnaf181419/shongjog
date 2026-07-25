import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/environment/air_quality_service.dart';

void main() {
  group('AirQualityService', () {
    test('returns null when offline', () async {
      final result =
          await AirQualityService.fetch(lat: 23.8, lon: 90.4, isOnline: false);
      expect(result, isNull,
          reason: 'Offline requests must short-circuit to null.');
    });
  });

  group('AirQualitySnapshot.fromOpenMeteo', () {
    test('parses a complete payload', () {
      const payload = {
        'pm2_5': 180.4,
        'pm10': 220.0,
        'carbon_monoxide': 550.0,
        'nitrogen_dioxide': 30.0,
        'sulphur_dioxide': 12.0,
        'ozone': 80.0,
        'european_aqi': 95,
      };
      final snap = AirQualitySnapshot.fromOpenMeteo(payload);
      expect(snap.pm25, 180.4);
      expect(snap.pm10, 220.0);
      expect(snap.carbonMonoxide, 550.0);
      expect(snap.europeanAqi, 95);
      expect(snap.severity, AirQualitySeverity.veryUnhealthy,
          reason: 'PM2.5 > 150 is very unhealthy per WHO thresholds.');
    });

    test('parses a minimal payload (pm fields only)', () {
      final snap = AirQualitySnapshot.fromOpenMeteo({
        'pm2_5': 10.0,
        'pm10': 20.0,
      });
      expect(snap.pm25, 10.0);
      expect(snap.pm10, 20.0);
      expect(snap.ozone, isNull);
      expect(snap.europeanAqi, isNull);
      expect(snap.severity, AirQualitySeverity.good);
    });

    test('coerces missing pm to 0 without throwing', () {
      final snap = AirQualitySnapshot.fromOpenMeteo({});
      expect(snap.pm25, 0);
      expect(snap.pm10, 0);
      expect(snap.severity, AirQualitySeverity.good,
          reason: '0 µg/m³ falls into the good bucket.');
    });
  });

  group('AirQualitySnapshot.severity (WHO 2021 thresholds)', () {
    AirQualitySnapshot snap(double pm25) =>
        AirQualitySnapshot(pm25: pm25, pm10: pm25);

    test('PM2.5 <= 15 is good', () {
      expect(snap(0).severity, AirQualitySeverity.good);
      expect(snap(15).severity, AirQualitySeverity.good);
    });

    test('PM2.5 16-40 is moderate', () {
      expect(snap(16).severity, AirQualitySeverity.moderate);
      expect(snap(40).severity, AirQualitySeverity.moderate);
    });

    test('PM2.5 41-65 is unhealthy for sensitive groups', () {
      expect(snap(41).severity, AirQualitySeverity.unhealthySensitive);
      expect(snap(65).severity, AirQualitySeverity.unhealthySensitive);
    });

    test('PM2.5 66-150 is unhealthy', () {
      expect(snap(66).severity, AirQualitySeverity.unhealthy);
      expect(snap(150).severity, AirQualitySeverity.unhealthy);
    });

    test('PM2.5 > 150 is very unhealthy', () {
      expect(snap(151).severity, AirQualitySeverity.veryUnhealthy);
      expect(snap(300).severity, AirQualitySeverity.veryUnhealthy);
    });
  });

}
