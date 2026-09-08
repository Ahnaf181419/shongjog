# Shongjog — End-to-End Feature / Button / Navigation Audit

Date: 2026-09-08 (re-evaluated 2026-09-08, second pass)
Branch: `design/admin-panel-audit` @ 65bbd6b (clean tree)
Scope: every user-facing control, every navigation edge, every route in `lib/`
Baseline: `flutter analyze` = 0 issues (re-run in re-eval)

## Re-evaluation (2026-09-08, ~30 min after first pass)

Re-verified every finding against the unchanged tree (HEAD still 65bbd6b),
re-ran the analyzer AND — new this pass — actually executed the test suite,
re-hashed the F11 digests, re-counted F6, and pinned exact locations for
F10. Outcomes:

  CORRECTED  1 claim: the first pass repeated the docs' "878 tests pass"
             without running them. Actual run: 890 pass, 1 skip, **2 FAIL**.
             Both failures pre-exist on `main` (introduced by the tawhid
             merge, PR #18) — see N1. "Suite green" is now a P0 item.
  REFINED    F5 (guard is provably dead code), F10 (exact file:line list).
  NEW        N1–N4 below (two failing tests + the merge-without-tests
             process gap + stale home doc-comment + dead l10n key).
  CONFIRMED  F1–F4, F6–F9, F11–F14 all re-proved with fresh greps/reads;
             digests re-hashed (`sha256('admin')` = 8c6976…, matches);
             Semantics=13 / IconButton=25 recount identical; main_shell
             dual-push (F7) re-read line-by-line.

Original method note follows; findings order is severity within each group
(F = original, N = new from re-eval).

## Method

Planned as a 3-way parallel subagent fan-out (chat/AI, emergency/mesh,
home/admin/settings) with save-to-file instructions. All three dispatches
ran past ~55 minutes without writing their output files, so per the
ui-ux-source-review skill's timeout-recovery decision matrix this audit was
completed by direct orchestrator investigation: full reads of the navigation
spine (`app.dart`, `main_shell.dart`, `router.dart`, `app.dart` route table),
bounded greps over `lib/features/`, and targeted reads of every screen's
control surface. Every gap claim below was cross-checked with a specific
grep (noted inline where a claim could plausibly be wrong). If independent
subagent review is required, that needs a fresh session.

═══════════════════════════════════════════════════════════════════════════
═ 1. NAVIGATION MAP (end to end)
═══════════════════════════════════════════════════════════════════════════

Launch flow
  main() → _SplashBoot (app.dart:139)
    ├─ first run → OnboardingScreen (3 pages: welcome/name → permissions → model)
    │    ├─ skip / শেষ করুন / শুরু করুন → sets pref_has_onboarded → MainShell
    │    └─ final page "সেটিংস" → MainShell + pushNamed /settings
    └─ returning → MainShell (mesh start + call service init here)

MainShell — 5 tabs, floating pill nav bar (main_shell.dart:166-183, 185-211)
  0 হোম     HomeScreen
  1 এআই     ChatScreen
  2 টুলস    ToolsScreen          ← NOTE: README/design.md still say "4 tabs"
  3 কার্ড    QuickCardsScreen
  4 আশ্রয়   ShelterMapScreen
  - Tab state cached via Offstage stack; PopScope returns to tab 0 before exit
  - Global dialog listeners: mesh connection request (accept/reject),
    incoming mesh call (local notification + direct push to MeshCallScreen)
  - Cross-tab API: MainShell.goToTab() used by chat empty-state CTA (→3)
    and home tiles (home_screen.dart:874); PendingChatPrompt notifier carries
    quick-card → AI-chat handoffs (quick_cards_screen.dart:196 → chat).

Route table (app.dart:83-116, constants in router.dart)
  /settings            SettingsScreen
  /emergency-contacts  EmergencyContactsScreen
  /about               AboutScreen
  /mesh-radar          MeshRadarScreen
  /triage              TriageWizardScreen (TTS bridge injected)
  /safe-beacon         SafetyStatusScreen      ← NOT SafeBeaconScreen (see F3)
  /directory           DirectoryScreen
  /sos-composer        SosComposerScreen       ← only entered from triage
  /admin-login         AdminLoginScreen → pushReplacement /admin-panel
  /admin-panel         AdminPanelScreen
  /admin-dashboard     AdminDashboardPage      (also inline tiles in panel)
  /admin-users         AdminUsersPage
  /admin-campaigns     AdminCampaignsPage
  /admin-broadcast     AdminBroadcastPage
  /admin-danger-list   AdminDangerListPage
  /notifications       NotificationsScreen
  /profile             ProfileScreen
  /planner             PlannerScreen
  /kit                 KitScreen
  /risk                RiskScreen
  /damage-scanner      DamageScannerScreen
  /situation-summary   SituationSummaryScreen
  /quick-card-detail   QuickCardDetailScreen(cardId from route arguments)
  onUnknownRoute       localized 404 scaffold

Screen → screen edges (push sites)
  home_screen.dart      :47 settings · :117 profile · :204 emergency-contacts
                         :275 notifications · :479 triage · :485 safe-beacon
                         :493 directory · :818 mesh-radar · :874 tab jump
  live_hazards_card     :111 → HazardsListScreen (unnamed MaterialPageRoute)
  chat_screen.dart      :587/:703 EmergencySheet (modal) · :764 → tab 3
  tools_screen.dart     :59 planner | kit | risk | damage-scanner | situation-summary
  quick_cards           tile → QuickCardDetailScreen; AI chip → AI tab w/ prompt
  triiage_wizard        :331 quick-card-detail(cardId) · :342 sos-composer(text)
  contacts              :53 EmergencySheet (panic hero) · FAB add sheet
  settings              :156 emergency-contacts · :241 about · :248 admin-login
                         :611 profile · model picker inline
  admin_login           :95 pushReplacement admin-panel
  admin_panel           :158 admin-danger-list · :405 5 tiles → admin pages
  admin_pages           :774 quick-action chips → admin pages
  mesh_radar            :333 peer tap → (connect) → MeshChatScreen(peer)
  mesh_chat             AppBar call → MeshCallScreen · media bubbles →
                         fullscreen image · :296 delete-confirm dialog
  main_shell            incoming call → MeshCallScreen(isIncoming)
  shelter_map           marker/sheet internal; campaign markers → info sheet
  profile               photo source sheet (gallery/camera), delete-photo dialog
  onboarding            :79 settings (final page)

Modal-only surfaces (no route)
  EmergencySheet (full-screen slide-to-dial 999) — from chat AppBar,
  contacts panic hero, chat error bubble
  Shelter bottom sheets (shelter detail w/ AI brief, campaign detail)
  Broadcast confirm dialog, logout confirm, campaign request dialog,
  clear-cache confirm, model info dialog, delete-chat dialog, add-contact
  sheet, photo-picker sheet, mesh connection dialog.

Depth observations
  - Deepest regular path: Home → Settings → Admin login → Admin panel →
    Campaigns → approve/reject = 5 levels (acceptable for admin power use).
  - All life-safety features are ≤2 taps from a tab bar: triage (Home tile),
    999 (chat AppBar / contacts hero), directory (Home tile), SOS composer
    is the exception — only reachable from the triage terminal screen.
  - No deep links / external URLs into the app (manifest has MAIN only) —
    fine for the offline thesis.

═══════════════════════════════════════════════════════════════════════════
═ 2. CONTROL INVENTORY (per screen)
═══════════════════════════════════════════════════════════════════════════

HOME (home_screen.dart)
  AppBar: profile avatar+name (→ /profile, refreshes on return) ·
    "Emergency call" red pill (→ /emergency-contacts, home_screen.dart:204) ·
    notification bell w/ unread badge (→ /notifications) ·
    settings IconButton (tooltip ✓)
  Body: status chips (online/offline pulse, data-ready — non-tappable) ·
    WeatherCard (tap = retry/load, weather_card.dart) ·
    LiveHazardsCard (tap → full hazards list) ·
    MarineCard (tap = load) · AirQualityCard (tap = retry) ·
    OfflineMessageTile glow → /mesh-radar ·
    _TriageTile → /triage · _SafeBeaconTile → /safe-beacon ·
    _DirectoryTile → /directory · _TipCard (rotating tips, non-tappable) ·
    ModelDownloadBanner (reactive download state) ·
    _DownloadCompletionListener (snackbar on completion)

AI CHAT (chat_screen.dart, chat_input.dart)
  AppBar: title + tier status text (device/cloud/corpus) ·
    red call IconButton (tooltip ✓ → EmergencySheet)
  Empty state: 4 suggestion chips (ORS / shelter / snakebite / rumour) +
    "quick cards" CTA → tab 3
  Error bubble: আবার চেষ্টা করুন (retry) + ৯৯৯ কল (EmergencySheet)
  Input bar: 64dp pulsing mic (hold-to-talk STT, bn-BD) ·
    text field (Semantics label ✓) · 80×64 send button
  Messages: typewriter reveal, TTS auto-read gated by pref_auto_read

TOOLS (tools_screen.dart)
  2×2 grid: পরিকল্পনা / জরুরি ব্যাগ / ঝুঁকি / ক্ষতি স্ক্যান / সারসংক্ষেপ
  (5 tiles, routes see map)

QUICK CARDS (quick_cards_screen.dart)
  Search field + clear suffix · card tiles (expand inline) ·
    "এআই দিয়ে জিজ্ঞাসা" ActionChip → AI tab with seeded prompt
  Detail screen: back button only (content is steps)

PLANNER / KIT / RISK / SITUATION SUMMARY
  planner: name/district/etc. form → FilledButton generate · reset dialog
  kit: inline family form (edit toggle w/ tooltip ✓) → save & generate ·
       generate-from-profile · reset dialog
  risk: district/house form → assess · reset dialog
  summary: single "generate" button → model summary w/ fallback
    (uses hardcoded sample reports — see F4)

DAMAGE SCANNER (damage_scan_screen.dart)
  camera pick (permission pre-flight Permission.camera.request) ·
    gallery pick (Android photo picker) · scan-another · retry ·
    45s timeout, body-size guard, typed error states

TRIAGE WIZARD (triage_wizard_screen.dart)
 AppBar: restart icon · questions: giant হ্যাঁ/না (64dp+) · recap chip ·
  terminal: কার্ড দেখুন (→ quick-card-detail) ·
    ৯৯৯ কল করুন (→ snackbar only — F1) ·
    ৯৯৯ কে জানান (→ /sos-composer — F2) · আবার চেষ্টা করুন (reset)

EMERGENCY SHEET (emergency_sheet.dart)
  close (tooltip ✓) · slide-to-confirm  knob ≥90% → dial 999
  (reduced-motion fallback collapses to big button ✓) ·
  SOS SMS TextButton → Geolocator GPS → silent SMS via SmsChannel,
  typed failure snackbars (sms failed / gps warning)

SOS COMPOSER (sos_composer_screen.dart)
  description field + AI-extract button (tooltip ✓, model function-calling
  fills structured fields, model-not-ready snackbar) · 6 structured fields ·
  live SMS preview · bottom "৯৯৯ কল" FilledButton → _sendSos (see F2)

DIRECTORY (directory_screen.dart)
  division FilterChips · call IconButton per entry (tel: via launchUrl)

CONTACTS (emergency_contacts_screen.dart)
  panic hero (→ EmergencySheet) · contact rows tap = dial ·
    FAB add → bottom-sheet form w/ save · delete flows

SAFE BEACON / SAFETY STATUS (safe_beacon/)
  SafetyStatusScreen (the routed one): safe (green) / danger (red) flow —
    GPS → mesh broadcast + Firestore report + SMS queue to contacts;
    danger type picker chips; offline queue drains on connectivity
  SafeBeaconScreen: NOT ROUTED (F3)

MESH (mesh_radar / mesh_chat / mesh_call)
  radar: rescan (tooltip ✓) · peer count chip · radar animation ·
    peer tiles (tap = connect → chat; star toggle saved contact) ·
    broadcast voice-record + quick-text + send row
  chat: call icon (tooltip ✓ → MeshCallScreen) · attach image/video ·
    voice note record/stop · play/pause voice bubbles · image bubbles →
    fullscreen zoom · delete-chat w/ confirm
  call: accept/reject (incoming) · mute · speaker · hang-up; all haptics

SHELTER (shelter_map_screen.dart)
  AppBar: search toggle (fires AI safety re-ranking) · clear-route ·
    map/list SegmentedButton · shelter markers (tap = fetch route) ·
    campaign markers (tap = info sheet) · zoom ± / locate-me (tooltips ✓,
    spinner state) · NearestCard top-3 (tap row = route) ·
    ShelterRouteInfoCard (details / cancel) · shelter sheet: facts +
    AI risk brief row (spinner → model sentence → deterministic fallback) ·
    GPS banner with reason-specific messages · OfflineBanner

SETTINGS (settings_screen.dart)
  theme SegmentedButton (light/dark/system) · language SegmentedButton
    (bn/en) · 5 SwitchListTiles (auto-read, voice input, sound, prep tips,
    mesh auto-save) · contacts tile · campaign-request tile (dialog form
    w/ type dropdown, submit) · model picker section (variant select,
    download/pause, info dialog w/ tooltip) · KB version · offline-AI
    diagnostics tiles · clear-cache (confirm dialog → ChatStore.clear) ·
    about tile · admin login tile

ADMIN (login, panel, pages, map picker)
  login: username/password fields, show/hide password (tooltip ✓),
    busy spinner, SHA-256 digest gate, pushReplacement on success
  panel: logout (confirm dialog, Semantics ✓) · pending badge ·
    danger-list entry (red, count-reactive) · 5 tiles → pages
  dashboard: stat cards + quick-action chips
  users: device tiles + chips
  campaigns: approve/reject per request (writes Firestore, markers on map)
  broadcast: char counter (danger ink when over) · send (disabled while
    empty/sending) → preview-confirm dialog styled as the real tray
    notification · recent-sent list
  danger list: cards (name/phone/type/GPS/note) + open-map button
    (canLaunchUrl guard)
  map picker: tap-to-pin · search results list · zoom ± · locate · confirm

NOTIFICATIONS (notifications_screen.dart)
  list of admin broadcasts, unread dot + tinted card; read-only (see F5)

PROFILE (profile_screen.dart)
  avatar tap → gallery/camera sheet (Android photo picker) ·
    remove-photo (confirm dialog) · name/phone/district fields · save

ONBOARDING (onboarding_screen.dart)
  page dots · skip · back · next (tonal) · final: সেটিংস / শুরু করুন ·
    name field on page 1 (persists user_name)

ABOUT (about_screen.dart)
  static source attribution list (WHO/BDRCS/MoDMR/BMD/CDC)

System-level interactions
  local notifications: mesh incoming call (tap → call screen), admin
    broadcasts, model download completion, proximity alerts
  Android: photo picker opt-in globally (main.dart:57-62), 19 permissions,
    <queries> for speech/TTS/camera/pickers

═══════════════════════════════════════════════════════════════════════════
═ 3. FINDINGS (severity-ordered)
═══════════════════════════════════════════════════════════════════════════

F1  CRITICAL — Triage "৯৯৯ কল করুন" never dials.
    triage_wizard_screen.dart:312-323 — `_call999()` only shows a snackbar;
    the button (:275-283) is styled as the primary life-safety action on the
    terminal screen of a first-aid wizard. Worse, the snackbar string
    (`triageCalling999` = "Call 999 — Dialing in phone app", app_en.arb:264)
    tells the user dialing is happening. It is not.
    Cross-check: `EmergencyActions.dial('999')` exists and works elsewhere
    (emergency_sheet.dart:224, emergency_contacts_screen.dart:63,83,
    directory via tel:). Fix is ~3 lines: call
    `await EmergencyActions.dial(EmergencyActions.police)` (add import),
    keep haptics, drop the misleading snackbar.

F2  CRITICAL — SOS composer "send" button sends nothing.
    sos_composer_screen.dart:318-321 — `_sendSos()` is
    `Navigator.of(context).pop(_smsPreview)`. No SMS, no dial, no copy.
    The comment says the caller is emergency_sheet.dart — stale:
    cross-checked, emergency_sheet never pushes /sos-composer. The ONLY
    entry is triage_wizard_screen.dart:342, which pushes with
    `pushNamed(...)` and drops the popped value (no `.then`). Net effect:
    a bystander who walked the triage wizard, tapped "৯৯৯ কে জানান",
    filled/verified the report, and hit the big red "৯৯৯ কল" button has
    sent nothing anywhere. Fix: in `_sendSos`, actually deliver —
    `EmergencyActions.sendSos(_smsPreview)` (mirroring emergency_sheet's
    flow) with the same failure snackbar, and/or await the route result in
    the triage handoff and send there.

F3  HIGH — SafeBeaconScreen is orphaned (dead feature, 248 lines + tests).
    safe_beacon_screen.dart implements the demo-famous "আমি নিরাপদ" giant
    button (GPS + mesh broadcast + SMS queue) but nothing constructs it:
    cross-check `grep -rn "SafeBeaconScreen" lib/ test/ integration_test/`
    returns only its own definition (plus a doc comment in
    profile_screen.dart:45). The `/safe-beacon` route maps to
    SafetyStatusScreen (app.dart:92), which is the safe/danger status
    reporter. Two similar features, one shipped, one dead — and the l10n
    keys (`safeBeaconTitle/Desc/Button`) still exist for the dead one.
    Decide: wire SafeBeaconScreen as a second route (or merge its one-tap
    UX into SafetyStatusScreen) or delete it + keys.

F4  HIGH — Situation Summary summarizes hardcoded sample data.
    situation_summary_screen.dart:24-30 — `_reports` is a fixed list of
    three literal queries ("নিকটস্থ সাইক্লোন শেল্টার", "বন্যার পানি…",
    "SOS: আটকা পড়েছি"), with a comment admitting "a richer build would
    pull from chat history + SOS log". README markets this module as
    "session reports into one briefing". Cross-check: ChatStore and the
    SOS log are never read here. The model output looks real in a demo
    but the input is fiction — a judge-credibility risk, not just polish.

F5  MEDIUM — Notifications screen: opening it marks everything read;
    no per-item action.
    notifications_screen.dart:22-25 calls `markAllAsRead()` in initState.
    REFINED in re-eval: the `_hasMarkedRead` guard there is an INSTANCE
    field, not static — initState already runs once per instance, so the
    guard can never be false-wrong and protects nothing. Every push of the
    route creates a new State → marks all read, every time. Tiles have no
    onTap (grep: no GestureDetector/InkWell in the file) — a broadcast
    saying "go to the shelter" cannot deep-link anywhere, and there is no
    clear/dismiss. At minimum add tap-through for actionable broadcasts;
    make the guard `static` if read-on-open is the intended UX.

F6  MEDIUM — Floating nav bar items lack semantics labels.
    main_shell.dart:238-299 — custom GestureDetector+AnimatedContainer
    pills replace NavigationBar. Selected item exposes its Text; the four
    unselected items expose only an Icon with no Semantics label and no
    tooltip (talkback announces nothing meaningful). App-wide Semantics
    count is 13 vs 25 IconButtons (19 of which do have tooltips). Wrap each
    pill in `Semantics(button: true, label: dest.label, selected: …)`.

F7  MEDIUM — Incoming mesh call can stack duplicate call screens.
    main_shell.dart:112-154 — every CallSignalMessage both posts a local
    notification (tap → push MeshCallScreen) AND pushes MeshCallScreen
    directly. Tapping the notification after the auto-push stacks a second
    copy; two rapid signals stack two. Add an "incoming call already
    showing" guard (or route through a single overlay).

F8  MEDIUM — Offline voice input is still the deferred Vosk stub.
    vosk_stt_provider.dart:45,58 — TODOs; recognition currently depends on
    the online Google recognizer via speech_to_text (STT failure
    classification in chat_screen.dart:480-530 is honest about it:
    networkRequired → "চলুন আবার…" messaging). Known/deferred (pubspec
    comment, PROJECT-STATUS Phase 4.1) but it remains the biggest gap
    between the "voice-first offline" pitch and reality. Typed input and
    TTS are the compensating controls.

F9  MEDIUM — pushNamedSafe is inconsistently applied (double-tap stacks).
    router.dart:33 exists to prevent duplicate pushes, but several sites
    use raw Navigator.pushNamed: home_screen.dart:117 (profile),
    triage_wizard_screen.dart:331/:342 (card detail, SOS composer),
    admin_panel_screen.dart:158/:405, admin_pages.dart:774,
    onboarding_screen.dart:79. Rapid double-taps can stack two
    profile/SOS screens. Mechanical sweep, low risk.

F10 MEDIUM — Docs/code drift: "4 tabs" vs 5; "23 chunks" vs 48.
    REFINED in re-eval with exact locations —
    "4 tabs": docs/architecture.md:122, docs/CHANGELOG.md:188,
    docs/PROJECT-STATUS.md:52. (README/design.md do NOT actually say
    "4 tabs" — first pass over-approximated the location; the drift lives
    in the three docs above. main_shell.dart builds 5 destinations.)
    "23 chunks": README.md:53, README.md:204, docs/kaggle-writeup.md:63,
    docs/PROJECT-STATUS.md:15, docs/PROJECT-STATUS.md:367 — while
    `python3 -c len(json.load(assets/kb/corpus.json))` = **48 chunks**.
    Not a code bug; fix the copy before submission judging.

F11 LOW — Admin gate defaults are the well-known admin/admin123 digests.
    admin_login_screen.dart:31-37 — default SHA-256 constants equal
    sha256('admin')/sha256('admin123') (8c6976…, 240be5…). The file itself
    documents this as obfuscation-not-auth with --dart-define override and
    Firestore rules as the real boundary — a known, documented limit.
    For the hackathon build: fine. For any public release: require the
    dart-define (no default) or move the gate server-side.

F12 LOW — Onboarding → Settings push rides a post-setState context.
    onboarding_screen.dart:73-79 — `_goToSettings()` awaits prefs, calls
    `widget.onComplete()` (which swaps this screen out of the tree via the
    startup gate) and then `Navigator.pushNamed(context, …)` on the
    onboarding's own context. It happens to work because the rebuild lands
    on the next frame, but it is one refactor away from
    "deactivated widget's ancestor" errors. Capture
    `Navigator.of(context)` before the await, or defer the push a frame.

F13 LOW — Hardcoded Bangla outside l10n (mostly deliberate content).
    UI chrome is fully localized (grep for Bangla in `Text('…')` under
    features: 0 hits). Remaining literals: SMS bodies
    (safety_status_screen.dart:212-223, safe_beacon_screen.dart:78-83 —
    operator-facing content, EN locale still sends Bangla SMS — correct),
    about_screen source names, SOS/triage model prompts, card/KB content
    artifacts. Acceptable; listing for completeness against the bilingual
    red-line.

F14 LOW — Emergency pill on Home routes to contacts, not the dialer.
    home_screen.dart:191-204 — deliberate (comment: contacts screen
    surfaces 999 + personal contacts) but it makes "999 from Home" a
    2-tap path (pill → 999 row) versus 1-tap from chat AppBar
    (EmergencySheet). Consider routing the pill to EmergencySheet.show()
    and keeping a secondary contacts entry elsewhere.

VERIFIED-GOOD (positive findings)
  + Zero analyzer issues (re-run in re-eval: still 0). Dead-button grep
    (`onPressed: null|onTap: null`) returns nothing.
  + CORRECTED in re-eval: the first pass said "878-test suite" green —
    that was repeated from the docs, not run. Actual: 890 pass, 1 skip,
    2 FAIL (see N1). Treat "suite green" as a P0 fix, not a fact.
  + Life-safety paths that DO work: EmergencySheet slide-to-dial +
    reduced-motion fallback + silent SOS SMS with typed failure states;
    contacts tap-to-dial; directory tel: launch; safety-status
    danger report (GPS + mesh + Firestore + SMS queue).
  + STT failure taxonomy (chat_screen.dart:480-530) distinguishes
    permission vs no-Bangla-pack vs network vs engine — rare quality.
  + Admin branch work (design/admin-panel-audit): dialogAction() sweep is
    consistently applied in every dialog I opened (profile, admin pages,
    mesh delete, settings, main_shell connection dialog); broadcast is
    gated behind a preview-the-real-notification confirm; tiles inherit
    cardTheme; badges use Bangla numerals; logout has Semantics+tooltip.
  + Every on-device AI module I traced has a deterministic fallback
    (shelter brief row, planner/kit/risk fallbacks, tier chain T1→T4).
  + mounted-check discipline after awaits is strong (heuristic sweep
    found no unguarded context-after-await sites).

NEW FINDINGS FROM RE-EVALUATION (N*)

N1  HIGH — Test suite is RED: 2 failures (890 pass / 1 skip / 2 fail).
    Both introduced by the `tawhid` merge (PR #18, commits 25eb7f8+)
    and present on `main` AND this branch:
    a) test/unit/adaptive_color_test.dart:103 "surface radii stay on the
       12/16/20 scale" — FAILS because main_shell.dart:224 uses
       `circular(40)` (the floating nav bar container) and :257 uses
       `circular(30)` (the pill), both outside the locked 12/16/20 scale
       (design.md §5.4). The repo's own design-token test caught the
       floating-nav-bar commit; it was merged without running the suite.
    b) test/widget/home_screen_test.dart:52 "renders 2-tile emergency
       triad" — expects `find.text('জরুরি কার্ড')`, but Home renders no
       such tile anymore (the cards tile moved to tab 3 / triad was
       reworked). Stale test, never updated.
    CONSEQUENCE: any `flutter test` gate (including the release script's
    checks and the predeploy gate) reports failure; new failures hide
    behind these two. Fix: tokens for (a) — or a documented one-off
    exception in the test with design sign-off — and update (b) to the
    current triad labels.

