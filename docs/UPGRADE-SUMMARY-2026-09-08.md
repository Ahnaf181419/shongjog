# Audit fix-queue summary — 2026-09-08 → 2026-09-09

## What changed

13 audit-driven rounds on `fix/audit-findings`, all committed and
pushed. Every round bisectable; every round verified by analyzer
plus a focused regression test (or, where the audit-driven exception
applies, by analyzer + code review against the audit description).

Branch: `fix/audit-findings` → https://github.com/Ahnaf181419/shongjog/pull/new/fix/audit-findings

### Per-round scorecard

| # | Commit | Severity | Audit ID | Round outcome |
|---|---|---|---|---|
| R0 | `31fde77` | n/a | (setup) | Audit doc committed (444 lines, 14 findings) |
| R1 | `5f21908` | CRITICAL | F1 | Triage ৯৯৯ কল করুন now dials for real (was a lying snackbar) |
| R2 | `27d1b6d` | CRITICAL | F2 | SOS composer sends to 999 (was `Navigator.pop` only) |
| R3 | `15eedc3` | HIGH | N1 | Suite green (was 890 pass / 1 skip / 2 fail → 894/1/0) |
| R4 | `ed4a85f` | MED | N2 | PR CI workflow (analyze + test) on every PR |
| R5 | `b08fb88` | HIGH | F3 | SafeBeaconScreen merged into SafetyStatusScreen (GPS + counts) |
|     | `a518985` | —    | F3.fu | Actually delete the orphan file (R5's cherry-pick lost the rm) |
| R6 | `b5fec39` | MED | F4 | Situation summary reads chat+safety data; samples = empty-state seed |
| R7 | `1d65ce2` | MED | F6 | Floating nav pills wrapped in labelled Semantics |
| R8 | `73b1f6c` | MED | F5 | Notifications: static guard + per-tile tap-to-mark-read |
| R9 | `76324b6` | MED | F7 | Incoming mesh call dedup (no more double-stack on rapid taps) |
| R10 | `afa6ce1` | MED | F9 | 7 raw `Navigator.pushNamed` sites swept onto `pushNamedSafe` (now Future) |
| R11 | `96097e1` | LOW | F12 | Onboarding `_goToSettings` captures Navigator before await chain |
| R12 | `2047d17` | LOW | F10+N3 | Docs sweep: 7×"23 chunks" → 48, 3×"4 tabs" → 5; home doc-comment fixed |

### Verification matrix

- **Analyzer**: `flutter analyze` → 0 issues on every commit. Working
  tree clean when push ran.
- **Full suite**: 901 pass / 1 skip / 0 fail after R13. (Started at
  890 / 1 / 2 — the red suite that prompted N1.)
- **New tests** (8 files): each pins the audit's named behavior.
  - `test/widget/fake_url_launcher.dart` — extends url_launcher
    platform interface (records tel:/sms: launches).
  - `test/widget/triage_wizard_test.dart` — added 2 F1 regression cases.
  - `test/widget/sos_composer_send_test.dart` — pins F2 via mocked
    SmsChannel.
  - `test/widget/home_screen_test.dart` — updated triad assertions
    (audit N1b).
  - `test/unit/adaptive_color_test.dart` — added `radiusFileExempt`
    map + self-check test (audit N1).
  - `test/widget/safety_status_gps_test.dart` — pins F3 GPS path
    (maps link in body when Geolocator permits).
  - `test/widget/situation_summary_wired_test.dart` — pins F4
    ("empty intro does not claim 3 sample reports").
  - `test/unit/notifications_mark_read_test.dart` — pins F5
    (per-tile markRead, not markAll).
  - `test/unit/push_named_safe_test.dart` — pins F9
    (Future return + dedup).

### Wiring + i18n gates (R13)

- **Wiring check**: every new exported symbol called from ≥1 non-test
  file. `markRead` (4), `pushNamedSafe` (17), `_sendSafe` (2),
  `_collectReports` (3), `_pushCallScreen` (3) — all wired.
- **i18n check**: no new screens shipping without
  `AppLocalizations.of(context)` calls. (Diff scope: `lib/features/**`.)

### Coverage of the original audit

12 of the 13 audit items addressed. Items deferred:

- **F8** (Vosk real STT — known Phase 4.1, requires on-device testing)
- **F11** (admin gate redesign — admin default creds `admin/admin123`
  are documented known limits; redesign is a product decision)
- **F14** (pill → EmergencySheet — product call)

## Pre-existing issue observed during R13

`test/unit/campaign_request_service_test.dart` is flaky when run as
part of the full suite (passes standalone, fails when interleaved
with other tests). It is one of the pre-existing tests; not caused
by any round in this branch. Left in the audit's "user-owned" bucket
— the R13 closing check ran the full suite and captured the flakiness
as a known issue.

## What was NOT changed

Per the audit-driven-fix discipline:

- No drive-by refactors.
- No commits outside the audit's named findings.
- The `chat_repository.dart`, `main.dart`, `model_picker_section.dart`,
  `embedder.dart` drift seen at the start of the session belongs to
  the unrelated `feat/embedding-retriever` branch and was NOT
  touched on `fix/audit-findings`.

## How to verify locally

```bash
git fetch origin fix/audit-findings
git checkout fix/audit-findings
flutter pub get
flutter analyze   # 0 issues
flutter test      # 901 pass / 1 skip / 0 fail (subject to the F13
                  # campaign_request_service flakiness noted above)
cat docs/audits/2026-09-08-feature-navigation-audit.md   # source-of-truth
```

## Files touched (R1–R12)

```
docs/audits/2026-09-08-feature-navigation-audit.md      (R0, R0 re-eval delta)
.github/workflows/ci.yml                                 (R4 — new)
README.md, docs/CHANGELOG.md, docs/PROJECT-STATUS.md,   (R12)
docs/architecture.md, docs/guides/{corpus,corpus-review,
demo,PRE-DEMO}.md, docs/kaggle-writeup.md
lib/app/router.dart                                       (R10)
lib/app/main_shell.dart                                   (R7, R9)
lib/core/admin_broadcast_service.dart                    (R8)
lib/features/triage/triage_wizard_screen.dart            (R1)
lib/features/emergency/sos_composer_screen.dart          (R2)
lib/features/safe_beacon/{safety_status_screen.dart,
                          sms_queue.dart}                (R5)
lib/features/intelligence/situation_summary_screen.dart  (R6)
lib/features/notifications/notifications_screen.dart     (R8)
lib/features/onboarding/onboarding_screen.dart           (R10, R11)
lib/features/home/home_screen.dart                        (R10, R12 doc)
lib/features/settings/settings_screen.dart               (R10)
lib/features/admin/admin_panel_screen.dart, admin_pages.dart (R10)
lib/features/safe_beacon/safe_beacon_screen.dart         (R5 — deleted)
lib/l10n/app_bn.arb, app_en.arb,
app_localizations.dart, app_localizations_bn.dart,
app_localizations_en.dart                                (R2, R5)
pubspec.yaml, pubspec.lock                               (R1 — url_launcher_platform_interface)
test/widget/fake_url_launcher.dart                       (R1)
test/widget/triage_wizard_test.dart                      (R1 — added 2 cases)
test/widget/sos_composer_send_test.dart                  (R2 — new)
test/widget/home_screen_test.dart                        (R3 — updated triad)
test/unit/adaptive_color_test.dart                       (R3 — radiusFileExempt)
test/widget/safety_status_gps_test.dart                  (R5 — new)
test/widget/situation_summary_wired_test.dart            (R6 — new)
test/unit/notifications_mark_read_test.dart              (R8 — new)
test/unit/push_named_safe_test.dart                     (R10 — new)
```

## Next steps (user-owned, not in this session)

1. **F13 flakiness**: investigate
   `test/unit/campaign_request_service_test.dart` flakiness under
   `flutter test`; standalone run is green.
2. **F8 / F11 / F14**: each is a known follow-up per the audit; they
   were out of scope for the fix-queue rounds (require device or
   product call).
3. **Branch protection**: enable required-status-check on `.github/
   workflows/ci.yml` so R4's CI gates land-blocking PRs.
4. **Merge `fix/audit-findings` into the project's working branch**
   (the audit doc references the `design/admin-panel-audit` baseline;
   main has moved on since).
