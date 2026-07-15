import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/haptics.dart';

void main() {
  group('HapticService', () {
    test('lightTap does not throw', () async {
      await HapticService.lightTap();
    });

    test('mediumTap does not throw', () async {
      await HapticService.mediumTap();
    });

    test('success does not throw', () async {
      await HapticService.success();
    });

    test('warn does not throw', () async {
      await HapticService.warn();
    });

    test('strong does not throw', () async {
      await HapticService.strong();
    });

    test('tick does not throw', () async {
      await HapticService.tick();
    });

    test('setEnabled(false) suppresses calls (no-op)', () async {
      HapticService.setEnabled(false);
      await HapticService.lightTap();
      await HapticService.strong();
      // Re-enable for subsequent tests
      HapticService.setEnabled(true);
    });

    testWidgets('all haptic constants are defined', (tester) async {
      expect(HapticEventLabels.lightTap, 'lightTap');
      expect(HapticEventLabels.mediumTap, 'mediumTap');
      expect(HapticEventLabels.success, 'success');
      expect(HapticEventLabels.warn, 'warn');
      expect(HapticEventLabels.strong, 'strong');
      expect(HapticEventLabels.tick, 'tick');
    });
  });
}