N2  MEDIUM — Process gap: PRs merged with a red suite.
    The tawhid merge (65bbd6b on this branch, PR #18 on main) landed with
    these failures already present, and .github/workflows/ contains only
    deploy-web.yml — no CI job runs `flutter test` or `flutter analyze`
    on PRs. CONTRIBUTING.md demands "suite green before pushing" but
    nothing enforces it. Cheapest durable fix: a 20-line PR workflow
    running analyze + test.

N3  LOW — Stale doc-comment on HomeScreen.
    home_screen.dart:22-23 still documents "AI hero (28 sp CTA on the
    drenched panel)" in the layout order — no hero widget exists (grep
    for hero/CTA widgets in features/home: 0 hits). The layout comment
    misleads the next editor; update to the actual order (status →
    weather → hazards → offline tile → marine → triad → tip).

N4  LOW — Dead l10n key family: `emergencyCards` (+`emergencyCardsCount`).
    app_bn.arb:104-105 / app_en.arb:98-99 — `emergencyCards` has zero
    references in lib/ outside the generated localizations files (grep
    confirmed). Orphaned by the same Home rework that broke test (N1b).
    Delete from both ARBs and regenerate, alongside fixing N1b.


═══════════════════════════════════════════════════════════════════════════
═ 4. SCORE CARD (updated in re-eval)
═══════════════════════════════════════════════════════════════════════════

  Navigation architecture            7.0   solid shell+routes; F2/F7/F9
  Feature completeness vs claims     6.0   F3 orphan, F4 sample data, F8 stub
  Life-safety action integrity       5.0   F1+F2 dead 999 paths in triage
  Feedback & error handling          8.5   typed failures, snackbars, fallbacks
  Accessibility                      6.5   tooltips good; F6 nav labels, scale cap
  l10n / bilingual discipline        8.0   chrome localized; N4 dead key, F13
  Design-system conformance          7.0   −1.0: N1a token violation in shell
  Docs/code consistency              5.5   F10 (5 sites), N3, + "878 tests" claim
  Test/CI integrity                  6.0   NEW dimension: 2 red tests, no CI (N1/N2)
  ─────────────────────────────────────
  Composite (audited scope)          ≈6.6/10  →  B− "ship-with-fixes"

  Composite moved 6.9 → 6.6. Nothing in the original audit was wrong about
  the app's screens; the re-eval cost comes from (a) the suite being red —
  which the first pass asserted as green by trusting docs — and (b) the
  shell itself violating the design-token scale the branch is named after.

  Verdict: the offline core (cards, triage decision tree, shelter ranker,
  tier chain, mesh) is genuinely strong. What blocks "demo-safe" is the
  triage terminal's two dead 999 actions (F1, F2) — in a disaster-app
  pitch, a judge tapping those is the worst possible failure — plus a red
  test suite that will surface in any `flutter test` gate during judging.

