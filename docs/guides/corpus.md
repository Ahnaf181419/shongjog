# Shongjog — Knowledge Base (Corpus) Guide

> **Internal team-facing document.** Why we have a curated corpus, the topic coverage
> matrix, chunk schema, authoring checklist, source whitelist, and review process.

This document governs `tools/corpus.json` — the source of truth for everything Gemma
answers with. **A 2B on-device model must never freelance medical advice.** Every answer
is grounded in this corpus, and every chunk in this corpus is attributable to a public,
authoritative source.

Companion docs: architecture in `docs/architecture.md` (§Build Pipeline).

---

## 1. Why a Small, Sourced Corpus

Three reasons, in order of importance:

1. **Safety.** Hallucinated medical advice in a disaster can kill. Grounding Gemma in a
   small, vetted corpus bounds what it can say. If a query has no good retrieval hit, the
   app says so and points to 999 — it never guesses.
2. **Attribution.** Every chunk carries a source (WHO, BDRCS, MoDMR, CDC). When the app
   answers, it can tell the user *where* the guidance comes from. This builds trust and
   makes the corpus auditable by partners post-hackathon.
3. **Offline simplicity.** ~23 chunks × 768 dims ≈ 69 KB of vectors. It ships inside the
   APK, loads in under 200ms, and searches in under 5ms. No server, no network, no
   first-run download that could fail in a flood.

This is **not** a general knowledge base. It is a tightly scoped emergency reference for
the 10–12 topics most likely to save lives in a Bangladesh flood or cyclone.

---

## 2. Topic Coverage Matrix

Target: **~23 chunks** across 10 topics. Each topic has a target count; the counts add
up to 23. Topics are ordered by demo impact (the first ones are what we'll show on
stage).

| Topic | `topic` value | Target chunks | Priority |
|---|---|---|---|
| ORS / dehydration | `ors` | 3 | P0 (demo) |
| Water purification | `water` | 3 | P0 (demo) |
| Severe diarrhea / cholera | `diarrhea` | 2 | P0 (demo) |
| Snakebite do/don't | `snakebite` | 2 | P0 (demo) |
| Bleeding / wound care | `bleeding` | 3 | P1 |
| Cyclone shelter / flood safety | `cyclone` | 3 | P1 |
| Drowning rescue | `drowning` | 2 | P1 |
| Fever / infection signs | `fever` | 2 | P2 |
| Pregnancy / infant care in disaster | `infant` | 2 | P2 |
| Emotional first-aid / panic | `emotional` | 1 | P2 |
| **Total** | | **23** | |

P0 topics must be done by IC-2 (end of Day 3). P1 by IC-3 (end of Day 5). P2 if time
permits — they're valuable but not demo-critical.

---

## 3. Chunk Schema

`tools/corpus.json` is a JSON array. Each element:

```json
{
  "id": "ors_recipe_basic",
  "topic": "ors",
  "lang": "bn",
  "source": "WHO Cholera fact sheet, 2024",
  "text": "ORS তৈরির সহজ উপায়: ১ লিটার পরিষ্কার পানি নিন। এতে ৬ চা-চামচ চিনি ও আধা চা-চামচ লবণ মেশান। ভালো করে নাড়ুন যতক্ষণ না দ্রবীভূত হয়। পাতলা পায়খানা বা বমির পর প্রতিবার অল্প অল্প করে খাওয়ান। শিশুকে বারবার অল্প পরিমাণে দিন। বানানো ORS কয়েক ঘণ্টা পর নতুন করে বানান।",
  "keywords_bn": ["ORS", "ডায়রিয়া", "পানিশূন্যতা", "চিনি", "লবণ", "খাওয়ানো"]
}
```

| Field | Type | Rule |
|---|---|---|
| `id` | string | stable snake_case, unique, descriptive (e.g. `snakebite_dont_cut`) |
| `topic` | string | one of the values in §2 |
| `lang` | string | `"bn"` for now; `"en"` only as a fallback chunk if needed |
| `source` | string | short citation — see §5 for the whitelist |
| `text` | string | **60–120 words** of simple Bangla; see §4 authoring checklist |
| `keywords_bn` | string[] | 5–10 Bangla keywords that should match this chunk even with imperfect STT |

The `id` is the stable join key across `corpus.json` and `vectors.bin`. Never rename an
`id` after build — embeddings would silently desync.

---

## 4. Authoring Checklist (run on every chunk)

- [ ] **Plain Bangla.** No jargon, no English loanwords where a Bangla word exists. Aim
  for a Class 5 reading level.
- [ ] **60–120 words.** Shorter = too thin to be useful; longer = dilutes retrieval and
  overwhelms the reader.
- [ ] **One actionable idea per chunk.** Don't combine ORS recipe with water purification
  in one chunk. Split them.
- [ ] **Numbered steps where sequential.** Free prose for context; numbered steps for
  actions.
- [ ] **Bangla numerals (০-৯)** in user-facing text, not Western digits.
- [ ] **Danda (।)** as the full stop, not Latin period.
- [ ] **No diagnosis, no prescription.** "যদি X হয় তাহলে Y করুন" is fine; "আপনার X হয়েছে,
  Z ওষুধ খান" is not.
