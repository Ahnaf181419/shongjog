# Shongjog — Team & Work Division

> **Internal team-facing document.** Roles, per-person deliverable checklists, branch
> conventions, integration checkpoints, and async coordination rules for a 3-person
> team on a ~7-day hackathon build.

Companion docs: product scope in `docs/prd.md`; build tasks in
`docs/implementation-plan.md`; architecture in `docs/architecture.md`.

---

## 1. Roles

**Principle:** Ahnaf owns everything critical-path and tough (including the skeleton UI
that unblocks the team). Maruf and Sehab own only simple, well-specified tasks they can
build on top of Ahnaf's skeleton — fully in parallel, never blocking him.

| Person | Role | Owns | Why |
|---|---|---|---|
| **Ahnaf (Lead)** | Critical path + tough integration + skeleton UI | Phase 0 spike, Phase 1.1 scaffolding, **Phase 1.2 skeleton UI** (theme + routing), Phase 2.4 KB loader, Phase 3.1–3.4 (model manager, embedder, prompt builder, ChatRepository, chat UI, TTS), Phase 4.1 Vosk STT, Phase 4.2 shelter map, Phase 5 demo hardening, Bangla review, all merges | Every risky seam + the foundation; determines viability |
| **Maruf** | Simple UI features on the skeleton | Phase 1.3 static quick cards, Phase 4.3 nearest-shelter haversine + list, emergency hub screen, widget tests, app icon/splash | Self-contained screens with no model dependency; pure UI + one pure-math module |
| **Sehab** | Simple content + small code | Phase 2.1 corpus authoring, Phase 2.2 `build_kb.py`, Phase 2.3 `verify_kb.py`, Phase 4.4 emergency dial, Phase 4.5 SOS SMS template, about/sources page | Content lift + typed-from-spec scripts + tiny Flutter utilities |

**Skill profile:** Maruf and Sehab are both Flutter-comfortable and can read the
implementation plan without hand-holding.

**Bangla review:** only Ahnaf reviews/edits final Bangla. Sehab drafts the corpus; Ahnaf
edits and signs off before `build_kb.py` runs.

**Hardware:** all three have their own arm64 Android device for on-device testing.

**Risk note:** Ahnaf's plate is intentionally heavy. This works because Maruf's and
Sehab's tasks are decoupled from the model and from each other — they never block him, and
they need little review. If Ahnaf falls behind on the critical path, the teammates keep
shipping their simple slices and Ahnaf integrates at the next IC.

---

## 2. Per-Person Deliverable Checklist

Done-criteria are explicit so slices ship without ambiguity. Reference
`docs/implementation-plan.md` tasks by ID.

### Ahnaf (critical path + skeleton + tough integration)

| Task | Done when |
|---|---|
| Phase 0.1 spike A (Gemma) | `docs/spike-results.md` records cold start, RAM, Bangla sample, verdict 🟢/🟡/🔴 |
| Phase 0.2 spike B (Vosk) | `docs/spike-results.md` records WER per utterance, verdict |
| Phase 0.3 spike C (shelter) | `assets/shelter/cyclone_shelters.geojson` committed, 5 shelters spot-checked |
| **Phase 1.1 + 1.2 scaffolding + skeleton UI** | `flutter pub get` + `flutter analyze` clean; theme applied; routes resolve to placeholder screens; AppBar nav present. **This is the IC-1 unblock.** |
| Phase 2.4 KB loader | `KnowledgeBase.load()` works; `retriever_test.dart` green |
| Phase 3.1 model manager | `ModelManager.ensureModel()` + `initialize()` run on device; download progress in UI |
| Phase 3.2 prompt builder + ChatRepository | `prompt_builder_test.dart` green; `ChatRepository.ask()` returns grounded answer in airplane mode |
| Phase 3.3 embedder | `Embedder.embed()` returns 768-dim `Float32List` on device |
| Phase 3.4 chat UI + TTS | Spoken Bangla query → grounded spoken answer; cold-start splash; TTS in `bn-BD` |
| Phase 4.1 Vosk STT | Mic → transcript → auto-submit works on device in airplane mode |
| Phase 4.2 shelter map | `flutter_map` renders bundled GeoJSON markers; offline tiles load; GPS centers map |
| Phase 5.1 airplane-mode E2E | 5 scenarios pass, timings recorded |
| Phase 5.2 cold-start polish | "AI প্রস্তুত হচ্ছে..." overlay + quick-cards fallback link |
| Phase 5.3 fallback video | 60s video on demo device, playable offline |

