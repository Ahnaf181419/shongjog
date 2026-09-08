import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/method_channel_url_launcher.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records tel:/sms: launch attempts made through `EmergencyActions`
/// without opening a real dialer in the widget-test environment.
///
/// url_launcher routes through `UrlLauncherPlatform.instance`; swapping in
/// this fake lets a widget test assert that a life-safety button actually
/// attempts to dial (audit F1) — the exact regression the 2026-09-08 audit
/// caught: the triage "৯৯৯ কল করুন" button only showed a snackbar.
class FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  /// When true, `canLaunch` reports false — lets tests exercise the
  /// "dialer unavailable" fallback path.
  bool failCanLaunch = false;

  @override
  Future<bool> canLaunch(String url) async => !failCanLaunch;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return !failCanLaunch;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

/// Installs [fake] as the active url_launcher platform for the duration of
/// one test. Returns the fake so the test can assert on `launchedUrls`.
FakeUrlLauncher installFakeUrlLauncher() {
  final fake = FakeUrlLauncher();
  UrlLauncherPlatform.instance = fake;
  addTearDown(() {
    // Restore a fresh method-channel instance so later tests are isolated.
    UrlLauncherPlatform.instance = MethodChannelUrlLauncher();
  });
  return fake;
}

void main() {
  // Guard: the fake itself must record launches. Keeps this helper honest
  // if url_launcher's platform interface changes shape.
  test('FakeUrlLauncher records launched urls', () async {
    final fake = installFakeUrlLauncher();
    final ok = await fake.launch(
      'tel:999',
      useSafariVC: false,
      useWebView: false,
      enableJavaScript: false,
      enableDomStorage: false,
      universalLinksOnly: false,
      headers: const {},
    );
    expect(ok, isTrue);
    expect(fake.launchedUrls, ['tel:999']);
  });
}
