import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthService', () {
    test('ensureSignedIn signs in when no user is present', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final svc = FirebaseAuthService(auth: auth, firestore: FakeFirebaseFirestore());

      expect(svc.uid, isNull);
      await svc.ensureSignedIn();
      expect(svc.uid, isNotNull);
    });

    test('ensureSignedIn is a no-op when already signed in', () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final svc = FirebaseAuthService(auth: auth, firestore: FakeFirebaseFirestore());
      final before = svc.uid;

      await svc.ensureSignedIn();

      expect(svc.uid, before);
    });

    test('claimAdminRole writes role:admin to this uid\'s Firestore doc',
        () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final fakeFs = FakeFirebaseFirestore();
      final svc = FirebaseAuthService(auth: auth, firestore: fakeFs);

      await svc.claimAdminRole();

      final snap = await fakeFs.collection('users').doc(svc.uid).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['role'], 'admin');
    });

    test('claimAdminRole is a no-op (never throws) when not signed in', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final fakeFs = FakeFirebaseFirestore();
      final svc = FirebaseAuthService(auth: auth, firestore: fakeFs);

      await svc.claimAdminRole();

      final snap = await fakeFs.collection('users').get();
      expect(snap.docs, isEmpty);
    });
  });
}
