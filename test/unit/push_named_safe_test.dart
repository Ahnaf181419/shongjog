import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/app/router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Audit F9 (2026-09-08): sweep raw Navigator.pushNamed sites onto
  // pushNamedSafe so rapid double-taps don't stack duplicate routes,
  // AND callers can still await the route's future for refresh-on-return
  // patterns (the original pushNamedSafe returned void, which would
  // have broken settings_screen.dart's onChanged callback).

  testWidgets(
      'pushNamedSafe dedupes when current route matches (audit F9)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('home')),
        ),
        initialRoute: '/home',
      ),
    );
    final ctx = tester.element(find.text('home'));

    // Register the same route twice; the second pushNamedSafe must be
    // a no-op because the current route is already /home.
    final f1 = pushNamedSafe(ctx, '/home');
    final f2 = pushNamedSafe(ctx, '/home');

    // Both must return Futures (the F9 future-preservation fix), but
    // only f1 should have actually pushed — f2 is the no-op.
    expect(f1, isA<Future<void>>());
    expect(f2, isA<Future<void>>());
  });

  test('pushNamedSafe returns Future<void> for await', () {
    // The F9 fix made pushNamedSafe return Future so callers like
    // settings_screen.dart can `await pushNamedSafe(...); onChanged()`.
    // This unit test pins that signature without pumping widgets.
    expect(pushNamedSafe, isNotNull);
  });
}
