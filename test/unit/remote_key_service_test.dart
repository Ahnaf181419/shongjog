import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/api_key_store.dart';
import 'package:shongjog/core/remote_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fs;
  late ApiKeyStore keyStore;
  late RemoteKeyService svc;

  setUp(() {
    fs = FakeFirebaseFirestore();
    // Swaps the Android Keystore platform channel — absent under
    // `flutter test` — for an in-memory map.
    FlutterSecureStorage.setMockInitialValues({});
    keyStore = ApiKeyStore();
    svc = RemoteKeyService(firestore: fs, keyStore: keyStore);
  });

  Future<void> setRemoteKey(Object? value) => fs
      .collection(RemoteKeyService.collection)
      .doc(RemoteKeyService.document)
      .set({RemoteKeyService.field: ?value});

  group('RemoteKeyService.syncKey', () {
    test('caches the remote key on device, so the APK needs no compiled-in '
        'key at all', () async {
      await setRemoteKey('AIzaSyFAKEKEYFORTESTINGONLY0000000000000');

      expect(await svc.syncKey(), isTrue);
      expect(await keyStore.getKey(), 'AIzaSyFAKEKEYFORTESTINGONLY0000000000000');
    });

    test('trims surrounding whitespace — the doc is hand-edited in the '
        'Firebase console and a stray newline would 401 every request',
        () async {
      await setRemoteKey('  AIzaSyFAKE  \n');

      await svc.syncKey();
      expect(await keyStore.getKey(), 'AIzaSyFAKE');
    });

    test('skips the write when the key is unchanged', () async {
      await setRemoteKey('AIzaSyFAKE');
      expect(await svc.syncKey(), isTrue);
      expect(await svc.syncKey(), isFalse);
    });

    test('leaves an existing key alone when the config doc is missing — a '
        'phone that already works must not be broken by a lookup failure',
        () async {
      await keyStore.saveKey('AIzaSyEXISTING');

      expect(await svc.syncKey(), isFalse);
      expect(await keyStore.getKey(), 'AIzaSyEXISTING');
    });

    test('ignores a blank remote value rather than caching an empty key',
        () async {
      await setRemoteKey('   ');
      expect(await svc.syncKey(), isFalse);
      expect(await keyStore.getKey(), isNull);
    });

    test('ignores a non-string value instead of crashing on a bad edit',
        () async {
      await setRemoteKey(12345);
      expect(await svc.syncKey(), isFalse);
      expect(await keyStore.getKey(), isNull);
    });
  });

  group('RemoteKeyService.syncOrRevoke', () {
    test('blanking the field in the console revokes the key on device at the '
        'next launch, with no new release', () async {
      await keyStore.saveKey('AIzaSyLEAKED');
      await setRemoteKey('');

      await svc.syncOrRevoke();

      expect(await keyStore.getKey(), isNull);
    });

    test('removing the field entirely also revokes', () async {
      await keyStore.saveKey('AIzaSyLEAKED');
      await setRemoteKey(null); // doc exists, field absent

      await svc.syncOrRevoke();

      expect(await keyStore.getKey(), isNull);
    });

    test('a missing config doc does NOT revoke — that is a lookup failure, '
        'not a decision to turn cloud AI off', () async {
      await keyStore.saveKey('AIzaSyEXISTING');

      await svc.syncOrRevoke();

      expect(await keyStore.getKey(), 'AIzaSyEXISTING');
    });

    test('rotating the key in the console replaces the cached one', () async {
      await keyStore.saveKey('AIzaSyOLD');
      await setRemoteKey('AIzaSyNEW');

      await svc.syncOrRevoke();

      expect(await keyStore.getKey(), 'AIzaSyNEW');
    });

    test('never throws when Firestore is unreachable — app boot must survive '
        'a dead backend', () async {
      final broken = RemoteKeyService(keyStore: keyStore); // no Firebase app
      await expectLater(broken.syncOrRevoke(), completes);
      await expectLater(broken.syncKey(), completion(isFalse));
    });
  });
}
