import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/rag/urgency_classifier.dart';

void main() {
  group('UrgencyClassifier', () {
    group('critical (thinking OFF)', () {
      test('শ্বাসকষ্ট → critical', () {
        final r = UrgencyClassifier.classify('শিশু শ্বাসকষ্টে ভুগছে');
        expect(r.level, UrgencyLevel.critical);
        expect(r.enableThinking, isFalse);
      });

      test('ডুবে গেছে → critical', () {
        final r = UrgencyClassifier.classify('বাচ্চা পুকুরে ডুবে গেছে');
        expect(r.level, UrgencyLevel.critical);
        expect(r.enableThinking, isFalse);
      });

      test('অজ্ঞান → critical', () {
        final r = UrgencyClassifier.classify('রোগী অজ্ঞান, নড়ছে না');
        expect(r.level, UrgencyLevel.critical);
        expect(r.enableThinking, isFalse);
      });

      test('প্রচুর রক্ত → critical', () {
        final r = UrgencyClassifier.classify('হাত কেটে প্রচুর রক্ত পড়ছে');
        expect(r.level, UrgencyLevel.critical);
        expect(r.enableThinking, isFalse);
      });
    });

    group('urgent (thinking ON)', () {
      test('সাপে কামড় → urgent', () {
        final r = UrgencyClassifier.classify('সাপে কামড়েছে, কি করবো?');
        expect(r.level, UrgencyLevel.urgent);
        expect(r.enableThinking, isTrue);
      });

      test('জ্বর → urgent', () {
        final r = UrgencyClassifier.classify('বাচ্চার অনেক জ্বর');
        expect(r.level, UrgencyLevel.urgent);
        expect(r.enableThinking, isTrue);
      });

      test('ডায়রিয়া → urgent', () {
        final r = UrgencyClassifier.classify('আমার বাচ্চার ডায়রিয়া হয়েছে');
        expect(r.level, UrgencyLevel.urgent);
        expect(r.enableThinking, isTrue);
      });
    });

    group('routine (thinking ON)', () {
      test('প্রস্তুতি → routine', () {
        final r = UrgencyClassifier.classify('প্রস্তুতি কীভাবে নিতে হবে?');
        expect(r.level, UrgencyLevel.routine);
        expect(r.enableThinking, isTrue);
      });

      test('নামের অর্থ → routine', () {
        final r = UrgencyClassifier.classify('আমার নামের অর্থ কী?');
        expect(r.level, UrgencyLevel.routine);
        expect(r.enableThinking, isTrue);
      });

      test('অফলাইন ডিরেক্টরি → routine', () {
        final r = UrgencyClassifier.classify('জরুরি নম্বর কোথায় পাবো?');
        expect(r.level, UrgencyLevel.routine);
        expect(r.enableThinking, isTrue);
      });
    });

    group('labels', () {
      test('critical label is জরুরি', () {
        expect(UrgencyResult.critical.labelBn, 'জরুরি');
      });

      test('urgent label is তাগিদপূর্ণ', () {
        expect(UrgencyResult.urgent.labelBn, 'তাগিদপূর্ণ');
      });

      test('routine label is সাধারণ', () {
        expect(UrgencyResult.routine.labelBn, 'সাধারণ');
      });
    });
  });
}