- [ ] **Always end with the escalation cue** if the topic is critical: "অবস্থা খারাপ হলে
  ৯৯৯ এ কল করুন বা নিকটস্থ হাসপাতালে যান।"
- [ ] **Source attribution present** in the `source` field — no chunk without a source.
- [ ] **Keywords cover STT failure modes.** If Vosk mishears "ORS" as "ওআরএস", include
  both spellings in `keywords_bn`.

---

## 5. Source Whitelist

Only these sources are allowed. If Sehab wants to add a source, Ahnaf must
approve it.

| Source | Citation format | URL / access |
|---|---|---|
| World Health Organization (WHO) | `WHO <topic> fact sheet, <year>` | who.int — public |
| Bangladesh Red Crescent Society (BDRCS) | `BDRCS <guide name>, <year>` | bdrcs.org — public |
| Bangladesh Ministry of Disaster Management (MoDMR) | `MoDMR <advisory>, <year>` | modmr.gov.bd — public |
| Bangladesh Meteorological Department (BMD) | `BMD <warning type>, <year>` | bmd.gov.bd — public |
| CDC (US Centers for Disease Control) | `CDC <topic>, <year>` | cdc.gov — public |
| IFRC (International Federation of Red Cross) | `IFRC <guide>, <year>` | ifrc.org — public |

**Not allowed:** random health blogs, AI-generated medical content, unverified social
media, sources behind paywalls, or anything without a clear public license.

**License note:** facts are not copyrightable; the chunks are paraphrased into simple
Bangla (transformative use). Source attribution is preserved per chunk for traceability.

---

## 6. Review Process

```
Sehab drafts chunk in tools/corpus.json
        |
        |  // REVIEW: <question> comment where unsure
        v
Ahnaf edits Bangla phrasing, checks medical accuracy, verifies source
        |
        v
Ahnaf marks chunk approved (remove // REVIEW comment)
        |
        v
Ahnaf runs tools/build_kb.py → assets/kb/{corpus.json, vectors.bin}
        |
        v
Ahnaf runs tools/verify_kb.py → all 7 test queries must be OK
        |
        v
Commit to main at IC-2
```

**Hard rules:**

- No chunk ships without Ahnaf's sign-off.
- No chunk ships without a passing `verify_kb.py`.
- If `verify_kb.py` returns `BAD` for a query, fix the chunk's `text` or `keywords_bn` —
  do not lower the test bar.

---

## 7. Build & Verify Scripts

### `tools/build_kb.py`

Reads `tools/corpus.json`, embeds each chunk's `(text + topic prefix + keywords_bn)`
with `paraphrase-multilingual-mpnet-base-v2` (via `sentence-transformers`), L2-normalizes
the vectors, and writes:

- `assets/kb/corpus.json` — a copy of the source (shipped for transparency).
- `assets/kb/vectors.bin` — `float32`, row-major, shape `[N, 768]`.
- `assets/kb/meta.json` — build metadata (chunk count, embed dim, build timestamp).

Run from the `tools/` directory after activating the venv:

```bash
cd tools
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 build_kb.py
```

### `tools/verify_kb.py`

Runs 7 hand-authored Bangla queries through the built index and asserts the top-1
`topic` matches expectation. Exits non-zero on any `BAD`. Run after every corpus change:

```bash
python3 tools/verify_kb.py
```

The 7 test queries:

1. "আমার বাচ্চার ডায়রিয়া হয়েছে, কি করবো" → `diarrhea`
2. "সাপে কামড়েছে" → `snakebite`
3. "ORS কিভাবে বানাবো" → `ors`
4. "বিশুদ্ধ পানি কিভাবে বানাবো" → `water`
5. "রক্তপাত বন্ধ হচ্ছে না" → `bleeding`
6. "ঝড়ের সময় কোথায় যাবো" → `cyclone`
7. "পানিতে ডুবে যাওয়া ব্যক্তি" → `drowning`

Add test queries as the corpus grows, but never remove the original 7.

---

## 8. Versioning

- `corpus.json` has an implicit version = the git commit it ships from. No semantic
  version needed for the hackathon.
- `build_kb.py` writes a `corpus_meta.json` alongside the outputs recording the chunk
  count, embed dim, and build timestamp. This helps debug "why did the answer change?"
  regressions.
- Never rename a chunk `id` after it's been built — embeddings would desync. If a chunk
  is wrong, edit its `text` in place and rebuild.

---

## 9. Extending Post-Hackathon

The corpus is designed to grow. Post-hackathon expansion path:

1. Partner review with BDRCS / MoDMR / WHO Bangladesh for medical accuracy.
2. Add regional dialects (Noakhali, Sylheti, Chittagong) as separate `lang` values or
   parallel corpora.
3. Add more topics: burn care, heat stroke, food safety in floods, maternal care.
4. Add multimodal cues: "if the wound looks X, do Y" — paired with the stretch vision
   model.
5. Crowd-source shelter status once connectivity returns (separate from this corpus).

The brute-force retriever scales comfortably to ~500 chunks before we'd consider HNSW.
At 500+ chunks, swap `BruteForceRetriever` for an HNSW index — the `retriever.dart`
interface stays the same.
