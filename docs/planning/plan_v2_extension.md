# Shonjog — 10-Day Extension Plan (v2)

**Status:** MVP complete. On-device Gemma 4 E2B + RAG + Bangla voice I/O + shelter locator + SOS all working offline.

**New goal:** Move from *"we built a working prototype"* to *"we built a validated, measurably safe, fine-tuned system that real users tested."*

---

## 0. The Strategic Shift

With one day, shipping *is* the achievement. With eleven, it isn't — most serious teams will have something working. The rubric weights don't change, but what **maxes them out** does:

| Criterion | 1-day bar | 11-day bar |
|---|---|---|
| Gemma Integration (30%) | Gemma runs on-device | Gemma is **fine-tuned by us** for Bangla emergency triage, with before/after numbers |
| Innovation & Impact (20–30%) | "This could help millions" | "We tested it with N real users; here's what they said" |
| Functionality (20%) | The demo works | It works **on low-end phones**, measured, with latency and accuracy data |
| Presentation (20%) | A good story | A story backed by **charts and evals** |

**The three highest-leverage additions, in order:**
1. **Fine-tune Gemma 4 E2B (LoRA)** — the single strongest differentiator available. Gemma is Apache 2.0 and open; almost no hackathon team fine-tunes. This is only possible *because* it's Gemma.
2. **Build an evaluation harness** — turns safety claims into measured facts. Judges reward evidence over adjectives.
3. **Field-test with real users** — converts "Real-world Impact" from a hypothesis into a finding.

Everything else is secondary. Resist adding features; depth beats breadth from here.

---

## 1. Priority Workstreams

### P0 — Fine-tuning Gemma 4 E2B for Bangla emergency triage
**Why:** Your on-device model is small. Out of the box it will occasionally drift into English, over-explain, bury the action step, or adopt a clinical register a panicking parent can't parse. Fine-tuning fixes exactly this — and it's a Gemma-only capability.

**What to do:**
- Build a supervised dataset of **150–400 examples**: `(Bangla emergency query + retrieved context) → ideal grounded Bangla answer`.
  - Cover the corpus domains: ORS/diarrhea, safe water, snakebite, drowning, wound care, electrical safety, evacuation, pregnancy/infant/elderly care.
  - Include **hard negatives**: myth-laden queries ("should I cut the snakebite?"), out-of-scope queries (the model must say "I don't know, call 999"), and low-context retrievals.
  - Enforce a consistent output shape: short, numbered steps → warning signs → "call 999 if X".
- Train **LoRA on Gemma 4 E2B** in Google Colab (a free/cheap T4 or an A100 hour is plenty at this size).
- Export the adapter and load it on-device — `flutter_gemma` supports LoRA weights alongside the base model.
- **Measure before vs. after** on a held-out set. This table is your writeup's centerpiece.

**Guard against:** overfitting on a tiny dataset, and degrading the model's refusal behavior. Keep the eval set untouched.

---

### P0 — Evaluation harness (your credibility engine)
**Why:** You are shipping medical-adjacent guidance from a 2B model. "We used RAG so it's safe" is a claim. Numbers make it a finding — and show engineering maturity.

**Build a held-out test set of ~50–80 Bangla queries** and measure:
- **Retrieval accuracy** — did the correct chunk make top-k? (report recall@1, recall@3)
- **Groundedness** — is every claim in the answer traceable to retrieved context? (manual rubric, 2 reviewers)
- **Safety refusals** — does it correctly decline out-of-scope/diagnostic questions?
- **Myth resistance** — does it correct dangerous folk beliefs rather than affirm them?
- **Language fidelity** — does it stay in simple Bangla without English drift?
- **Latency** — time-to-first-token and full-answer time, **per device tier**.

Report base model vs. fine-tuned. Ship the harness in the repo — a reproducible eval script is a strong repo signal on its own.

---

### P0 — Device performance matrix
**Why:** Your users are not on Pixels. If it only runs on a flagship, the impact story collapses — and a judge may well ask.

Test on **3–4 real phones across tiers** (e.g. a 4GB budget device, a 6GB midrange, a flagship). Record per device:
- Cold start / model load time
- Time-to-first-token, tokens/sec
- Peak RAM, OOM behavior
- Battery drain per query
- Thermal throttling on sustained use

Then **tune to the floor, not the ceiling**: pick quantization, `maxTokens`, and CPU/GPU backend so the *budget* phone is usable. Consider an automatic model-tier fallback (E2B → Gemma 3 1B) on constrained devices. A table of "runs acceptably on a ৳12,000 phone" is worth more than any feature.

---

### P1 — Corpus expansion + expert review
- Grow from ~20 to **40–60 chunks**; add heat/cold exposure, mental-health first aid, livestock/water contamination, post-flood mold and hygiene, document recovery.
- **Get a human expert to review it** — a physician, a public-health student, a BDRCS volunteer, or a faculty member at Southeast University. Even one reviewer, named and credited (with permission), transforms your safety claim.
- Add explicit source attribution per chunk in the UI ("Source: WHO / BDRCS") so users and judges can see the provenance.

---

