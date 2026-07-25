import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/semantic_search_service.dart';

void main() {
  group('SemanticSearchService.classify', () {
    test('shelter keywords → shelterFilter intent', () {
      expect(
        SemanticSearchService.classify('নিকটস্থ শেল্টার').intent,
        SearchIntent.shelterFilter,
      );
      expect(
        SemanticSearchService.classify('cyclone shelters near me').intent,
        SearchIntent.shelterFilter,
      );
    });

    test('hospital keyword → poiQuery with hospital tag', () {
      final r = SemanticSearchService.classify('নিকটস্থ হাসপাতাল');
      expect(r.intent, SearchIntent.poiQuery);
      expect(r.poiTag, 'hospital');
    });

    test('pharmacy keyword → poiQuery with pharmacy tag', () {
      final r = SemanticSearchService.classify('pharmacy near me');
      expect(r.intent, SearchIntent.poiQuery);
      expect(r.poiTag, 'pharmacy');
    });

    test('police/thana → poiQuery with police tag', () {
      final r = SemanticSearchService.classify('নিকটস্থ থানা');
      expect(r.intent, SearchIntent.poiQuery);
      expect(r.poiTag, 'police');
    });

    test('place name → geocode intent', () {
      final r = SemanticSearchService.classify('ঢাকা মেডিকেল কলেজ');
      expect(r.intent, SearchIntent.geocode);
      expect(r.poiTag, isNull);
    });

    test('empty query → shelterFilter (safe default)', () {
      final r = SemanticSearchService.classify('');
      expect(r.intent, SearchIntent.shelterFilter);
    });

    test('POI takes priority over shelter keywords', () {
      // "শেল্টারের কাছে হাসপাতাল" — mentions both shelter + hospital.
      // Should classify as POI since the user wants a hospital.
      final r = SemanticSearchService.classify('শেল্টারের কাছে হাসপাতাল');
      expect(r.intent, SearchIntent.poiQuery);
      expect(r.poiTag, 'hospital');
    });

    test('case-insensitive matching', () {
      expect(
        SemanticSearchService.classify('HOSPITAL').intent,
        SearchIntent.poiQuery,
      );
    });
  });
}
