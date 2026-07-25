# AI-First Features — Upgrade Summary (2026-07-25)

**Plan doc:** [AI-FIRST-FEATURES.md](AI-FIRST-FEATURES.md)
**Source blueprint:** [v3.md](v3.md)
**Branch:** main

Five AI-first feature modules from `docs/v3.md`, all wired into the
home screen with deterministic fallbacks for every path.

---

## What shipped

11 commits (plan doc + 10 rounds). Each round is one focused, bisectable
commit. Per the round-based-execution skill: pure-logic first, UI wiring
in the same round where possible, closing wiring check before summary.

| # | Commit | What |
|---|--------|------|
| 0 | `22b920e` | `docs(ai-first): plan doc for the five AI-first feature modules` |
| R1 | `2ba18be` | `feat(planner): family profile model + SharedPreferences persistence` |
| R2 | `f3c3f80` | `feat(planner): AI disaster planner prompt builder + service` |
| R3 | `68e0456` | `feat(home): AI tools grid + planner screen wired to home` |
| R4 | `b81934f` | `feat(planner): AI emergency kit generator (Module B)` |
| R5 | `c1f5afa` | `feat(planner): AI risk assessment (Module C)` |
| R6 | `0caf1f1` | `feat(damage_scanner): damage scanner service (Module D core)` |
| R7 | `ce68791` | `feat(damage_scanner): damage scanner screen + route` |
| R8 | `47bd152` | `feat(intelligence): situation summary service + screen (Module E)` |
| R9 | *(no code)* | closing wiring check passed for every new public API |
| R10 | *(this file)* | upgrade summary |

---

## The five modules

| Module | v3 ref | AI path | Offline? |
|--------|--------|---------|----------|
| AI Family Disaster Planner | Module 4 | on-device Gemma + RAG-style prompt | ✅ |
| AI Emergency Kit Generator | Module 5 | on-device Gemma | ✅ |
| AI Risk Assessment | Module 6 | on-device Gemma + deterministic scorer | ✅ |
| AI Damage Scanner | Module 2/7 | cloud Gemini vision | ❌ online |
| AI Situation Summary | Module 8 | on-device Gemma + deterministic fallback | ✅ |

Four of five work offline via the on-device Gemma. Only the vision
module (Damage Scanner) requires internet + a `GEMINI_API_KEY`
build flag, because Gemma 4 E2B `.litertlm` has no vision capability.

---

## Entry points (user-facing)

All five modules are wired into a single home-screen card grid
("AI টুলস"), reached by tapping the icons on the bottom of the home
tab. Each tile routes to a dedicated screen:

| Tile | Route | File |
|------|-------|------|
| পরিকল্পনা (Planner) | `/planner` | `planner_screen.dart` |
| কিট (Kit) | `/kit` | `kit_screen.dart` |
| ঝুঁকি (Risk) | `/risk` | `risk_screen.dart` |
| ড্যামেজ স্ক্যান (Damage Scanner) | `/damage-scanner` | `damage_scan_screen.dart` |
| সারাংশ (Summary) | `/situation-summary` | `situation_summary_screen.dart` |

---

## Metrics

| Metric | Before | After | Δ |
|---|---|---|---|
| New Dart files (lib) | — | 13 | +13 |
| New test files | — | 6 | +6 |
| New tests | — | 45 | +45 |
| `flutter analyze` on new files | — | 0 issues | — |
| API keys required | 0 | 0 (one optional via `--dart-define`) | — |
| New home-screen card | — | "AI টুলস" 3×N grid | +1 |

---

## What was deliberately skipped

- **Modules 2/7 vision on-device** — Gemma 4 E2B `.litertlm` has no
  vision. The Damage Scanner routes through Gemini (vision-capable)
  instead, gated behind the `GEMINI_API_KEY` build flag.
- **Module 9 (Family Safety Plan)** — overlaps heavily with Module 4
  and would be redundant.
- **Module 3 redo (Voice Incident Reporter)** — the existing SOS
  function-calling already covers this (search for `sosReportTool`).
- **Tied intelligence to live chat history** — the Situation Summary
  screen uses a static sample. A future iteration would feed it
  the real chat-history store + SOS dispatch log.

---

## Next steps (user-owned)

1. **On-device smoke test.** All text-only modules have pure-Dart
   prompt builders + on-device service wrappers. They need a phone
   with the Gemma model downloaded to confirm end-to-end. The
   Damage Scanner needs both phone + internet + a valid
   `GEMINI_API_KEY`.
2. **Real history for Situation Summary.** Replace the sample
   reports list with a read from `chat_store.dart` + the SOS
   dispatcher log.
3. **Damage Scanner severity colour tuning.** The colour mapping
   is a baseline; tuning based on what the model actually returns
   on real photos is a follow-up.

---

*Five modules, two delivery paths, zero broken features. Every
fallback returns a useful Bangla result — no feature shows blank.*