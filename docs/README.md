# Shongjog — Documentation

> **Start here:** [`PROJECT-STATUS.md`](PROJECT-STATUS.md) — one-shot status
> report of everything done, everything blocking, and pointers to every other doc.

## Structure

```
docs/
├── PROJECT-STATUS.md       ← START HERE (v2 snapshot — see banner)
├── architecture.md         ← Technical architecture
├── kaggle-writeup.md       ← Hackathon submission writeup
├── prd.md                  ← Product requirements
├── design.md               ← UX/UI design system
├── CONTRIBUTING.md         ← Contributor guide
├── CHANGELOG.md            ← Changelog
├── README.md               ← this index
├── guides/                 ← Operational how-tos
└── screenshots/            ← App screenshots (28 images)
```

> The current, authoritative state lives in the **root [`README.md`](../README.md)**
> and [`kaggle-writeup.md`](kaggle-writeup.md).

---

## Core docs

| Doc | What it is |
|-----|-----------|
| [`PROJECT-STATUS.md`](PROJECT-STATUS.md) | Snapshot of project state — start here |
| [`architecture.md`](architecture.md) | Module boundaries, data flow, build pipeline, constraints |
| [`kaggle-writeup.md`](kaggle-writeup.md) | Hackathon submission writeup |
| [`prd.md`](prd.md) | Product requirements, success criteria, scope |
| [`design.md`](design.md) | UX/UI design system, tokens, accessibility |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Local dev setup, conventions, testing, PR flow |
| [`CHANGELOG.md`](CHANGELOG.md) | Keep-a-Changelog entries per milestone |

---

## guides/ — Operational How-Tos

| Doc | What it covers |
|-----|---------------|
| [`guides/demo.md`](guides/demo.md) | Demo runbook, story arc, fallback playbook, judge Q&A |
| [`guides/PRE-DEMO.md`](guides/PRE-DEMO.md) | Pre-demo operational checklist |
| [`guides/OFFLINE-MODEL-SETUP.md`](guides/OFFLINE-MODEL-SETUP.md) | On-device LLM setup from scratch (flutter_gemma 1.x + LiteRT-LM) |
| [`guides/corpus.md`](guides/corpus.md) | Knowledge base guide: topic coverage, chunk schema, source whitelist |
| [`guides/corpus-review.md`](guides/corpus-review.md) | Corpus expert review record |
| [`guides/ai_context.md`](guides/ai_context.md) | AI session anchor — tracks recent changes for future AI dev sessions |
