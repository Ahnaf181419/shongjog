import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/device_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RegisteredDevice', () {
    test('is online while its heartbeat is inside the online window', () {
      final d = RegisteredDevice(
        uid: 'u1',
        name: 'রহিম',
        lastSeen: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      expect(d.isOnline, isTrue);
    });

    test('ages out to offline once the heartbeat goes stale — a backgrounded '
        'phone stops heartbeating, so this needs no explicit sign-out', () {
      final d = RegisteredDevice(
        uid: 'u1',
        name: 'রহিম',
        lastSeen: DateTime.now()
            .toUtc()
            .subtract(DeviceRegistryService.onlineWindow +
                const Duration(minutes: 1)),
      );
      expect(d.isOnline, isFalse);
    });

    test('the online window is longer than the heartbeat interval, so one '
        'dropped write does not flip a live device to offline', () {
      expect(DeviceRegistryService.onlineWindow,
          greaterThan(DeviceRegistryService.heartbeatInterval * 2));
    });

    test('a device that never checked in is offline, not online-by-default',
        () {
      const d = RegisteredDevice(uid: 'u1', name: '');
      expect(d.isOnline, isFalse);
    });

    test('fromJson falls back to the doc id when the uid field is absent', () {
      final d = RegisteredDevice.fromJson('doc-abc', const {});
      expect(d.uid, 'doc-abc');
      expect(d.name, '');
      expect(d.isAdmin, isFalse);
      expect(d.lastSeen, isNull);
    });

    test('reads the admin role written by claimAdminRole on the same doc', () {
      final d = RegisteredDevice.fromJson('u1', const {'role': 'admin'});
      expect(d.isAdmin, isTrue);
    });
  });

  group('DeviceRegistryService', () {
    test('registerSelf writes this device into the users collection',
        () async {
      SharedPreferences.setMockInitialValues({'user_name': 'করিম'});
      final fs = FakeFirebaseFirestore();
      final svc = DeviceRegistryService(firestore: fs, uidProvider: () => 'u1');

      await svc.registerSelf();

      final doc = await fs.collection('users').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'করিম');
      expect(doc.data()!['lastSeen'], isA<String>());
    });

    test('registerSelf merges, so a heartbeat never wipes the admin role '
        'claimed on the same doc', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('users').doc('u1').set({'role': 'admin'});
      final svc = DeviceRegistryService(firestore: fs, uidProvider: () => 'u1');

      await svc.registerSelf();

      final doc = await fs.collection('users').doc('u1').get();
      expect(doc.data()!['role'], 'admin');
      expect(doc.data()!['lastSeen'], isNotNull);
    });

    test('registerSelf is a no-op before anonymous sign-in lands', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DeviceRegistryService(firestore: fs, uidProvider: () => null);

      await svc.registerSelf();

      final snap = await fs.collection('users').get();
      expect(snap.docs, isEmpty);
    });

    test('registerSelf swallows a throwing uid lookup — FirebaseAuth.instance '
        'throws synchronously when no Firebase app exists, and that must not '
        'take down app boot', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DeviceRegistryService(
        firestore: fs,
        uidProvider: () => throw StateError('[core/no-app]'),
      );

      await expectLater(svc.registerSelf(), completes);
    });

    test('devices registered by other phones appear in the roster', () async {
      final fs = FakeFirebaseFirestore();
      final now = DateTime.now().toUtc();
      await fs.collection('users').doc('other-1').set({
        'uid': 'other-1',
        'name': 'ফাতেমা',
        'lastSeen': now.toIso8601String(),
      });
      await fs.collection('users').doc('other-2').set({
        'uid': 'other-2',
        'name': 'সাকিব',
        'lastSeen': now.subtract(const Duration(hours: 3)).toIso8601String(),
      });

      final svc = DeviceRegistryService(firestore: fs, uidProvider: () => 'u1');
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);
      addTearDown(svc.dispose);

      // 2 remote + this device's own registration.
      expect(svc.totalDevices, 3);
      expect(svc.onlineCount, 2); // other-1 and self
      expect(svc.offlineCount, 1); // other-2, last seen 3h ago
    });

    test('the roster puts online devices first — an admin scanning it during '
        'an incident cares who is reachable now', () async {
      final fs = FakeFirebaseFirestore();
      final now = DateTime.now().toUtc();
      await fs.collection('users').doc('stale').set({
        'name': 'পুরোনো',
        'lastSeen': now.subtract(const Duration(days: 2)).toIso8601String(),
      });
      await fs.collection('users').doc('live').set({
        'name': 'সক্রিয়',
        'lastSeen': now.toIso8601String(),
      });

      final svc =
          DeviceRegistryService(firestore: fs, uidProvider: () => null);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);
      addTearDown(svc.dispose);

      expect(svc.devices.first.name, 'সক্রিয়');
      expect(svc.devices.last.name, 'পুরোনো');
    });

    test('notifies listeners when a new device joins', () async {
      final fs = FakeFirebaseFirestore();
      final svc =
          DeviceRegistryService(firestore: fs, uidProvider: () => null);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);
      addTearDown(svc.dispose);

      var notified = false;
      svc.addListener(() => notified = true);

      await fs.collection('users').doc('newcomer').set({
        'name': 'নতুন',
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      });
      await Future<void>.delayed(Duration.zero);

      expect(notified, isTrue);
      expect(svc.totalDevices, 1);
    });

    test('initialize is idempotent', () async {
      final fs = FakeFirebaseFirestore();
      final svc = DeviceRegistryService(firestore: fs, uidProvider: () => 'u1');
      await svc.initialize();
      await svc.initialize();
      addTearDown(svc.dispose);
      expect(svc.isInitialized, isTrue);
    });
  });
}
