import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/hazards/eonet_service.dart';

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
    test('labelBn returns Bangla for each category', () {
      for (final c in EonetCategory.values) {
        expect(c.labelBn.isNotEmpty, isTrue,
            reason: '$c must have a non-empty Bangla label');
        // Asserts at least one Bangla Unicode character is present.
        final hasBangla =
            c.labelBn.codeUnits.any((u) => u >= 0x0980 && u <= 0x09FF);
        expect(hasBangla, isTrue, reason: '$c.labelBn must contain Bangla');
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
