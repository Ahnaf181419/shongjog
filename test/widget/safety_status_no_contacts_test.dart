import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/safe_beacon/safety_status_screen.dart';

import 'test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Independent-review suggestions (post-audit polish, 2026-09-09):
  // 2. _sendSafe() showed "willNotifyOnReconnect(0)" when no contacts
  //    were configured — misleading UX. Add an explicit "no contacts"
  //    branch.
  // 3. _sendDanger() ignored the (sent, pending) record from _queueSms,
  //    unlike _sendSafe(). Surface the same count-aware feedback on
  //    the danger path so operators see the truth.

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    connectivityProvider.debugSetOnline(true);
  });

  tearDown(() {
    connectivityProvider.debugSetOnline(false);
  });

  testWidgets(
      'safe path with no contacts does NOT say "will notify 0 on reconnect"',
      (tester) async {
    // No contacts configured (SharedPreferences mocked empty above).
    await tester.pumpWidget(localizedApp(const SafetyStatusScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('আমি নিরাপদ'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The misleading "০জনকে জানানো হবে সংযোগ ফিরলে।" must NOT appear
    // when there are zero contacts — there are no "0 to notify".
    expect(find.text('০জনকে জানানো হবে সংযোগ ফিরলে।'), findsNothing);
  });
}
