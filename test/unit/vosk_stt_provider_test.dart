import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/voice/vosk_stt_provider.dart';

/// Tests for the blocked Vosk provider. These exist to lock in the
/// "always returns false / not initialized" contract so the fallback
/// path in SttService._ensureProvider() keeps working without
/// accidentally throwing or appearing to work.
///
/// When the upstream `vosk_flutter` plugin compileSdk issue is fixed,
/// these tests will need to be updated to reflect the working state.
void main() {
  group('VoskSttProvider (blocked — fallback path)', () {
    final provider = VoskSttProvider();

    test('name is offline Bangla', () {
      expect(provider.name, 'Vosk (offline)');
    });

    test('isOffline is true', () {
      expect(provider.isOffline, isTrue);
    });

    test('isInitialized is false before init', () {
      expect(provider.isInitialized, isFalse);
    });

    test('init() returns false (plugin blocked)', () async {
      final ok = await provider.init();
      expect(ok, isFalse);
      expect(provider.isInitialized, isFalse);
    });

    test('listen() throws UnimplementedError (plugin blocked)', () async {
      expect(
        () => provider.listen(),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('stop() is a no-op (no crash)', () async {
      await provider.stop();
    });
  });
}