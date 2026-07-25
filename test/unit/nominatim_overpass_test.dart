import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/nominatim_service.dart';
import 'package:shongjog/features/shelter/overpass_service.dart';

void main() {
  group('NominatimService', () {
    test('returns null when offline', () async {
      final result = await NominatimService.search(
          query: 'Dhaka', isOnline: false);
      expect(result, isNull);
    });

    test('returns null for empty query', () async {
      final result = await NominatimService.search(
          query: '', isOnline: true);
      expect(result, isNull);
    });
  });

  group('NominatimResult.tryParse', () {
    test('parses a well-formed result', () {
      final r = NominatimResult.tryParse({
        'display_name': 'Dhaka Medical College, Dhaka, Bangladesh',
        'lat': '23.7261',
        'lon': '90.3976',
      });
      expect(r, isNotNull);
      expect(r!.displayName, contains('Dhaka Medical'));
      expect(r.lat, closeTo(23.7261, 0.001));
      expect(r.lon, closeTo(90.3976, 0.001));
    });

    test('returns null when lat/lon are missing', () {
      final r = NominatimResult.tryParse({
        'display_name': 'somewhere',
      });
      expect(r, isNull);
    });
  });

  group('OverpassService', () {
    test('returns null when offline', () async {
      final result = await OverpassService.searchPois(
        lat: 23.8,
        lon: 90.4,
        amenity: 'hospital',
        isOnline: false,
      );
      expect(result, isNull);
    });
  });

  group('OverpassPoi.tryParse', () {
    test('parses a well-formed element', () {
      final p = OverpassPoi.tryParse({
        'type': 'node',
        'id': 12345,
        'lat': 23.7333,
        'lon': 90.3981,
        'tags': {
          'amenity': 'hospital',
          'name': 'Dhaka Medical College Hospital',
          'name:bn': 'ঢাকা মেডিকেল কলেজ হাসপাতাল',
        },
      });
      expect(p, isNotNull);
      expect(p!.name, 'Dhaka Medical College Hospital');
      expect(p.nameBn, 'ঢাকা মেডিকেল কলেজ হাসপাতাল');
      expect(p.amenity, 'hospital');
      expect(p.lat, closeTo(23.7333, 0.001));
    });

    test('returns null when name is missing', () {
      final p = OverpassPoi.tryParse({
        'lat': 23.0,
        'lon': 90.0,
        'tags': {'amenity': 'hospital'},
      });
      expect(p, isNull);
    });

    test('returns null when tags are missing', () {
      final p = OverpassPoi.tryParse({
        'lat': 23.0,
        'lon': 90.0,
      });
      expect(p, isNull);
    });
  });
}
