import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/triage/triage_tts.dart';

import '../widget/fake_triage_tts.dart';

void main() {
  group('TriageTts', () {
    test('SilentTriageTts.speak is a no-op', () async {
      const tts = SilentTriageTts();
      await tts.speak('hello');
      // No assertion needed — the absence of a thrown exception is
      // the contract.
    });

    test('FakeTriageTts records speak calls', () async {
      final tts = FakeTriageTts();
      await tts.speak('ব্যক্তি কি সচেতন?');
      await tts.speak('শ্বাস নিচ্ছে?');
      expect(tts.spoken, ['ব্যক্তি কি সচেতন?', 'শ্বাস নিচ্ছে?']);
    });

    test('FakeTriageTts.stop sets the stopped flag', () async {
      final tts = FakeTriageTts();
      await tts.stop();
      expect(tts.stopped, isTrue);
    });
  });
}
