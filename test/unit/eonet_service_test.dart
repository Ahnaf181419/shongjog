import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/hazards/eonet_service.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {

  group('EonetService', () {
    test('returns null when offline', () async {
      final result = await EonetService.fetchOpenHazards(isOnline: false);
      expect(result, isNull,
          reason: 'Offline requests must short-circuit to null.');
    });

    test('Bangladesh bbox covers the expected region', () {
      final b = EonetService.bangladeshBbox;
      expect(b.length, 4);
      // west, north, east, south
      expect(b[0], lessThan(b[2])); // west < east
      expect(b[1], greaterThan(b[3])); // north > south
    });

    test('bbox is tightened to roughly Bangladesh\'s real extent, not the '
        'old looser box that swept in Meghalaya/Assam/Myanmar', () {
      final b = EonetService.bangladeshBbox;
      expect(b[1], lessThanOrEqualTo(27.0), // north
          reason: 'Bangladesh\'s northernmost point is ~26.65°N.');
      expect(b[2], lessThanOrEqualTo(93.0), // east
          reason: 'Bangladesh\'s easternmost point is ~92.7°E.');
    });
  });

  group('EonetService.namesOtherCountry', () {
    test('flags a title that names a neighboring country', () {
      expect(EonetService.namesOtherCountry('Flooding in Assam, India'),
          isTrue);
      expect(EonetService.namesOtherCountry('Wildfires - Rakhine, Myanmar'),
          isTrue);
    });

    test('does not flag a title that names Bangladesh, even alongside '
        'another country', () {
      expect(EonetService.namesOtherCountry('Flooding in Bangladesh'),
          isFalse);
      expect(
          EonetService.namesOtherCountry('Cyclone affecting Bangladesh and India'),
          isFalse);
    });

    test('does not flag a title with no country mentioned at all — this is '
        'the common case for storms, which EONET names after the storm '
        'only ("Tropical Cyclone Amphan")', () {
      expect(EonetService.namesOtherCountry('Tropical Cyclone Amphan'),
          isFalse);
    });
  });

  group('EonetService.crossBorderCategories', () {
    test('covers the hazard types that reach across a national border', () {
      expect(EonetService.crossBorderCategories,
          contains(EonetCategory.severeStorms));
      expect(
          EonetService.crossBorderCategories, contains(EonetCategory.floods));
      expect(EonetService.crossBorderCategories,
          contains(EonetCategory.earthquakes));
    });

    test('excludes wildfires — a fire in Meghalaya burns where it burns and '
        'is not a Bangladesh emergency, which is what kept the card from '
        'filling up with in-bbox Indian wildfires', () {
      expect(EonetService.crossBorderCategories,
          isNot(contains(EonetCategory.wildfires)));
      expect(EonetService.crossBorderCategories,
          isNot(contains(EonetCategory.drought)));
    });
  });

  group('EonetEvent cross-border marking', () {
    EonetEvent build(String title, String catId) => EonetEvent.tryParse({
          'id': 'X',
          'title': title,
          'categories': [
            {'id': catId, 'title': catId}
          ],
          'geometry': [
            {
              'date': '2026-07-25T00:00:00Z',
              'type': 'Point',
              'coordinates': [91.0, 24.0],
            }
          ],
        })!;

    test('flags an event filed under a neighbouring country', () {
      expect(build('Flooding in Assam, India', 'floods').isCrossBorder, isTrue);
    });

    test('does not flag a multi-country event that names Bangladesh — it '
        'genuinely affects the country, so it must not be badged as '
        'foreign', () {
      expect(
          build('Wildfire in India, Bangladesh', 'wildfires').isCrossBorder,
          isFalse);
    });

    test('displayTitle strips EONET\'s trailing numeric event id, which reads '
        'as a glitch to a user', () {
      expect(build('Wildfire in India, Bangladesh 1023636', 'wildfires')
          .displayTitle, 'Wildfire in India, Bangladesh');
    });

    test('displayTitle leaves a title without a trailing id untouched', () {
      expect(build('Tropical Cyclone Amphan', 'severeStorms').displayTitle,
          'Tropical Cyclone Amphan');
    });

    test('displayTitle does not eat a short trailing number that is part of '
        'the storm name', () {
      expect(build('Tropical Depression 04B', 'severeStorms').displayTitle,
          'Tropical Depression 04B');
    });
  });

  group('EonetEvent.tryParse', () {
    /// Realistic EONET v3 event shape: a cyclone with a point geometry.
    const cyclonePayload = {
      'id': 'EONET_99999',
      'title': 'Tropical Cyclone Demo',
      'description': null,
      'link': 'https://eonet.gsfc.nasa.gov/api/v3/events/EONET_99999',
      'closed': null,
      'categories': [
        {'id': 'severeStorms', 'title': 'Severe Storms', 'link': '...', 'description': '...'},
      ],
      'sources': [
        {'id': 'JTWC', 'url': '...'},
      ],
      'geometry': [
        {
          'date': '2026-07-24T00:00:00Z',
          'type': 'Point',
          'coordinates': [91.0, 21.5],
        },
      ],
    };

    test('parses a well-formed event with point geometry', () {
      final ev = EonetEvent.tryParse(cyclonePayload);
      expect(ev, isNotNull);
      expect(ev!.id, 'EONET_99999');
      expect(ev.title, 'Tropical Cyclone Demo');
      expect(ev.category, EonetCategory.severeStorms);
      expect(ev.latitude, closeTo(21.5, 0.001));
      expect(ev.longitude, closeTo(91.0, 0.001));
      expect(ev.isActive, isTrue,
          reason: 'closed == null means the event is still open.');
      expect(ev.opened, isNotNull);
    });

    test('returns null when geometry is missing', () {
      final ev = EonetEvent.tryParse({
        'id': 'x',
        'title': 'No geometry event',
        'categories': [],
        'geometry': [],
      });
      expect(ev, isNull,
          reason: 'Events with no usable geometry cannot be mapped.');
    });

    test('parses a closed (inactive) flood event', () {
      final ev = EonetEvent.tryParse({
        'id': 'EONET_1',
        'title': 'Flooding in Bangladesh',
        'closed': '2026-07-20T00:00:00Z',
        'categories': [
          {'id': 'flood', 'title': 'Flood'},
        ],
        'geometry': [
          {'date': '2026-07-15T00:00:00Z', 'type': 'Point', 'coordinates': [90.0, 24.0]},
        ],
      });
      expect(ev, isNotNull);
      expect(ev!.category, EonetCategory.floods);
      expect(ev.isActive, isFalse,
          reason: 'A non-null closed date means the event has ended.');
    });

    test('uses the LAST geometry point (most recent), not the first', () {
      // Regression: `latest ??= g` inside the parse loop only ever
      // assigned once, so a multi-day tracked event (e.g. a cyclone)
      // always kept its FIRST known position, not its most recent one —
      // contradicting the "take the most recent" doc comment and the
      // point-in-Bangladesh filtering that depends on it.
      final ev = EonetEvent.tryParse({
        'id': 'EONET_track',
        'title': 'Tropical Cyclone Tracked',
        'categories': [
          {'id': 'severeStorms', 'title': 'Severe Storms'},
        ],
        'geometry': [
          {'date': '2026-07-20T00:00:00Z', 'type': 'Point', 'coordinates': [91.0, 21.5]},
          {'date': '2026-07-21T00:00:00Z', 'type': 'Point', 'coordinates': [92.0, 22.0]},
          {'date': '2026-07-22T00:00:00Z', 'type': 'Point', 'coordinates': [95.0, 23.0]},
        ],
      });
      expect(ev, isNotNull);
      expect(ev!.longitude, closeTo(95.0, 0.001),
          reason: 'Should use the last (most recent) point, not the first.');
      expect(ev.latitude, closeTo(23.0, 0.001));
    });

    test('maps unknown category id to EonetCategory.other', () {
      final ev = EonetEvent.tryParse({
        'id': 'x',
        'title': 'Mystery event',
        'categories': [
          {'id': 'noSuchCategory', 'title': 'Something New'},
        ],
        'geometry': [
          {'type': 'Point', 'coordinates': [89.0, 22.0]},
        ],
      });
      expect(ev, isNotNull);
      expect(ev!.category, EonetCategory.other);
    });
  });

  group('EonetCategory', () {
    testWidgets('label returns localized string for each category', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      for (final c in EonetCategory.values) {
        expect(c.label(ctx).isNotEmpty, isTrue,
            reason: '$c must have a non-empty localized label');
      }
    });

    test('iconKey is a non-empty snake_case slug', () {
      for (final c in EonetCategory.values) {
        expect(c.iconKey.isNotEmpty, isTrue);
        expect(RegExp(r'^[a-z]+$').hasMatch(c.iconKey), isTrue,
            reason: 'iconKey should be a lowercase alpha slug');
      }
    });
  });
}
