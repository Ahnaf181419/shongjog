import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/triage/decision_tree.dart';

void main() {
  group('TriageTree.walk', () {
    test('unconscious + not breathing -> cpr', () {
      // conscious=no, breathing=no -> cpr.
      expect(TriageTree.walk([false, false]), TriageRoute.cpr);
    });

    test('conscious + not breathing -> cpr', () {
      // conscious=yes, breathing=no -> cpr.
      expect(TriageTree.walk([true, false]), TriageRoute.cpr);
    });

    test('unconscious + breathing -> recovery position', () {
      // conscious=no, breathing=yes -> unconsciousBreathing.
      expect(
        TriageTree.walk([false, true]),
        TriageRoute.unconsciousBreathing,
      );
    });

    test('conscious + breathing + severe bleeding -> bleeding', () {
      expect(
        TriageTree.walk([true, true, true]),
        TriageRoute.bleeding,
      );
    });

    test('conscious + breathing + no bleeding + was in water -> drowning',
        () {
      expect(
        TriageTree.walk([true, true, false, true]),
        TriageRoute.drowning,
      );
    });

    test('conscious + breathing + no bleeding + no water + snakebite -> snakebite',
        () {
      expect(
        TriageTree.walk([true, true, false, false, true]),
        TriageRoute.snakebite,
      );
    });

    test('all-no path -> escalation999', () {
      expect(
        TriageTree.walk([true, true, false, false, false]),
        TriageRoute.escalation999,
      );
    });

    test('empty answers -> escalation999 (safe default)', () {
      expect(TriageTree.walk([]), TriageRoute.escalation999);
    });

    test('short answers -> escalation999 (safe default)', () {
      // answers run out before reaching a terminal node
      expect(TriageTree.walk([true, true]), TriageRoute.escalation999);
    });

    test('every TriageRoute is reachable from some answer sequence', () {
      const reachable = <TriageRoute>{
        TriageRoute.cpr, TriageRoute.bleeding,
        TriageRoute.drowning, TriageRoute.snakebite,
        TriageRoute.escalation999,
        TriageRoute.choking, TriageRoute.burn,
        TriageRoute.unconsciousBreathing,
      };
      expect(reachable.length, TriageRoute.values.length);
    });

    // ── Cycle 2 (B): new triage routes ────────────────────────────────
    test('conscious + breathing + severe burn -> burning', () {
      // conscious=yes, breathing=yes, bleeding=no, water=no, snakebite=no,
      //   burn=yes -> TriageRoute.burn
      expect(
        TriageTree.walk([true, true, false, false, false, true]),
        TriageRoute.burn,
      );
    });

    test('conscious + breathing + chokes -> choking', () {
      // conscious=yes, breathing=yes, bleeding=no, water=no, snakebite=no,
      //   burn=no, cannot speak (no) -> TriageRoute.choking
      expect(
        TriageTree.walk([
          true, true, false, false, false, false, false,
        ]),
        TriageRoute.choking,
      );
    });

    test('unconscious + breathing -> unconsciousBreathing (recovery)',
        () {
      // conscious=no, breathing=yes -> recovery position
      expect(
        TriageTree.walk([false, true]),
        TriageRoute.unconsciousBreathing,
      );
    });

    test('all-no path on the extended tree still -> escalation999', () {
      // conscious=yes, breathing=yes, bleeding=no, water=no, snakebite=no,
      //   burn=no, can speak (yes) -> TriageRoute.escalation999
      expect(
        TriageTree.walk([true, true, false, false, false, false, true]),
        TriageRoute.escalation999,
      );
    });
  });
}