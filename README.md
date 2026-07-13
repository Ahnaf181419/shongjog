# Shongjog

**An on-device, Bangla, voice-first flood/cyclone emergency companion powered by Gemma 4
— it works when the internet doesn't.**

Built for the *Build with Gemma 4: ML, AI, Deep Learning & NLP Community Hackathon*
(Bangladesh). Flutter app, Gemma 4 E2B running fully on-device, RAG over a verified
Bangla corpus, Vosk-Bangla speech-to-text, and offline maps. The entire core loop runs in
airplane mode.

> The single sentence that defines this project: **it works when the internet doesn't.**

## Documentation

All project docs live in [`docs/`](./docs). Start there.

| Doc | What it covers |
|---|---|
| [`docs/prd.md`](./docs/prd.md) | Product requirements — problem, scope, success criteria, risks |
| [`docs/architecture.md`](./docs/architecture.md) | Technical architecture — stack, pipeline, data model, constraints |
| [`docs/design.md`](./docs/design.md) | UX/UI design — principles, personas, flows, visual system, accessibility |
| [`docs/team.md`](./docs/team.md) | Work division — roles, per-person checklist, integration checkpoints |
| [`docs/corpus.md`](./docs/corpus.md) | Knowledge base — topic coverage, schema, authoring guide, source policy |
| [`docs/demo.md`](./docs/demo.md) | Demo runbook — live script, pre-demo checklist, fallback, judge Q&A |
| [`docs/implementation-plan.md`](./docs/implementation-plan.md) | Task-by-task build plan (Phase 0 → Phase 5) |

## Quick Start

```bash
flutter pub get
flutter analyze
flutter run -d <arm64-device-id> --release
```

> **Note:** `.litertlm` inference is `arm64-v8a` only. A standard x86 emulator will not
> run the model — test on a real arm64 Android device. The Android build is restricted
> via `abiFilters 'arm64-v8a'` in `android/app/build.gradle.kts`.

## Status

Pre-implementation. Phase 0 validation spike is the next step — see
[`docs/implementation-plan.md`](./docs/implementation-plan.md).
