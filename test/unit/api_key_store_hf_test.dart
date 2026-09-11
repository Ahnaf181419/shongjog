import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shongjog/core/api_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('ApiKeyStore HF token', () {
    test('hasHfToken is false before anything is saved', () async {
      final store = ApiKeyStore();
      expect(await store.hasHfToken(), isFalse);
      expect(await store.getHfToken(), isNull);
    });

    test('saveHfToken round-trips a token', () async {
      final store = ApiKeyStore();
      await store.saveHfToken('hf_abcdefghijklmnop');
      expect(await store.hasHfToken(), isTrue);
      expect(await store.getHfToken(), 'hf_abcdefghijklmnop');
    });

    test('saveHfToken trims surrounding whitespace', () async {
      final store = ApiKeyStore();
      await store.saveHfToken('  hf_xyz  ');
      expect(await store.getHfToken(), 'hf_xyz');
    });

    test('saveHfToken ignores blank input', () async {
      final store = ApiKeyStore();
      await store.saveHfToken('   ');
      expect(await store.hasHfToken(), isFalse);
      expect(await store.getHfToken(), isNull);
    });

    test('deleteHfToken clears the stored value', () async {
      final store = ApiKeyStore();
      await store.saveHfToken('hf_secret');
      await store.deleteHfToken();
      expect(await store.hasHfToken(), isFalse);
      expect(await store.getHfToken(), isNull);
    });

    test('saving a second token overwrites the first', () async {
      final store = ApiKeyStore();
      await store.saveHfToken('hf_first');
      await store.saveHfToken('hf_second');
      expect(await store.getHfToken(), 'hf_second');
    });
  });
}