═══════════════════════════════════════════════════════════════════════════
═ 5. FIX QUEUE (priority order — updated in re-eval)
═══════════════════════════════════════════════════════════════════════════

  P0  F1  Wire triage _call999 → EmergencyActions.dial.            ~10 min
  P0  F2  Make SOS composer _sendSos actually send (SMS/dial) +
          consume the popped value in triage.                      ~30 min
  P0  N1  Green the suite: tokens or documented exception for the
          nav-bar radii; update the stale জরুরি কার্ড expectation.   ~40 min
  P1  N2  Add PR CI workflow (analyze + test).                     ~30 min
  P1  F3  Route or delete SafeBeaconScreen (+ its l10n keys).      ~30 min
  P1  F4  Situation summary: feed ChatStore/SOS log, keep samples
          only as empty-state demo seed.                           ~2 h
  P2  F6  Semantics labels on the 5 floating nav pills.            ~20 min
  P2  F7  Dedup incoming-call screen pushes.                       ~30 min
  P2  F5  Notifications: tap-through + per-item read (static
          guard if read-on-open intended).                         ~1 h
  P2  F9  Sweep remaining pushNamed → pushNamedSafe.               ~30 min
  P3  F10+N3+N4  Docs sweep: 5 "23 chunks" sites, 3 "4 tabs" sites,
          stale home doc-comment, dead emergencyCards keys.        ~45 min
  P3  F12 Capture Navigator before await in onboarding.            ~10 min
  P3  F14 Consider pill → EmergencySheet.                          product call

  Regression guard after P0 fixes: extend test/widget/triage_wizard_test.dart
  to assert the 999 button opens the dialer (mock channel) and the SOS
  composer handoff ends in a send attempt, so F1/F2 can never recur.
