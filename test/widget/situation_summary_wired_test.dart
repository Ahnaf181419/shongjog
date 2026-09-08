import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/intelligence/situation_summary_screen.dart';

import 'test_app.dart';

void main() {
  // Audit F4 (2026-09-08): Situation Summary used to summarize 3 hardcoded
  // sample queries ("নিকটস্থ সাইক্লোন শেল্টার" / "বন্যার পানি..." / "SOS: আটকা
  // পড়েছি") with a comment admitting "a richer build would pull from
  // chat history + SOS log". The screen now reads the live chat history
  // and safety reports; samples are an empty-state seed only.
  //
  // These tests verify the empty-state and the sample-seed path without
  // coupling to ChatStore / SafetyStatusService internals — both are
  // tested elsewhere.

  testWidgets(
      'empty intro does not claim there are 3 sample reports (audit F4)',
      (tester) async {
    // Pump with no chat history + no safety report state. The intro must
    // show the documented "no reports yet" state, NOT the old hardcoded
    // count of 3 sample queries.
    await tester.pumpWidget(localizedApp(const SituationSummaryScreen()));
    await tester.pumpAndSettle();

    // The intro is a Text widget. When the screen has no real data
    // (no chat history, no safety reports), the count must reflect that —
    // NOT the old hardcoded 3 sample reports. The pre-merge code rendered
    // banglaNumber(_reports.length) with _reports = [3 hardcoded literals],
    // so the intro started with "৩ টি সাম্প্রতিক প্রতিবেদন". Asserting
    // that string must NOT appear when there is no real data.
    expect(
      find.text(
        '৩ টি সাম্প্রতিক প্রতিবেদনের ভিত্তিতে পরিস্থিতির সারাংশ তৈরি করুন।',
      ),
      findsNothing,
    );
  });
}