**Ahnaf also owns:** all merges into `main`, `pubspec.yaml`, Bangla review of Sehab's
corpus, and final integration of Maruf's and Sehab's slices.

### Maruf — Simple UI features (branch `feat/quick-cards` → `feat/shelter-ui`)

| Task | Done when |
|---|---|
| Phase 1.3 static quick cards | 6 cards render with Bangla text; `quick_cards_screen_test.dart` green; expansion works |
| Phase 4.3 nearest-shelter haversine + list | `nearest_shelter_test.dart` green; a list widget shows top-3 shelters sorted by km from a hardcoded GPS (Ahnaf wires real GPS later) |
| Emergency hub screen | A landing with 3 big tappable tiles (জরুরি কার্ড / নিকটস্থ আশ্রয়কেন্দ্র / ৯৯৯ কল) that navigate to the right routes |
| Widget tests | One widget test per screen Maruf owns; all green |
| App icon + splash | App icon generated and wired; splash screen shows on cold start |

**Owns:** `lib/features/quick_cards/`, `lib/features/shelter/nearest_shelter.dart` + the
list widget (not the map screen — that's Ahnaf's), the emergency hub screen, app icon
assets.

**Ping Ahnaf when:** (a) `git pull` from `main` breaks your build; (b) a route you need
to navigate to doesn't exist yet in `router.dart`.

### Sehab — Simple content + small code (branch `feat/corpus-pipeline` → `feat/emergency-actions`)

| Task | Done when | Status |
|---|---|---|
| Phase 2.1 corpus authoring | `tools/corpus.json` has 23 chunks across all required topics; every chunk has source attribution; draft-quality Bangla (Ahnaf edits) | ✅ DONE |
| Phase 2.2 `build_kb.py` | Script runs locally; produces `assets/kb/corpus.json` + `vectors.bin`; dimensions `[N, 768]` | ❌ Ahnaf owns |
| Phase 2.3 `verify_kb.py` | 7 test queries return correct topic; no `BAD` lines in output | ❌ Ahnaf owns |
| Phase 4.4 emergency dial | 999 tap opens dialer on device | ✅ DONE |
| Phase 4.5 SOS SMS template | `sos_sms_template_test.dart` green; SMS body contains name + phone + coords | ✅ DONE |
| About / sources page | A static screen listing all corpus sources (WHO, BDRCS, MoDMR, CDC) with a one-line credit each | ✅ DONE |

**Sehab deliverables complete.** Waiting on Ahnaf for build pipeline (Phase 2.2-2.3) and IC-2 integration.

**Owns:** `tools/corpus.json`, `tools/build_kb.py`, `tools/verify_kb.py`,
`lib/features/emergency/`, the about/sources screen.

**Ping Ahnaf when:** (a) a corpus source URL is inaccessible; (b) a Bangla medical term
is unclear — drop a `// REVIEW: <question>` comment in `corpus.json` and move on; Ahnaf
does all editorial review.

---

## 3. Branch Conventions

- **`main`** is the integration branch. Only Ahnaf merges into `main`.
- **Feature branches:** `feat/<scope>` — e.g. `feat/quick-cards`, `feat/shelter-ui`,
  `feat/corpus-pipeline`, `feat/emergency-actions`.
- **Branch lifecycle:** create from `main`, rebase onto latest `main` before merge, delete
  after merge.
- **`pubspec.yaml` is Ahnaf's.** Anyone who needs a new dependency pings Ahnaf to add it
  — avoids merge conflicts on the manifest.
- **Commit messages:** conventional prefix + short imperative summary —
  `feat(chat): wired RAG + gemma`, `fix(shelter): haversine unit`, `docs(corpus): ...`.
- **Commit cadence:** small, frequent commits on feature branches. Don't accumulate a
  week of work in one commit.

---

