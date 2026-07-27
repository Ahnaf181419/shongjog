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

  /// Writes the legacy single-key field.
  Future<void> setRemoteKey(Object? value) => fs
      .collection(RemoteKeyService.collection)
      .doc(RemoteKeyService.document)
      .set({RemoteKeyService.field: ?value});

  /// Writes the key ring.
  Future<void> setRemoteKeys(Object? value) => fs
      .collection(RemoteKeyService.collection)
      .doc(RemoteKeyService.document)
      .set({RemoteKeyService.listField: ?value});

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

  group('RemoteKeyService key ring', () {
    test('caches all four keys in order — the ring rotates through them when '
        'one exhausts its daily free-tier quota', () async {
      await setRemoteKeys(['k1', 'k2', 'k3', 'k4']);

      expect(await svc.syncKey(), isTrue);
      expect(await keyStore.getKeys(), ['k1', 'k2', 'k3', 'k4']);
    });

    test('the array field wins over the legacy single-key field', () async {
      await fs
          .collection(RemoteKeyService.collection)
          .doc(RemoteKeyService.document)
          .set({
        RemoteKeyService.field: 'old-single',
        RemoteKeyService.listField: ['k1', 'k2'],
      });

      await svc.syncKey();
      expect(await keyStore.getKeys(), ['k1', 'k2']);
    });

    test('a doc still using the single-key layout keeps working', () async {
      await setRemoteKey('only-one');

      await svc.syncKey();
      expect(await keyStore.getKeys(), ['only-one']);
    });

    test('skips blank rows and duplicates — a duplicate would make the ring '
        '"rotate" onto the same exhausted key', () async {
      await setRemoteKeys(['k1', '', '  ', 'k2', 'k1']);

      await svc.syncKey();
      expect(await keyStore.getKeys(), ['k1', 'k2']);
    });

    test('skips a non-string row rather than failing the whole parse — the '
        'doc is hand-edited and one bad cell must not kill cloud AI',
        () async {
      await setRemoteKeys(['k1', 42, 'k2']);

      await svc.syncKey();
      expect(await keyStore.getKeys(), ['k1', 'k2']);
    });

    test('reordering the keys in the console is picked up', () async {
      await setRemoteKeys(['k1', 'k2']);
      await svc.syncKey();
      await setRemoteKeys(['k2', 'k1']);

      expect(await svc.syncKey(), isTrue);
      expect(await keyStore.getKeys(), ['k2', 'k1']);
    });

    test('an unchanged ring skips the write', () async {
      await setRemoteKeys(['k1', 'k2']);
      expect(await svc.syncKey(), isTrue);
      expect(await svc.syncKey(), isFalse);
    });

    test('emptying the array revokes every key on device', () async {
      await keyStore.saveKeys(['k1', 'k2']);
      await setRemoteKeys(<String>[]);

      await svc.syncOrRevoke();

      expect(await keyStore.getKeys(), isEmpty);
    });
  });

  group('ApiKeyStore active index', () {
    test('remembers the working key so the next launch does not re-burn a '
        'round trip on one already spent today', () async {
      await keyStore.saveActiveIndex(2);
      expect(await keyStore.getActiveIndex(), 2);
    });

    test('defaults to the first key when nothing is stored', () async {
      expect(await keyStore.getActiveIndex(), 0);
    });

    test('resets to the first key on a new day — Gemini free-tier quota '
        'resets daily, so yesterday\'s dead key is alive again', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gemini_api_key_index': '3',
        'gemini_api_key_rotation_day': '2020-1-1',
      });
      expect(await ApiKeyStore().getActiveIndex(), 0);
    });

    test('saving keys clears nothing but keeps the single-key slot in sync '
        'for the damage scanner and manual-entry readers', () async {
      await keyStore.saveKeys(['k1', 'k2']);
      expect(await keyStore.getKey(), 'k1');
    });

    test('deleteKeys clears the ring, the index and the single-key slot',
        () async {
      await keyStore.saveKeys(['k1', 'k2']);
      await keyStore.saveActiveIndex(1);

      await keyStore.deleteKeys();

      expect(await keyStore.getKeys(), isEmpty);
      expect(await keyStore.getKey(), isNull);
      expect(await keyStore.getActiveIndex(), 0);
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
