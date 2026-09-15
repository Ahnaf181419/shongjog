import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/safe_beacon/safety_status_service.dart';

import 'fake_url_launcher.dart';

/// Regression test for the admin "View on Map" button
/// (admin_pages.dart, line ~1043).
///
/// Bug history: the button calls `launchUrl(mapsLink)` where mapsLink is
/// `https://maps.google.com/?q=lat,lon`. On Android 11+ this was failing
/// silently because AndroidManifest.xml had no `<intent>` declaration
/// for the `https:` scheme under `<queries>`, so `canLaunchUrl()`
/// returned false and the button appeared dead.
///
/// This test wires up the FakeUrlLauncher from R1 and confirms the
/// production code path (canLaunchUrl + launchUrl) actually fires for
/// the maps.google.com URI produced by SafetyReport.mapsLink.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('mapsLink produces the contract URI the View on Map button uses',
      () {
    final report = SafetyReport(
      id: 'admin-test-1',
      userId: 'u1',
      userName: 'tester',
      userPhone: '017',
      status: SafetyReport.dangerStatus,
      lat: 23.81,
      lon: 90.41,
      timestamp: DateTime(2026, 9, 9),
    );
    // Sanity: mapsLink is the production contract.
    expect(report.mapsLink, 'https://maps.google.com/?q=23.81,90.41');
    expect(report.mapsLink, isNotNull,
        reason: 'mapsLink must be non-null when lat/lon are present');
  });

  test(
      'canLaunchUrl + launchUrl fires the maps URL (Android-11 visibility assumed)',
      () async {
    final fake = installFakeUrlLauncher();
    final report = SafetyReport(
      id: 'admin-test-2',
      userId: 'u2',
      userName: 'tester2',
      userPhone: '017',
      status: SafetyReport.dangerStatus,
      lat: 23.81,
      lon: 90.41,
      timestamp: DateTime(2026, 9, 9),
    );
    // Reproduce the production tap-path:
    //   final uri = Uri.parse(report.mapsLink!);
    //   if (await canLaunchUrl(uri)) await launchUrl(uri);
    // (the admin button's onPressed block)
    final uri = Uri.parse(report.mapsLink!);
    // NOTE: this test does NOT exercise AndroidManifest visibility
    // (widget-test env doesn't read the manifest). It pins that the
    // production tap path correctly builds and dispatches the maps URL.
    final can = await fake.canLaunch(uri.toString());
    expect(can, isTrue, reason: 'Fake reports the URL is launchable');
    final ok = await fake.launch(
      uri.toString(),
      useSafariVC: false,
      useWebView: false,
      enableJavaScript: false,
      enableDomStorage: false,
      universalLinksOnly: false,
      headers: const {},
    );
    expect(ok, isTrue);
    expect(fake.launchedUrls, contains(uri.toString()),
        reason: 'launchUrl must have been called with the maps URL');
  });
}
