import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/safe_beacon/safety_status_service.dart';

void main() {
  late SafetyStatusService svc;

  setUp(() {
    svc = SafetyStatusService();
  });

  group('SafetyReport', () {
    test('isDanger / isSafe flags', () {
      final safe = SafetyReport(
        id: '1',
        userId: 'u1',
        userName: 'A',
        userPhone: '',
        status: SafetyReport.safeStatus,
        timestamp: DateTime(2026, 7, 25),
      );
      final danger = SafetyReport(
        id: '2',
        userId: 'u2',
        userName: 'B',
        userPhone: '',
        status: SafetyReport.dangerStatus,
        dangerType: DangerType.flood,
        timestamp: DateTime(2026, 7, 25),
      );
      expect(safe.isSafe, isTrue);
      expect(safe.isDanger, isFalse);
      expect(danger.isDanger, isTrue);
      expect(danger.isSafe, isFalse);
    });

    test('mapsLink is null when no GPS', () {
      final r = SafetyReport(
        id: '1', userId: 'u', userName: 'x', userPhone: '',
        status: SafetyReport.dangerStatus,
        timestamp: DateTime.now(),
      );
      expect(r.mapsLink, isNull);
    });

    test('mapsLink is a Google Maps URL when GPS present', () {
      final r = SafetyReport(
        id: '1', userId: 'u', userName: 'x', userPhone: '',
        status: SafetyReport.dangerStatus,
        lat: 23.8, lon: 90.4,
        timestamp: DateTime.now(),
      );
      expect(r.mapsLink, contains('maps.google.com'));
      expect(r.mapsLink, contains('23.8'));
    });

    test('toJson + fromJson round-trip', () {
      final original = SafetyReport(
        id: 'abc',
        userId: 'u1',
        userName: 'কবির',
        userPhone: '017',
        status: SafetyReport.dangerStatus,
        dangerType: DangerType.trapped,
        note: 'ছাদে আটকা পড়েছি',
        lat: 24.0,
        lon: 90.0,
        timestamp: DateTime(2026, 7, 25, 10, 30),
        hopCount: 2,
      );
      final json = original.toJson();
      final restored = SafetyReport.fromJson(json);
      expect(restored.id, 'abc');
      expect(restored.userId, 'u1');
      expect(restored.userName, 'কবির');
      expect(restored.status, SafetyReport.dangerStatus);
      expect(restored.dangerType, DangerType.trapped);
      expect(restored.note, 'ছাদে আটকা পড়েছি');
      expect(restored.lat, 24.0);
      expect(restored.lon, 90.0);
      expect(restored.hopCount, 2);
    });
  });

  group('DangerType', () {
    test('labelBn returns Bangla for each type', () {
      expect(DangerType.flood.labelBn, 'বন্যা');
      expect(DangerType.fire.labelBn, 'আগুন');
      expect(DangerType.trapped.labelBn, 'আটকা পড়েছি');
      expect(DangerType.medical.labelBn, 'চিকিৎসা জরুরি');
    });

    test('fromId round-trips', () {
      for (final t in DangerType.values) {
        expect(DangerType.fromId(t.id), t);
      }
    });

    test('fromId falls back to other for unknown', () {
      expect(DangerType.fromId('xyz'), DangerType.other);
      expect(DangerType.fromId(null), DangerType.other);
    });
  });

  group('SafetyStatusService', () {
    test('empty service has zero counts', () {
      expect(svc.totalUsers, 0);
      expect(svc.safeCount, 0);
      expect(svc.dangerCount, 0);
      expect(svc.dangerReports, isEmpty);
    });

    test('ingest one safe report', () {
      svc.ingest(SafetyReport(
        id: '1', userId: 'u1', userName: 'A', userPhone: '',
        status: SafetyReport.safeStatus,
        timestamp: DateTime.now(),
      ));
      expect(svc.totalUsers, 1);
      expect(svc.safeCount, 1);
      expect(svc.dangerCount, 0);
    });

    test('ingest one danger report with GPS', () {
      svc.ingest(SafetyReport(
        id: '2', userId: 'u2', userName: 'B', userPhone: '017',
        status: SafetyReport.dangerStatus,
        dangerType: DangerType.flood,
        lat: 23.0, lon: 90.0,
        timestamp: DateTime.now(),
      ));
      expect(svc.totalUsers, 1);
      expect(svc.dangerCount, 1);
      expect(svc.dangerReports.length, 1);
      expect(svc.dangerReports.first.mapsLink, isNotNull);
    });

    test('mixed safe + danger counts correctly', () {
      svc.ingest(_r('u1', safe: true));
      svc.ingest(_r('u2', safe: false));
      svc.ingest(_r('u3', safe: true));
      svc.ingest(_r('u4', safe: false, danger: DangerType.fire));
      expect(svc.totalUsers, 4);
      expect(svc.safeCount, 2);
      expect(svc.dangerCount, 2);
    });

    test('same user sending twice keeps latest', () {
      svc.ingest(SafetyReport(
        id: '1', userId: 'u1', userName: 'A', userPhone: '',
        status: SafetyReport.safeStatus,
        timestamp: DateTime(2026, 7, 25, 10),
      ));
      // Same user, later timestamp, now in danger
      svc.ingest(SafetyReport(
        id: '2', userId: 'u1', userName: 'A', userPhone: '',
        status: SafetyReport.dangerStatus,
        dangerType: DangerType.trapped,
        timestamp: DateTime(2026, 7, 25, 11),
      ));
      expect(svc.totalUsers, 1); // deduped by userId
      expect(svc.dangerCount, 1);
      expect(svc.safeCount, 0);
    });

    test('stale report (older timestamp) is ignored', () {
      svc.ingest(SafetyReport(
        id: '1', userId: 'u1', userName: 'A', userPhone: '',
        status: SafetyReport.dangerStatus,
        timestamp: DateTime(2026, 7, 25, 12),
      ));
      // Older report for same user — should be ignored
      svc.ingest(SafetyReport(
        id: '2', userId: 'u1', userName: 'A', userPhone: '',
        status: SafetyReport.safeStatus,
        timestamp: DateTime(2026, 7, 25, 10),
      ));
      expect(svc.dangerCount, 1); // still danger, stale safe ignored
      expect(svc.safeCount, 0);
    });

    test('setMyReport sets myReport and ingests', () {
      final r = SafetyReport(
        id: 'my', userId: 'me', userName: 'Me', userPhone: '018',
        status: SafetyReport.safeStatus,
        timestamp: DateTime.now(),
      );
      svc.setMyReport(r);
      expect(svc.myReport, isNotNull);
      expect(svc.myReport!.id, 'my');
      expect(svc.totalUsers, 1);
    });

    test('clear removes everything', () {
      svc.ingest(_r('u1', safe: true));
      svc.ingest(_r('u2', safe: false));
      svc.clear();
      expect(svc.totalUsers, 0);
      expect(svc.myReport, isNull);
    });

    test('dangerReports sorted newest-first', () {
      svc.ingest(_r('u1', safe: false,
          ts: DateTime(2026, 7, 25, 8)));
      svc.ingest(_r('u2', safe: false,
          ts: DateTime(2026, 7, 25, 10)));
      svc.ingest(_r('u3', safe: false,
          ts: DateTime(2026, 7, 25, 9)));
      final reports = svc.dangerReports;
      expect(reports[0].userId, 'u2'); // 10:00
      expect(reports[1].userId, 'u3'); // 9:00
      expect(reports[2].userId, 'u1'); // 8:00
    });
  });
}

/// Helper: build a report quickly.
SafetyReport _r(String userId,
    {required bool safe, DangerType? danger, DateTime? ts}) {
  return SafetyReport(
    id: userId,
    userId: userId,
    userName: 'User $userId',
    userPhone: '',
    status: safe ? SafetyReport.safeStatus : SafetyReport.dangerStatus,
    dangerType: safe ? null : (danger ?? DangerType.flood),
    timestamp: ts ?? DateTime.now(),
  );
}