## 4. Integration Checkpoints

Three hard checkpoints force a merge so the team doesn't drift. Ahnaf drives these
merges; Maruf and Sehab push to their branches before the checkpoint.

| Checkpoint | When | What merges into `main` |
|---|---|---|
| **IC-1** | End of Day 1 | **Ahnaf's skeleton UI** — scaffolding (pubspec, manifest, arm64 filter) + theme + router + placeholder screens + AppBar nav. **Unblocks Maruf and Sehab** — they can `flutter pub get`, run, and start building screens on real routes. |
| **IC-2** | End of Day 3 | Maruf's quick cards (Phase 1.3); Sehab's `corpus.json` (Phase 2.1) + `build_kb.py` (Phase 2.2) + `verify_kb.py` (Phase 2.3); Ahnaf's KB loader (Phase 2.4). |
| **IC-3** | End of Day 5 | Maruf's nearest-shelter list (Phase 4.3) + emergency hub; Sehab's emergency dial (Phase 4.4) + SOS SMS (Phase 4.5) + about page; Ahnaf's full Gemma integration + chat UI + TTS (Phase 3.x) + Vosk STT (Phase 4.1) + shelter map (Phase 4.2). |

After IC-3, Days 6–7 are Ahnaf-led integration, bug fixing, and demo hardening (Phase 5).
Maruf and Sehab fix bugs on their owned features.

---

## 5. Coordination Rules (async + chat-when-blocked)

The team coordinates **async by default** — no standing daily meeting. To prevent
late-discovered conflicts:

1. **Contract files first.** Ahnaf posts the skeleton's route names and screen signatures
   in the team chat at IC-1 (e.g. `AppRoutes.quickCards`, `Widget QuickCardsScreen()`).
   Maruf and Sehab code against those contracts, not against Ahnaf's in-progress code.
2. **Push at end of day.** Everyone pushes their feature branch daily, even if WIP. Ahnaf
   can spot integration conflicts early.
3. **Ping when blocked, not when curious.** Blockers: build broken after `git pull`,
   missing dependency, unclear task scope, Bangla phrasing question. Non-blockers: read
   the docs and proceed.
4. **One device, one model version.** All three devices use the **same** Gemma 4 E2B
   `.task` file. Ahnaf shares it via a cloud link once; everyone downloads from there.
   Inconsistent model versions = inconsistent answers = bad demo.
5. **Screenshots for UI questions.** If anyone is unsure about a visual choice, they post
   a screenshot in chat rather than describing it in words.

---

## 6. Suggested Day-by-Day Schedule

| Day | Ahnaf | Maruf | Sehab |
|---|---|---|---|
| **Day 1** | Phase 0 spike (all 3); Phase 1.1 + 1.2 skeleton UI → **IC-1** | Read docs; set up local env; review plan | Read docs; begin Phase 2.1 corpus drafting |
| **Day 2** | Phase 2.4 KB loader; Phase 3.1 model manager | Phase 1.3 quick cards | Continue corpus; Ahnaf reviews drafts |
| **Day 3** | Phase 3.2 prompt builder + ChatRepository; Phase 3.3 embedder → **IC-2** | Phase 4.3 nearest-shelter haversine + list | Phase 2.2 `build_kb.py`; Phase 2.3 `verify_kb.py` |
| **Day 4** | Phase 3.4 chat UI + TTS; integrate Maruf's cards + Sehab's KB | Emergency hub screen; app icon/splash | Phase 4.4 dial; Phase 4.5 SOS SMS |
| **Day 5** | Phase 4.1 Vosk STT; Phase 4.2 shelter map; integrate all → **IC-3** | Widget tests; polish owned screens | About/sources page; polish owned screens |
| **Day 6** | Phase 5.1 airplane-mode E2E; Phase 5.2 cold-start polish | Fix bugs; manual testing of owned screens | Fix bugs; manual testing of owned screens |
| **Day 7** | Phase 5.3 fallback video; dry-run demo; buffer | Support demo prep | Support demo prep |

---

## 7. Asset & Resource Sharing

