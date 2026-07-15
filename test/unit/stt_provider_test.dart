import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/voice/stt_provider.dart';
import 'package:shongjog/features/voice/vosk_stt_provider.dart';

void main() {
  group('SttProvider interface', () {
    test('VoskSttProvider is offline', () {
      final vosk = VoskSttProvider();
      expect(vosk.isOffline, isTrue);
      expect(vosk.name, contains('Vosk'));
    });

    test('VoskSttProvider isModelBundled returns false (plugin not active)', () async {
      final bundled = await VoskSttProvider.isModelBundled();
      expect(bundled, isFalse);
    });

    test('VoskSttProvider init returns false (plugin not active)', () async {
      final vosk = VoskSttProvider();
      final result = await vosk.init();
      expect(result, isFalse);
      expect(vosk.isInitialized, isFalse);
    });
  });

  group('SttProvider contract', () {
    test('all providers implement required interface', () {
      final vosk = VoskSttProvider();
      expect(vosk, isA<SttProvider>());
      expect(vosk.name, isA<String>());
      expect(vosk.isOffline, isA<bool>());
    });
  });
}