### P1 — Field validation with real users
**Why:** This is what almost nobody does, and it's 20–30% of the score.

- Test with **8–15 people** — ideally including someone from a flood-affected area, an elderly user, and a low-literacy user. Campus staff, family, neighbours all count.
- Give each 3 realistic scenarios. Observe silently. Record:
  - Could they complete the task without help?
  - Did the voice input understand their accent/dialect?
  - Did they *trust* and *understand* the answer? Ask them to re-explain it back.
  - Time to first useful answer.
- Write up **what broke and what you changed**. Findings that contradicted your assumptions are the most compelling material you can put in a writeup — they prove you actually left the building.

---

### P1 — Multimodal triage (the biggest unused Gemma capability)
Gemma 4 E2B has **native vision and audio**. You're currently using a fraction of the model.

- **Vision:** photograph a wound (infection signs), a snake (broad venomous/non-venomous caution guidance), or floodwater. Frame it carefully: **visual assessment support, never identification-as-diagnosis** — always route toward "seek help."
- **Audio:** try Gemma's native audio input as an STT alternative — potentially better on Bangla dialects than the device STT, and it collapses two models into one.

Scope this **only if P0 is genuinely complete**. A shaky vision feature is worse than none.

---

### P2 — Robustness & polish
- Graceful degradation everywhere: model missing, GPS off, no permissions, low battery, storage full.
- **Battery-saver mode** — critical in a real disaster; consider a shorter-answer mode.
- Accessibility: large text, high contrast (wet screens, bright sun, panic), one-handed reach.
- First-run experience: the 1.5GB download must be explained honestly — WiFi-only option, resumable, "download before flood season" framing.
- Crash-free run of the full demo path 10× in a row.

---

## 2. Day-by-Day Schedule

**Days 1–2 — Foundation for measurement**
- Freeze features. Write the eval test set (50–80 queries) *before* touching the model — no fitting to the test.
- Run baseline evals on the current build. Record every number.
- Start the device matrix; borrow a budget phone today.

**Days 3–5 — Fine-tuning**
- Day 3: build the SFT dataset (150–400 examples). This is the bottleneck — parallelize across the team.
- Day 4: LoRA train on Colab; iterate on hyperparameters; sanity-check outputs.
- Day 5: export adapter, load on-device via `flutter_gemma`, re-run the **full eval suite**. Produce the before/after table.

**Days 4–6 — In parallel: corpus + expert review**
- Expand corpus, embed, rebuild the index, re-run retrieval evals.
- Send to your reviewer early — humans are slow; don't block on Day 9.

**Days 6–7 — Field testing**
- Run 8–15 user sessions. Take notes, not vibes.
- Triage findings into: fix now / document as future work.

**Day 8 — Fix + (optionally) multimodal**
- Ship the top 3 field-test fixes.
- If and only if P0 is done: add vision triage.

**Day 9 — Freeze, harden, measure**
- **Code freeze.** No new features.
- Full regression on all devices. 10× clean demo runs.
- Final eval numbers, final charts.

**Day 10 — Ship**
- Record the demo video (airplane mode, real Bangla query, real phone).
- Finalize the ≤1,500-word Kaggle writeup.
- Repo hygiene: README, deps, config, eval scripts, LoRA training notebook, license.
- Submit on Kaggle → **then fill the Google form**.

> **Rule:** Days 9–10 are non-negotiable. Teams lose on submission quality, not code quality. Protect this buffer.

---

## 3. Updated Writeup Structure (≤1,500 words)

The extension earns you three new sections that most submissions won't have:

1. Problem & why it matters
2. Solution overview
3. **Gemma 4 integration — including our LoRA fine-tune** ← upgraded
4. Architecture
5. **Evaluation: base vs. fine-tuned, with numbers** ← NEW, high value
6. **Device performance across phone tiers** ← NEW, proves real-world reach
7. **Field testing: what we learned from N real users** ← NEW, proves impact
8. Safety, grounding, and expert review
9. Challenges & future work

Lead the demo video with airplane mode. Lead the writeup with the eval table.

---

## 4. What NOT to Do With 10 Extra Days

- **Don't add features.** Feature count is not a rubric criterion. A broad, shallow app loses to a narrow, proven one.
- **Don't rebuild the architecture.** It works. Optimize inside it.
- **Don't chase a hosted/cloud version.** It contradicts the entire thesis.
- **Don't skip the eval set discipline.** Writing tests after you've seen the model's behavior makes them worthless.
- **Don't leave the writeup for the last night.** It's 20% of the score and the only thing every judge definitely reads.

---

## 5. Definition of Done

- [ ] Fine-tuned LoRA adapter running on-device, with a before/after eval table
- [ ] Reproducible eval harness in the repo, ~50–80 held-out Bangla queries
- [ ] Performance matrix across 3–4 real devices, tuned so a budget phone is usable
- [ ] Corpus at 40–60 chunks, reviewed by a named human expert
- [ ] Field-test findings from 8–15 real users, with documented fixes
- [ ] Airplane-mode demo video on a real phone, plus a backup recording
- [ ] Writeup ≤1,500 words, public repo, Kaggle submitted, Google form filed