| Asset | Owner | Sharing |
|---|---|---|
| Gemma 4 E2B `.task` file (~1.5GB) | Ahnaf | Cloud link shared once; everyone downloads to their device |
| Vosk Bangla model (~50MB) | Ahnaf | Bundled in repo under `assets/vosk/` after Phase 0 spike B |
| Shelter GeoJSON | Ahnaf (sources it in Phase 0 spike C) | Bundled in repo under `assets/shelter/` |
| Corpus (`tools/corpus.json`) | Sehab (drafts), Ahnaf (edits) | In repo; version-stamped |
| Demo phone (primary) | Ahnaf | Pre-loaded with model; charged ≥ 80% before event |

---

## 8. Task Difficulty Map (why it's split this way)

For transparency, here's how the tasks rank by difficulty/risk and who owns each:

| Task | Difficulty | Owner |
|---|---|---|
| Phase 0.1 spike A (Gemma on arm64) | 🔴 Critical / risky | Ahnaf |
| Phase 3.1–3.4 (Gemma integration: manager, embedder, RAG, chat, TTS) | 🔴 Critical / risky | Ahnaf |
| Phase 4.1 Vosk STT integration | 🔴 Critical / risky | Ahnaf |
| Phase 4.2 shelter map + offline tiles | 🟠 Tough | Ahnaf |
| Phase 0.2 spike B (Vosk WER) | 🟠 Tough | Ahnaf |
| Phase 2.4 KB loader + retriever | 🟠 Tough | Ahnaf |
| Phase 0.3 spike C (GeoJSON source) | 🟡 Medium | Ahnaf |
| Phase 2.2 `build_kb.py` | 🟡 Medium (typed from spec) | Sehab |
| Phase 2.3 `verify_kb.py` | 🟡 Medium (typed from spec) | Sehab |
| Phase 2.1 corpus authoring (23 Bangla chunks) | 🟡 Medium (content, Ahnaf edits) | Sehab |
| Phase 1.2 skeleton UI (theme + routing) | 🟡 Medium | Ahnaf |
| Phase 1.3 static quick cards | 🟢 Simple | Maruf |
| Phase 4.3 nearest-shelter haversine + list | 🟢 Simple (pure math + list) | Maruf |
| Phase 4.4 emergency dial | 🟢 Simple (one-liner) | Sehab |
| Phase 4.5 SOS SMS template | 🟢 Simple (string + test) | Sehab |
| Emergency hub screen | 🟢 Simple (navigation tiles) | Maruf |
| About / sources page | 🟢 Simple (static list) | Sehab |
| Widget tests, app icon, splash | 🟢 Simple | Maruf |

---

## 9. Decision Log (append-only)

Append significant decisions here as they happen, so the team has a shared record.

| Date | Decision | Rationale |
|---|---|---|
| Day 0 | Scope: must-haves + voice-in + shelter map + SOS | Full should-have set chosen for demo impact |
| Day 0 | STT: Vosk-Bangla bundled, not Google STT | True offline required for the thesis |
| Day 0 | KB: build-time embedded, not lazy download | No first-run network step in a disaster |
| Day 0 | Architecture: feature-first, light seams | Fast to build, easy to demo; no full clean-arch |
| Day 0 | Retrieval: brute-force cosine, not HNSW | N≈23 vectors; brute force is faster and simpler |
| Day 0 | Demo: live airplane-mode + 60s prerecorded fallback | Hedge against live-demo flakiness |
| Day 0 | Roles: Ahnaf (Lead/critical path), Maruf (UI/Map), Sehab (Content/Data) | Skill fit; Ahnaf owns Bangla review |
| Day 1 | Redistribution: Ahnaf owns all critical + tough + skeleton UI; Maruf & Sehab own only simple tasks | Concentrate risk on the lead; keep teammates unblocked with self-contained simple slices |
| Day X | Sehab corpus authoring complete: 23 chunks across 10 topics | tools/corpus.json ready for Ahnaf review + build pipeline |
| Day X | Sehab emergency features complete: dial, SOS SMS, about page | All Phase 4.4, 4.5, and about tasks done |
| Day X | Quick cards text contrast fix: added ShongjogTheme.ink color | Readability fix — dark text on white card background |
| _ | _ | _(add rows as decisions are made)_ |
