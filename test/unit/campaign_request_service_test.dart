import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/firebase_auth_service.dart';
import 'package:shongjog/features/admin/campaign_request.dart';

CampaignRequest _req(String id, {CampaignStatus status = CampaignStatus.pending}) {
  return CampaignRequest(
    id: id,
    userId: 'u-$id',
    userName: 'ব্যবহারকারী',
    userPhone: '017',
    type: CampaignType.foodDonation,
    latitude: 23.8,
    longitude: 90.4,
    address: 'ঢাকা',
    description: 'বিবরণ',
    timestamp: DateTime(2026, 7, 25),
    status: status,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('campaign_request_test_');
    CampaignRequestService.debugFilesDirOverride = tempDir.path;
  });

  tearDown(() {
    CampaignRequestService.debugFilesDirOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('CampaignRequestService (local persistence, pre-existing behavior)', () {
    test('submitRequest stores and persists a request', () async {
      final svc = CampaignRequestService(firestore: FakeFirebaseFirestore());
      await svc.submitRequest(_req('r1'));
      expect(svc.requests.length, 1);
      expect(svc.pendingCount, 1);
    });

    test('updateRequestStatus moves a request out of pending', () async {
      final svc = CampaignRequestService(firestore: FakeFirebaseFirestore());
      await svc.submitRequest(_req('r1'));
      await svc.updateRequestStatus('r1', CampaignStatus.approved);
      expect(svc.pendingCount, 0);
      expect(svc.approvedRequests.length, 1);
    });
  });

  group('CampaignRequestService Firestore sync', () {
    test('submitRequest writes the request to Firestore', () async {
      final fakeFs = FakeFirebaseFirestore();
      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.submitRequest(_req('r1'));

      final snap = await fakeFs.collection('campaigns').doc('r1').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['userId'], 'u-r1');
    });

    test('updateRequestStatus writes the status change to Firestore',
        () async {
      final fakeFs = FakeFirebaseFirestore();
      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.submitRequest(_req('r1'));
      await svc.updateRequestStatus('r1', CampaignStatus.approved,
          adminNotes: 'অনুমোদিত');

      final snap = await fakeFs.collection('campaigns').doc('r1').get();
      expect(snap.data()!['status'], CampaignStatus.approved.index);
      expect(snap.data()!['adminNotes'], 'অনুমোদিত');
    });

    test(
        'a campaign request submitted on another device merges into this '
        "device's list", () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('campaigns').doc('remote-1').set(
            _req('remote-1').toJson(),
          );

      // A campaign carries the submitter's phone and coordinates, so the
      // unfiltered read is admin-only; a non-admin device subscribes to
      // approved campaigns alone (all it renders — the map markers).
      SharedPreferences.setMockInitialValues(
          {FirebaseAuthService.prefIsAdminDevice: true});
      await firebaseAuthService.loadAdminFlag();

      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(svc.requests.any((r) => r.id == 'remote-1'), isTrue);
    });

    test('a non-admin device sees approved campaigns but not pending ones',
        () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('campaigns').doc('pending-1').set(
          _req('pending-1').toJson());
      await fakeFs.collection('campaigns').doc('approved-1').set(
          _req('approved-1', status: CampaignStatus.approved).toJson());

      SharedPreferences.setMockInitialValues(
          {FirebaseAuthService.prefIsAdminDevice: false});
      await firebaseAuthService.loadAdminFlag();

      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(svc.requests.any((r) => r.id == 'approved-1'), isTrue);
      expect(svc.requests.any((r) => r.id == 'pending-1'), isFalse);
    });

    test('one malformed document cannot poison the whole batch', () async {
      // `fromJson` indexes CampaignType.values[...] with a raw int, so
      // `type: 99` threw RangeError inside the stream listener and broke the
      // campaign list on every install — with delete denied to all clients,
      // making it unrecoverable in-app.
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('campaigns').doc('poison').set({
        ..._req('poison', status: CampaignStatus.approved).toJson(),
        'type': 99,
      });
      await fakeFs.collection('campaigns').doc('good').set(
          _req('good', status: CampaignStatus.approved).toJson());

      SharedPreferences.setMockInitialValues(
          {FirebaseAuthService.prefIsAdminDevice: false});
      await firebaseAuthService.loadAdminFlag();

      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(svc.requests.any((r) => r.id == 'good'), isTrue);
      expect(svc.requests.any((r) => r.id == 'poison'), isFalse);
    });

    test(
        'an admin approving a request on another device updates this '
        "device's local copy via the Firestore stream", () async {
      final fakeFs = FakeFirebaseFirestore();
      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.submitRequest(_req('r1'));
      expect(svc.pendingCount, 1);

      // Simulate an admin device approving it directly in Firestore.
      await fakeFs.collection('campaigns').doc('r1').set(
            _req('r1', status: CampaignStatus.approved).toJson(),
          );
      await Future<void>.delayed(Duration.zero);

      expect(svc.pendingCount, 0);
      expect(svc.approvedRequests.length, 1);
    });
  });
}
