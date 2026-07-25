import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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

      final svc = CampaignRequestService(firestore: fakeFs);
      await svc.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(svc.requests.any((r) => r.id == 'remote-1'), isTrue);
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
