import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/intelligence/situation_summary_service.dart';

void main() {
  final t = DateTime(2026, 7, 25);

  group('buildSituationPrompt', () {
    test('includes all provided reports', () {
      final prompt = buildSituationPrompt([
        SituationReport(
            query: 'নিকটস্থ হাসপাতাল', source: 'chat', when: t),
        SituationReport(query: 'বন্যা', source: 'chat', when: t),
        SituationReport(query: 'SOS: trapped', source: 'sos', when: t),
      ]);
      expect(prompt, contains('নিকটস্থ হাসপাতাল'));
      expect(prompt, contains('SOS'));
    });

    test('returns null for empty reports', () {
      expect(buildSituationPrompt(const []), isNull);
    });
  });

  group('fallbackSituationSummary', () {
    test('returns a useful summary for any reports list', () {
      final summary = fallbackSituationSummary([
        SituationReport(
            query: 'বন্যা সম্পর্কে জানতে চাই', source: 'chat', when: t),
      ]);
      expect(summary, isNotEmpty);
      expect(summary, contains('AI সহায়িকা'));
    });

    test('includes 999 guidance when SOS reports present', () {
      final summary = fallbackSituationSummary([
        SituationReport(query: 'SOS trapped', source: 'sos', when: t),
      ]);
      expect(summary, contains('৯৯৯'));
    });

    test('returns an empty-state summary for no reports', () {
      final summary = fallbackSituationSummary(const []);
      expect(summary, contains('পরিস্থিতি'));
    });

    test('counts incident types', () {
      final summary = fallbackSituationSummary([
        SituationReport(query: 'SOS trapped', source: 'sos', when: t),
        SituationReport(query: 'ভবন ধস', source: 'sos', when: t),
        SituationReport(query: 'হাসপাতাল', source: 'chat', when: t),
      ]);
      expect(summary, contains('৩'));
    });
  });
}