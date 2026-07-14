# Contributing to Shongjog

> **For future maintainers and contributors.** How to set up a local dev environment,
> the codebase conventions, how to test, how to ship.

The project started as a 3-person hackathon build and grew into a deeper codebase. New
contributors are very welcome — please read this carefully before opening a PR.

---

## Table of contents

1. [Project context](#project-context)
2. [Architecture overview](#architecture-overview)
3. [Local dev setup](#local-dev-setup)
4. [Code conventions](#code-conventions)
5. [Testing policy](#testing-policy)
6. [Commit + PR conventions](#commit--pr-conventions)
7. [Bangla content policy](#bangla-content-policy)
8. [What NOT to change](#what-not-to-change)

---

## Project context

Shongjog (`শঙ্গ্যোগ`) is a Flutter app that delivers Bangladesh disaster-preparedness
guidance fully **offline**. It's designed for the moment when mobile data is down, the
grid is failing, and people need step-by-step emergency guidance in Bangla. The core
thesis is "it works when the internet doesn't."

Read `docs/prd.md` first — it explains the product. Then `docs/architecture.md` for the
technical shape and `docs/design.md` for visual / interaction conventions.

**Three ground rules:**

- **No internet in the core loop.** Every new feature must work in airplane mode, or be
  explicitly gated behind "online-only, no offline fallback = bug."
- **No medical advice that isn't traceable to a vetted source.** Everything in the
  knowledge base is paraphrased from WHO / BDRCS / MoDMR / CDC / IFRC — see
  `docs/corpus.md` §5.
- **User privacy is hard-line.** Voice, GPS, photos, chat content never leave the
  device. No analytics that ships any user content. No crash reporters that include
  query text.

---

## Architecture overview

```
lib/
├── app/                ← MaterialApp, theme, _StartupGate, MainShell (bottom nav)
├── core/               ← Cross-cutting singletons: modelManager, themeController
├── features/           ← Self-contained feature modules (chat, voice, shelter, …)
├── rag/                ← Retrieval core (retriever, keyword_retriever, prompt_builder)
└── knowledge/          ← KB loader (reads assets/kb/{corpus.json, vectors.bin})
assets/
├── kb/                 ← Build-time embedded corpus + vectors
├── shelter/            ← GeoJSON
├── fonts/              ← HindSiliguri
├── sound/              ← chime.wav, knock.wav
└── vosk/               ← Offline STT model (when ready)
tools/                  ← Python: build_kb.py, verify_kb.py, corpus.json, .venv/
test/
├── unit/               ← 9 files: pure-Dart correctness
├── widget/             ← 7 files: in-app UI behavior
└── integration_test/   ← Needs device (full app start → home → AI chat)
```

The dependency rule: `core/`, `rag/`, and pure parts of `features/` (search for
"pure" comments) import only `dart:*` and other internal modules. Adapter layers
(features that talk to plugins) depend on `core/` and `rag/`. The app (`app/`)
depends on everything.

Read `docs/architecture.md` §3 for the layered dependency diagram.

---

## Local dev setup

### 1. Install Flutter

```bash
# macOS / Linux
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"

flutter doctor
# All green is not required for offline development; you need:
#   - Flutter SDK ✓
#   - Android toolchain ✓
#   - Connected arm64 device for model-related work
```

### 2. Clone + bootstrap

```bash
git clone https://github.com/<your-org>/shongjog.git
cd shongjog
flutter pub get

# Verify clean state (no model / network needed)
flutter analyze                # → "No issues found!"
flutter test                   # → 91 pass, 1 skip
```

### 3. (Optional) Rebuild the KB from source

Only needed if you're changing `tools/corpus.json`:

```bash
cd tools
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 build_kb.py            # ~5 min on first run, downloads mpnet model

cd ..
python3 tools/verify_kb.py     # → all "OK"
```

### 4. (Optional) Run the app without the model

The app works without the Gemma model — quick cards, shelter list view, settings,
onboarding, voice prefs all work. The chat will fall back to keyword retrieval +
canned responses without the model.

```bash
flutter run -d <device-id>     # any device; arm64-v8a for full demo
```

### 5. Build for production

```bash
flutter build apk --release --target-platform android-arm64
flutter build appbundle --release
```

---

## Code conventions

### Style

We follow the `flutter_lints` default rules with these exceptions / additions:

- **File-level docstring** at the top of every module explaining purpose, owner, and
  related docs. See `lib/features/chat/chat_repository.dart` for a template.

- **One widget per file** in `lib/features/<name>/widgets/` if you have a sub-folder.
  Otherwise `lib/features/<name>/<widget>.dart` is fine.

- **No emojis in code unless the user-facing copy demands it.** We're a crisis-context
  app; restraint is a feature.

- **Pure functions for testability.** Anything that touches plugins / IO / global state
  lives in an "adapter" layer. Core logic (parsers, scoring, ranking, prompt assembly)
  is plain Dart and unit-tested.

- **Bangla numerals in user-facing strings.** `০-৯`, not `0-9`. Western numerals are
  fine in logs, debug overlay, and code identifiers.

- **Danda (`।`) for full stop in user-facing Bangla.** Not Latin period. Exception:
  inside `assert` strings or `FormatException` messages.

- **No comments in production code.** Per project policy, comments are removed from
  shipped code. Use clear naming instead. (Test files and tools/ are exempt.)

### Naming

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Methods: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Test files: `*_test.dart` under `test/unit/` or `test/widget/`

### Architecture patterns

- **Repositories** wrap external data sources (assets, plugins, network).
- **Stores** are JSON-based persistence helpers, owned per feature.
- **Services** are singleton adapters (Vosk, TTS, GPS, Sound). Pass user-controlled
  prefs via `setEnabled(...)` calls.
- **Stores and services should expose pure test seams.** `load` / `save` / `clear` —
  not just `init` and open-ended methods.

### The on-device model pattern

Anything that talks to `flutter_gemma` lives in `lib/core/model_manager.dart`.
**Do not create a second model API path.** All model access goes through
`modelManager.initialize()` and `modelManager.generate(prompt: ...)` (or, for streaming, `modelManager.modelStream(...)`).

---

## Testing policy

We have three test layers:

1. **`test/unit/`** — pure Dart, fast, no widget tree.
   - Required for any logic in `lib/rag/`, `lib/core/`, `lib/knowledge/`.
   - Run constantly in CI.

2. **`test/widget/`** — widget tests against the Flutter tree, no IO.
   - Required for any UI changes that have meaningful behavior.
   - Run in CI.

3. **`test/integration_test/`** and `integration_test/` — full app on device.
   - Required for release-blocking changes (model loading, voice, GPS, dial).
   - Run manually before any demo.

### Conventions

- **Test names state behavior, not implementation.** "topK returns highest cosine" beats
  "testTopK".

- **Group tests by file-by-feature, not one-file-per-test.** A single test file per
  module under `test/unit/`.

- **Widget tests: avoid `pumpAndSettle` with infinite animations.** Use `pump(Duration)`
  with explicit time advancement for typewriter / breathing-dot animations.

- **Mocking strategy.** Adopt-pure-Dart modules can be tested directly. Adapter modules
  that depend on plugins use no-op test doubles (`_NoOpModelManager`, `_NoOpSttService`)
  exported from the module under test.

- **Never ship a feature without tests.** A PR that adds a feature with no new tests
  must include reasoning in the PR body — otherwise it blocks until tests land.

### Running tests

```bash
flutter test                              # all tests
flutter test test/unit/                   # only unit
flutter test --coverage                   # with coverage
flutter test integration_test/...         # requires device
```

---

## Commit + PR conventions

### Commit prefix style

```
feat(<scope>): <imperative summary, present tense>
fix(<scope>): <imperative summary>
test(<scope>): <imperative summary>
docs(<scope>): <imperative summary>
build(<scope>): <imperative summary>
refactor(<scope>): <imperative summary>
chore: <imperative summary>
```

`<scope>` for this repo: `chat`, `voice`, `shelter`, `emergency`, `kb`, `rag`,
`settings`, `mesh`, `contacts`, `audio`, `home`, `about`, `onboarding`, `app`,
`core`, `tools`.

### Branch policy

- `main` — protected, only merged via PR
- `feat/<scope>` — for new features
- `fix/<scope>` — for bug fixes
- `docs/<scope>` — for docs-only

**No `git push --force` to `main`.** Rebase feature branches instead.

### PR body template

```markdown
## What
One paragraph: what changed and why.

## Why
Link the issue or design doc, or explain the motivation.

## How tested
- [ ] `flutter analyze` clean
- [ ] `flutter test` (n passed)
- [ ] Manual check on device (describe)

## Risk
Anything reviewers should pay extra attention to.

## Screenshots / recordings
If UX-relevant.
```

---

## Bangla content policy

If you're adding or changing Bangla copy in the app:

1. **Write plain Bangla first.** No jargon, no English loanwords where a Bangla word
   exists. Aim for Class 5 reading level.
2. **Numbered steps for sequential actions.** Bullets for non-sequential lists.
3. **Danda (`।`) as full stop.** Not Latin period.
4. **Bangla numerals (`০-৯`)** in user-facing text. Western digits only in logs and
   code identifiers.
5. **Never editorialize.** If a chunk paraphrases a public source (WHO, BDRCS,
   MoDMR), keep the source attribution in the `source` field.
6. **Have a native reviewer sign off before shipping.** Even small phrasing changes
   can change the medical interpretation.

For Bangla content in the corpus, see `docs/corpus.md` §4 (authoring checklist).

---

## What NOT to change

These are red lines for any contributor. If your PR violates one, it will be closed.

1. **Remove the arm64-v8a ABI restriction.** The model is arm64-only. Lifting this
   silently breaks the demo.

2. **Add network calls to the core chat loop.** The whole thesis is offline.

3. **Lower the cosine floor or remove canned fallbacks.** These prevent hallucinated
   medical advice. If a chunk is unhelpful, fix the corpus, not the gate.

4. **Add analytics that ship user content.** Voice, GPS, photos, chat content are
   device-local. Crash logs may be sent but must redact query text.

5. **Ship medical content from a non-whitelisted source.** WHO / BDRCS / MoDMR / BMD
   / CDC / IFRC only. See `docs/corpus.md` §5.

6. **Add an English-language path through the user UI.** The user surface is Bangla.
   English is for engineering docs and code comments only.

7. **Branch the model path.** All model access goes through `modelManager`. Don't
   create a second `FlutterGemma.instance.initialize(...)`.

8. **Auto-read aloud without opt-in.** TTS must be triggered by the user or by the
   `pref_auto_read` opt-in. Do not add startup-voice features that catch users off
   guard.

---

## Where to ask

- **Open a GitHub issue** with the `question` label.
- **Or email Ahnaf** (lead) — see `docs/team.md` for contact.
- **Or join the BDRCS integration channel** if you're a partner reviewer.

We respond within 48h on weekdays. Urgent demo-day questions get faster turnaround;
flag the issue with the `urgent-demo` label.
