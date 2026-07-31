import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/safe_beacon/safety_status_service.dart';

/// Mesh safety relay was dead code until this was fixed: the sender built its
/// payload as `'SAFE:${report.toJson()}'`, and interpolating a Map calls
/// `Map.toString()`, which emits `{id: safe-1, userId: u-2, …}` — not JSON.
/// Every receiver's `jsonDecode` threw, the catch swallowed it, and no report
/// ever landed. These tests pin both halves of the wire contract.
void main() {
  SafetyReport sample({String id = 'safe-1', String note = ''}) => SafetyReport(
        id: id,
        userId: 'u-2',
        userName: 'পরীক্ষা',
        userPhone: '01700000000',
        status: SafetyReport.safeStatus,
        note: note,
        lat: 23.81,
        lon: 90.41,
        timestamp: DateTime.utc(2026, 7, 31, 12),
      );

  test('Map.toString is NOT valid JSON — the shape of the original bug', () {
    final broken = '${sample().toJson()}';
    expect(() => jsonDecode(broken), throwsFormatException);
  });

  test('jsonEncode round-trips a report through ingestJson', () {
    final service = SafetyStatusService();
    addTearDown(service.dispose);

    service.ingestJson(jsonEncode(sample().toJson()));

    expect(service.totalUsers, 1);
    expect(service.all.single.userId, 'u-2');
    expect(service.all.single.userName, 'পরীক্ষা');
    expect(service.all.single.lat, closeTo(23.81, 1e-9));
  });

  test('a note containing a bare % no longer breaks the parse', () {
    // ingestJson used to run Uri.decodeComponent unconditionally, which
    // throws FormatException on a lone '%'.
    final service = SafetyStatusService();
    addTearDown(service.dispose);

    service.ingestJson(jsonEncode(sample(note: '৫০% পানি নেই').toJson()));

    expect(service.totalUsers, 1);
    expect(service.all.single.note, contains('%'));
  });

  test('a percent-encoded payload still parses (legacy encode() format)', () {
    final service = SafetyStatusService();
    addTearDown(service.dispose);

    service.ingestJson(Uri.encodeComponent(jsonEncode(sample().toJson())));

    expect(service.totalUsers, 1);
    expect(service.all.single.userId, 'u-2');
  });

  test('garbage is dropped without throwing', () {
    final service = SafetyStatusService();
    addTearDown(service.dispose);

    service.ingestJson('not json at all');
    service.ingestJson('');

    expect(service.totalUsers, 0);
  });
}
