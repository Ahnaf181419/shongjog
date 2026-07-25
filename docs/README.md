# Shongjog — Documentation

> **Start here:** [`PROJECT-STATUS.md`](PROJECT-STATUS.md) — one-shot status
> report of everything done, everything blocking, and pointers to every other doc.

## Structure

```
docs/
├── PROJECT-STATUS.md       ← START HERE
├── architecture.md         ← Technical architecture
├── prd.md                  ← Product requirements
├── ai_context.md           ← AI session anchor (change log)
├── spike-results.md        ← On-device measurements (judge Q&A)
│
├── guides/                 ← Operational how-tos
├── planning/               ← Active roadmaps & plans
├── features/               ← Feature specs & proposals
├── audits/                 ← Historical code reviews
├── changelogs/             ← Historical upgrade summaries
├── specs/                  ← Design specs
└── archive/                ← Completed/superseded docs
```

---

## Entry Points

| Doc | What it is |
|-----|-----------|
| [`PROJECT-STATUS.md`](PROJECT-STATUS.md) | Snapshot of project state — start here |
| [`architecture.md`](architecture.md) | Module boundaries, data flow, build pipeline, constraints |
| [`prd.md`](prd.md) | Product requirements, success criteria, scope |

---

## guides/ — Operational How-Tos

| Doc | What it covers |
|-----|---------------|
| [`guides/demo.md`](guides/demo.md) | Demo runbook, story arc, fallback playbook, judge Q&A |
| [`guides/PRE-DEMO.md`](guides/PRE-DEMO.md) | Pre-demo operational checklist |
| [`guides/OFFLINE-MODEL-SETUP.md`](guides/OFFLINE-MODEL-SETUP.md) | On-device LLM setup from scratch (flutter_gemma 1.x + LiteRT-LM) |
| [`guides/corpus.md`](guides/corpus.md) | Knowledge base guide: topic coverage, chunk schema, source whitelist |
| [`guides/corpus-review.md`](guides/corpus-review.md) | Corpus expert review record |

---

## planning/ — Active Roadmaps & Plans

| Doc | What it covers |
|-----|---------------|
| [`planning/v3.md`](planning/v3.md) | AI Disaster Copilot v3 blueprint |
| [`planning/ROADMAP-v2.md`](planning/ROADMAP-v2.md) | Comprehensive v2 implementation roadmap |
| [`planning/plan_v2_extension.md`](planning/plan_v2_extension.md) | 10-day v2 extension plan |
| [`planning/POST-HACKATHON.md`](planning/POST-HACKATHON.md) | Post-hackathon roadmap: debt, expansion, deployment |
| [`planning/HACKATHON-WIN-PLAN.md`](planning/HACKATHON-WIN-PLAN.md) | 5-day hackathon standout plan |
| [`planning/firebase-backend-plan.md`](planning/firebase-backend-plan.md) | Firebase backend integration plan |

---

## features/ — Feature Specs & Proposals

| Doc | What it covers |
|-----|---------------|
| [`features/AI-FIRST-FEATURES.md`](features/AI-FIRST-FEATURES.md) | AI-first feature expansion plan |
| [`features/AI-MAP-FEATURES.md`](features/AI-MAP-FEATURES.md) | AI-on-the-map feature plan |
| [`features/ai_feature_candidates.md`](features/ai_feature_candidates.md) | AI feature candidates exploiting Gemma 4 capabilities |

---

## audits/ — Historical Code Reviews

| Doc | What it covers |
|-----|---------------|
| [`audits/AUDIT-2026-07-16.md`](audits/AUDIT-2026-07-16.md) | Full project audit (2026-07-16) |
| [`audits/AUDIT_REVIEW_2026-07-25.md`](audits/AUDIT_REVIEW_2026-07-25.md) | Full project audit (2026-07-25), 7.5/10 rating |
| [`audits/AUDIT_SEHAB_MERGE_2026-07-25.md`](audits/AUDIT_SEHAB_MERGE_2026-07-25.md) | Sehab merge verification audit |
| [`audits/V3-AI-TOOLS-VERIFICATION-2026-07-25.md`](audits/V3-AI-TOOLS-VERIFICATION-2026-07-25.md) | V3 AI tools functional verification |

---

## changelogs/ — Historical Upgrade Summaries

| Doc | What it covers |
|-----|---------------|
| [`changelogs/UPGRADE-SUMMARY-2026-07-18.md`](changelogs/UPGRADE-SUMMARY-2026-07-18.md) | v2 upgrade: 11 TDD-driven improvement rounds |
| [`changelogs/UPGRADE-SUMMARY-2026-07-24-free-apis.md`](changelogs/UPGRADE-SUMMARY-2026-07-24-free-apis.md) | Free-APIs integration: 5 key-less services |
| [`changelogs/UPGRADE-SUMMARY-2026-07-24-ai-map.md`](changelogs/UPGRADE-SUMMARY-2026-07-24-ai-map.md) | AI-augmented map: 4 AI-on-the-map features |
| [`changelogs/UPGRADE-SUMMARY-2026-07-25-admin-grid.md`](changelogs/UPGRADE-SUMMARY-2026-07-25-admin-grid.md) | Admin grid redesign: 4-tab to single-page dashboard |
| [`changelogs/UPGRADE-SUMMARY-2026-07-25-ai-first.md`](changelogs/UPGRADE-SUMMARY-2026-07-25-ai-first.md) | AI-first features: 5 modules wired to home screen |

---

## specs/ — Design Specs

| Doc | What it covers |
|-----|---------------|
| [`specs/2026-07-17-profile-and-voice-call-design.md`](specs/2026-07-17-profile-and-voice-call-design.md) | Profile + voice-call mesh hardening spec |
| [`specs/2026-07-24-mvp-i18n-design.md`](specs/2026-07-24-mvp-i18n-design.md) | MVP i18n design: Bangla/English toggle |

---

## archive/ — Completed/Superseded Docs

Historical documents from earlier build phases. Preserved for reference.

| Doc | What it covers |
|-----|---------------|
| [`archive/README.md`](archive/README.md) | Archive index |
| [`archive/implementation-plan.md`](archive/implementation-plan.md) | Original 2,584-line build plan (all tasks executed) |
| [`archive/design.md`](archive/design.md) | UX/UI design document |
| [`archive/team.md`](archive/team.md) | Team division and branch conventions |
| [`archive/IMPLAN.md`](archive/IMPLAN.md) | Multi-tier AI system implementation plan |
| [`archive/AUDIT-2026-07-15.md`](archive/AUDIT-2026-07-15.md) | Code audit (2026-07-15) |
| [`archive/superpowers/plans/2026-07-14-corpus-authoring.md`](archive/superpowers/plans/2026-07-14-corpus-authoring.md) | Corpus authoring implementation plan |

---

## Root Files

| Doc | What it covers |
|-----|---------------|
| [`ai_context.md`](ai_context.md) | AI session anchor — tracks recent changes for future AI dev sessions |
| [`spike-results.md`](spike-results.md) | On-device spike results and measurements (judge Q&A reference) |
