import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/hazards/usgs_earthquake_service.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {

  group('UsgsEarthquakeService', () {
    test('returns null when offline', () async {
      final result = await UsgsEarthquakeService.fetchRecent(isOnline: false);
      expect(result, isNull,
          reason: 'Offline requests must short-circuit to null.');
    });
  });

  group('EarthquakeEvent.tryParse', () {
    /// Realistic USGS GeoJSON Feature shape.
    const quakePayload = {
      'type': 'Feature',
      'properties': {
        'mag': 5.4,
        'place': '32 km E of Sylhet, Bangladesh',
        'time': 1784900000000, // ms since epoch
        'updated': 1784900100000,
        'tz': null,
        'url': 'https://earthquake.usgs.gov/...',
        'detail': 'https://...',
        'felt': 12,
        'cdi': 4.2,
        'mmi': 4.5,
        'alert': null,
        'status': 'reviewed',
        'tsunami': 0,
        'sig': 442,
        'net': 'us',
        'code': '7000abcd',
        'ids': ',us7000abcd,',
        'sources': ',us,',
        'types': ',origin,phase-data,',
        'nst': null,
        'dmin': 0.5,
        'rms': 0.6,
        'gap': 88,
        'magType': 'mww',
        'type': 'earthquake',
        'title': 'M 5.4 - 32 km E of Sylhet, Bangladesh',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [92.02, 24.89, 35.0],
      },
      'id': 'us7000abcd',
    };

    test('parses a well-formed earthquake Feature', () {
      final ev = EarthquakeEvent.tryParse(quakePayload);
      expect(ev, isNotNull);
      expect(ev!.id, 'us7000abcd');
      expect(ev.magnitude, 5.4);
      expect(ev.place, '32 km E of Sylhet, Bangladesh');
      expect(ev.latitude, closeTo(24.89, 0.001));
      expect(ev.longitude, closeTo(92.02, 0.001));
      expect(ev.depthKm, 35.0);
      expect(ev.time.toUtc().toIso8601String(),
          DateTime.fromMillisecondsSinceEpoch(1784900000000, isUtc: true)
              .toIso8601String());
      expect(ev.severity, EarthquakeSeverity.moderate);
    });

    test('returns null when geometry is missing', () {
      final ev = EarthquakeEvent.tryParse({
        'id': 'x',
        'properties': {'mag': 4.0, 'place': 'somewhere', 'time': 0},
        'geometry': null,
      });
      expect(ev, isNull);
    });

    test('returns null when magnitude is missing', () {
      final ev = EarthquakeEvent.tryParse({
        'id': 'x',
        'properties': {'place': 'somewhere', 'time': 0},
        'geometry': {
          'type': 'Point',
          'coordinates': [90.0, 24.0, 10.0],
        },
      });
      expect(ev, isNull,
          reason: 'A quake without magnitude is not useful to surface.');
    });

    test('returns null when time is missing', () {
      final ev = EarthquakeEvent.tryParse({
        'id': 'x',
        'properties': {'mag': 4.5, 'place': 'somewhere'},
        'geometry': {
          'type': 'Point',
          'coordinates': [90.0, 24.0, 10.0],
        },
      });
      expect(ev, isNull);
    });

    test('handles features with 2-coordinate geometry (no depth)', () {
      final ev = EarthquakeEvent.tryParse({
        'id': 'x',
        'properties': {'mag': 4.1, 'place': 'test', 'time': 1000},
        'geometry': {
          'type': 'Point',
          'coordinates': [89.0, 22.0],
        },
      });
      expect(ev, isNotNull);
      expect(ev!.depthKm, 0.0,
          reason: 'Missing depth should default to 0, not fail.');
    });
  });

  group('UsgsEarthquakeService.isBangladeshPlace', () {
    test('matches a place string naming Bangladesh', () {
      expect(
          UsgsEarthquakeService.isBangladeshPlace('32 km E of Sylhet, Bangladesh'),
          isTrue);
    });

    test(
        'rejects a place string naming a neighboring country — this is the '
        'reported bug: the lat/lon bounding box alone cannot distinguish '
        'e.g. Imphal, India from a genuine Bangladesh location, since '
        'Bangladesh is surrounded on three sides by India', () {
      expect(
          UsgsEarthquakeService.isBangladeshPlace('45 km NW of Imphal, India'),
          isFalse);
      expect(
          UsgsEarthquakeService.isBangladeshPlace('12 km SE of Sittwe, Myanmar'),
          isFalse);
    });

    test('is case-insensitive', () {
      expect(UsgsEarthquakeService.isBangladeshPlace('Dhaka, BANGLADESH'),
          isTrue);
    });

    test('rejects an empty place string', () {
      expect(UsgsEarthquakeService.isBangladeshPlace(''), isFalse);
    });
  });

  group('EarthquakeEvent.isBangladesh', () {
    EarthquakeEvent build(String place) => EarthquakeEvent.tryParse({
          'id': 'q',
          'properties': {
            'mag': 4.3,
            'place': place,
            'time': 1784900000000,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [90.68, 25.52, 10.0],
          },
        })!;

    test('marks a quake USGS places inside Bangladesh as domestic', () {
      expect(build('32 km E of Sylhet, Bangladesh').isBangladesh, isTrue);
    });

    test('marks a cross-border quake as foreign so the UI can badge it — '
        'these are kept, not dropped, because shaking on the Dauki fault '
        'is felt in Sylhet regardless of which side it is recorded on', () {
      expect(build('45 km E of Tura, India').isBangladesh, isFalse);
      expect(build('12 km SE of Sittwe, Myanmar').isBangladesh, isFalse);
    });
  });

  group('EarthquakeSeverity', () {
    test('magnitude < 5.0 is light', () {
      expect(
        EarthquakeEvent(
          id: 'x',
          magnitude: 4.5,
          place: 't',
          time: DateTime.utc(2026),
          latitude: 0,
          longitude: 0,
          depthKm: 0,
        ).severity,
        EarthquakeSeverity.light,
      );
    });

    test('magnitude 5.0–5.9 is moderate', () {
      expect(
        EarthquakeEvent(
          id: 'x',
          magnitude: 5.5,
          place: 't',
          time: DateTime.utc(2026),
          latitude: 0,
          longitude: 0,
          depthKm: 0,
        ).severity,
        EarthquakeSeverity.moderate,
      );
    });

    test('magnitude >= 6.0 is strong', () {
      expect(
        EarthquakeEvent(
          id: 'x',
          magnitude: 6.1,
          place: 't',
          time: DateTime.utc(2026),
          latitude: 0,
          longitude: 0,
          depthKm: 0,
        ).severity,
        EarthquakeSeverity.strong,
      );
    });

    testWidgets('severity labels are localized', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      for (final s in EarthquakeSeverity.values) {
        expect(s.label(ctx).isNotEmpty, isTrue, reason: '$s must have a label');
      }
    });
  });
}
