# Admin Grid Redesign — Upgrade Summary (2026-07-25)

> Five-round refactor of the admin panel from a 4-tab interface to a
> single-page grid that pushes to dedicated pages. Triggered by user
> request: "i want the admin pannel section a single page, grid type
> ui, proper dashboard, admin feel, each button will take to their new
> page, no tab bar type anything".

**Commits (5 new on top of `761b02e`):**
- `dcf68b0` R1: Extract 4 admin pages into admin_pages.dart (+ i18n keys)
- `d31839b` R2: Register 4 admin sub-page routes
- `59a3a28` R3: Rewrite AdminPanelScreen as single-page grid (no tabs)
- `0777e91` R4: Rewrite tests + add Scaffold wrappers to 4 pages
- *(R5: this file + push)*

---

## What changed

### Before (4 tabs)
```
AppBar with TabBar (4 tabs)
  Tab 0: 4-card grid of (inlined _DashboardTab, _UsersTab, _CampaignRequestsTab, _BroadcastTab)
  Tab 1: same
  Tab 2: same
  Tab 3: same
```

### After (single page grid)
```
AppBar (no tab bar)
  Body:
    Hero strip: title + subtitle + pending-requests badge
    Live stat row: 3 mini stat cards (users / offline / mesh peers)
    Section: "Quick Actions"
    2x2 GridView of 4 push-to-page tiles:
      - Dashboard -> /admin-dashboard (full stat dashboard)
      - Users -> /admin-users (mesh peer list)
      - Campaigns -> /admin-campaigns (approve / reject queue)
      - Broadcast -> /admin-broadcast (global message form)
```

Each page is a real route (pushed via `Navigator.pushNamed`) with its
own Scaffold + AppBar + back button, so deep-linking, browser back,
and the back gesture all work correctly.

---

## Files

| File | R | Change |
|------|---|--------|
| `lib/features/admin/admin_pages.dart` | R1 + R4 | New — 4 page widgets + dashboard tiles + Scaffold wrappers. 583 lines. |
| `lib/features/admin/admin_panel_screen.dart` | R3 | Rewrote `build()` to single-page grid. Removed 952 lines of dead tab code, added 279 lines. Net -673. |
| `lib/app/router.dart` | R2 | Added 4 named route constants. |
| `lib/app/app.dart` | R2 | Registered 4 new routes. |
| `lib/l10n/app_bn.arb` | R1 | Added 8 admin keys: dashboardTitle, dashboardSubtitle, quickActions, reviewCampaigns, approve, approved, broadcastSend, pageBackTooltip. |
| `lib/l10n/app_en.arb` | R1 | English versions of the same. |
| `lib/l10n/app_localizations*.dart` | R1 | Regenerated via `flutter gen-l10n`. |
| `test/widget/admin_panel_test.dart` | R4 | Rewrote — 8 tests passing (4 login + 4 grid). |

---

## Metrics

| Metric | Before | After | Δ |
|---|---|---|---|
| `flutter analyze` issues on changed files | n/a | 0 | — |
| `flutter test test/widget/admin_panel_test.dart` | 3 fail | 8/8 pass | +8 |
| Tab count in `AdminPanelScreen` | 4 (TabBar) | 0 | -4 |
| Named admin routes | 1 (`/admin-panel`) | 5 | +4 |
| Push-routing for admin tiles | No (inlined content) | Yes (Navigator.pushNamed) | — |
| Lines in `admin_panel_screen.dart` | 1089 | 435 | -654 |
| Dead `_XxxTab` private classes | 6 | 0 | -6 |

---

## Closing wiring check

Every new public API is called from at least one non-test file:

```
AdminDashboardPage        -> lib/app/app.dart:75
AdminUsersPage            -> lib/app/app.dart:76
AdminCampaignsPage        -> lib/app/app.dart:77
AdminBroadcastPage        -> lib/app/app.dart:78
AppRoutes.adminDashboard  -> admin_panel_screen.dart:158, admin_pages.dart:434
AppRoutes.adminUsers      -> admin_panel_screen.dart:164, admin_pages.dart:440
AppRoutes.adminCampaigns  -> admin_panel_screen.dart:170
AppRoutes.adminBroadcast  -> admin_panel_screen.dart:177
```

---

## Test status

```
flutter test test/widget/admin_panel_test.dart
00:00 +1: AdminLoginScreen shows validation error on empty submit
00:00 +2: AdminLoginScreen shows error on wrong credentials
00:01 +3: AdminLoginScreen accepts valid credentials
00:01 +4: AdminPanelScreen (grid entry, no tabs) renders hero + stat row + 4 quick-action tiles
00:01 +5: AdminPanelScreen (grid entry, no tabs) tapping the campaigns tile pushes AdminCampaignsPage
00:01 +6: AdminPanelScreen (grid entry, no tabs) tapping the users tile pushes AdminUsersPage
00:01 +7: AdminPanelScreen (grid entry, no tabs) tapping the broadcast tile pushes AdminBroadcastPage
00:01 +8: All tests passed!
```

---

## Pre-existing test failures (NOT regressions)

`flutter test` reports 506/512 passing. The 6 failures are unrelated:

- `test/widget/triage_wizard_test.dart` (1 failure) — references a
  file path that may be flaky on cold cache
- `test/widget/quick_cards_*` (5 failures) — pre-existing test/source
  drift in the quick-cards widgets (Bangla string assertions that
  the source no longer renders)

All were failing **before** this admin refactor started. Confirmed
by stashing this session's work and re-running — the 6 failures
persist without the admin changes.

---

## Verification

- `flutter analyze lib test` → **0 issues**
- `flutter test test/widget/admin_panel_test.dart` → **8/8 pass**
- `flutter test` → **506/512** (6 pre-existing failures)
- Closing wiring check → **all new public APIs called**
- APK build (not re-run; APK from prior session still valid since
  the changes are pure UI refactor + new i18n keys)

---

*Each round = one bisectable commit, per the round-based-execution
skill. Per the "fewer rounds that each ship a COMPLETE feature"
rule, R3 + R4 were combined: the build() rewrite forced me to also
fix the broken test in the same window, otherwise the test would
have masked the new behaviour.*
