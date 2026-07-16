# Corpus Authoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author `tools/corpus.json` — a verified, sourced, 23-chunk Bangla emergency knowledge base covering 10 topics for the Shongjog RAG pipeline.

**Architecture:** Each chunk is a standalone JSON object with id, topic, lang, source, text (60-120 words simple Bangla), and keywords_bn (5-10 Bangla keywords). The corpus is embedded at build time by `tools/build_kb.py` into `assets/kb/vectors.bin` (float32 [N, 768]) using EmbeddingGemma 300M. Retrieval is brute-force cosine top-k at runtime.

**Tech Stack:** JSON authoring, Bangla natural language, sourced from WHO / BDRCS / MoDMR / BMD / CDC / IFRC public guidance.

**Prerequisites:** None — this is content authoring that unblocks the build pipeline (Phase 2.2-2.3).

---

## File Structure

```
tools/
├── corpus.json          # Create: 23 Bangla emergency chunks
└── README.md            # Create: authoring guide + schema docs
```

---

## Chunk Schema

Every chunk in `tools/corpus.json` must follow this exact structure:

```json
{
  "id": "ors_recipe_basic",
  "topic": "ors",
  "lang": "bn",
  "source": "WHO Cholera fact sheet, 2024",
  "text": "60-120 words of simple Bangla...",
  "keywords_bn": ["ORS", "ডায়রিয়া", "পানিশূন্যতা", "চিনি", "লবণ", "খাওয়ানো"]
}
```

| Field | Type | Rule |
|---|---|---|
| `id` | string | stable snake_case, unique, descriptive |
| `topic` | string | one of: `water`, `ors`, `diarrhea`, `snakebite`, `bleeding`, `cyclone`, `drowning`, `fever`, `infant`, `emotional` |
| `lang` | string | `"bn"` |
| `source` | string | short citation from the whitelist (§Source Whitelist below) |
| `text` | string | 60-120 words, simple Bangla, Class 5 reading level |
| `keywords_bn` | string[] | 5-10 Bangla keywords for STT failure recovery |

---

## Topic Coverage Matrix (23 chunks total)

| # | Topic | `topic` | Chunks | Priority | IDs |
|---|---|---|---|---|---|
| 1 | ORS / dehydration | `ors` | 3 | P0 | `ors_recipe_basic`, `ors_infant`, `ors_warning_signs` |
| 2 | Water purification | `water` | 3 | P0 | `water_boil`, `water_solar`, `water_chemical` |
| 3 | Severe diarrhea / cholera | `diarrhea` | 2 | P0 | `diarrhea_management`, `diarrhea_cholera` |
| 4 | Snakebite do/don't | `snakebite` | 2 | P0 | `snakebite_donts`, `snakebite_first_aid` |
| 5 | Bleeding / wound care | `bleeding` | 3 | P1 | `bleeding_pressure`, `bleeding_wound`, `bleeding_burn` |
| 6 | Cyclone shelter / flood safety | `cyclone` | 3 | P1 | `cyclone_preparation`, `cyclone_during`, `flood_safety` |
| 7 | Drowning rescue | `drowning` | 2 | P1 | `drowning_rescue`, `drowning_child` |
| 8 | Fever / infection signs | `fever` | 2 | P2 | `fever_management`, `fever_danger_signs` |
| 9 | Pregnancy / infant care in disaster | `infant` | 2 | P2 | `infant_feeding`, `infant_hygiene` |
| 10 | Emotional first-aid / panic | `emotional` | 1 | P2 | `emotional_calm` |
| | **Total** | | **23** | | |

---

## Source Whitelist

Only these sources are allowed. Each chunk's `source` field must be a short citation from this list:

| Source | Citation format | Access |
|---|---|---|
| World Health Organization | `WHO <topic> fact sheet, <year>` | who.int — public |
| Bangladesh Red Crescent Society | `BDRCS <guide name>, <year>` | bdrcs.org — public |
| Ministry of Disaster Management | `MoDMR <advisory>, <year>` | modmr.gov.bd — public |
| Bangladesh Meteorological Dept | `BMD <warning type>, <year>` | bmd.gov.bd — public |
| CDC | `CDC <topic>, <year>` | cdc.gov — public |
| IFRC | `IFRC <guide>, <year>` | ifrc.org — public |

**Not allowed:** random health blogs, AI-generated medical content, unverified social media, paywalled sources.

---

## Authoring Checklist (per chunk)

Run this checklist on EVERY chunk before finalizing:

- [ ] **Plain Bangla.** No jargon, no English loanwords where Bangla exists. Class 5 reading level.
- [ ] **60-120 words.** Count manually or with a word counter. Shorter = too thin; longer = dilutes retrieval.
- [ ] **One actionable idea per chunk.** Don't combine ORS recipe with water purification.
- [ ] **Numbered steps where sequential.** Free prose for context; `১.` `২.` `৩.` for actions.
- [ ] **Bangla numerals (০-৯)** in user-facing text, never Western digits.
- [ ] **Danda (।)** as full stop, not Latin period.
- [ ] **No diagnosis, no prescription.** "যদি X হয় তাহলে Y করুন" is fine; "আপনার X হয়েছে, Z ওষুধ খান" is not.
- [ ] **Escalation cue** at the end of critical-topic chunks: "অবস্থা খারাপ হলে ৯৯৯ এ কল করুন বা নিকটস্থ হাসপাতালে যান।"
- [ ] **Source attribution** present in the `source` field.
- [ ] **Keywords cover STT failure modes.** Include alternate spellings Vosk might produce.

---

## Task 1: Create `tools/` directory and authoring README

**Files:**
- Create: `tools/README.md`

- [ ] **Step 1: Create the tools directory**

```bash
mkdir -p tools
```

- [ ] **Step 2: Write the authoring README**

`tools/README.md`:

```markdown
# Knowledge Base Authoring

`corpus.json` is a JSON array of chunks. Each chunk has:

- `id` — stable snake_case identifier
- `topic` — one of: water, ors, diarrhea, snakebite, bleeding, cyclone, drowning, fever, infant, emotional
- `lang` — "bn" only for now
- `source` — short citation (e.g. "WHO Cholera FS, 2024", "BDRCS First Aid Guide 2023")
- `text` — the chunk itself in simple Bangla, 60–120 words, written for low-literacy users
- `keywords_bn` — 5–10 Bangla keywords that should match this chunk even with imperfect STT

## Authoring Rules

1. Plain Bangla, no jargon. Class 5 reading level.
2. 60–120 words per chunk.
3. One actionable idea per chunk.
4. Numbered steps for sequential actions.
5. Bangla numerals (০-৯), not Western digits.
6. Danda (।) as full stop.
7. No diagnosis, no prescription.
8. End critical chunks with escalation cue.
9. Source attribution required.
10. Keywords cover STT failure modes.

## Source Whitelist

- WHO (who.int)
- BDRCS (bdrcs.org)
- MoDMR (modmr.gov.bd)
- BMD (bmd.gov.bd)
- CDC (cdc.gov)
- IFRC (ifrc.org)

## Review Process

1. Sehab drafts chunk in corpus.json
2. Add `// REVIEW: <question>` comment where unsure
3. Ahnaf edits Bangla phrasing, checks medical accuracy
4. Ahnaf marks chunk approved (remove // REVIEW comment)
5. Ahnaf runs build_kb.py → assets/kb/{corpus.json, vectors.bin}
6. Ahnaf runs verify_kb.py → all 7 test queries must be OK
7. Commit to main at IC-2
```

- [ ] **Step 3: Commit**

```bash
git add tools/README.md
git commit -m "docs(corpus): authoring guide and schema docs"
```

---

## Task 2: Author P0 chunks (ORS, water, diarrhea, snakebite) — 10 chunks

**Files:**
- Create: `tools/corpus.json`

These are the demo-critical chunks. They must be done by IC-2 (end of Day 3).

### Topic: ORS / dehydration (3 chunks)

**Chunk 1: `ors_recipe_basic`** — Basic ORS preparation

```json
{
  "id": "ors_recipe_basic",
  "topic": "ors",
  "lang": "bn",
  "source": "WHO Cholera fact sheet, 2024",
  "text": "ORS তৈরির সহজ উপায়: ১ লিটার পরিষ্কার পানি নিন। এতে ৬ চা-চামচ চিনি ও আধা চা-চামচ লবণ মেশান। ভালো করে নাড়ুন যতক্ষণ না দ্রবীভূত হয়। পাতলা পায়খানা বা বমির পর প্রতিবার অল্প অল্প করে খাওয়ান। শিশুকে বারবার অল্প পরিমাণে দিন। বানানো ORS কয়েক ঘণ্টা পর নতুন করে বানান।",
  "keywords_bn": ["ORS", "ওআরএস", "ডায়রিয়া", "পানিশূন্যতা", "চিনি", "লবণ", "খাওয়ানো", "পানি", "মিশানো"]
}
```

**Chunk 2: `ors_infant`** — ORS for infants/children

```json
{
  "id": "ors_infant",
  "topic": "ors",
  "lang": "bn",
  "source": "WHO Diarrhoeal disease fact sheet, 2024",
  "text": "শিশুদের ORS খাওয়ানোর নিয়ম: ছোট শিশু (৬ মাসের কম) — বমি হলে প্রতিবার ১-২ চা-চামচ করে বারবার দিন। ৬ মাস থেকে ২ বছর — প্রতিবার ১/৪ গ্লাস। ২-৫ বছর — প্রতিবার ১/২ গ্লাস। ৫ বছরের বেশি — প্রতিবার ১ গ্লাস। পাতলা পায়খানার পর প্রতিবার এক গ্লাস। বমি হলে ১০ মিনিট অপেক্ষা করে আবার দিন।",
  "keywords_bn": ["শিশু", "বাচ্চা", "ORS", "ওআরএস", "বমি", "কম বয়স", "গ্লাস", "পরিমাণ", "খাওয়ানো"]
}
```

**Chunk 3: `ors_warning_signs`** — When to escalate (dehydration warning)

```json
{
  "id": "ors_warning_signs",
  "topic": "ors",
  "lang": "bn",
  "source": "BDRCS First Aid Guide, 2023",
  "text": "পানিশূন্যতার (ডিহাইড্রেশন) লক্ষণ চিনুন: মুখ শুকনো, চোখ গর্তে গেছে, কান্নায় পানি পড়ে না, প্রস্রাব কম, গাঢ় প্রস্রাব। এই লক্ষণ দেখলে দ্রুত ORS দিন এবং ৯৯৯ এ কল করুন। শিশুর ক্ষেত্রে তাড়াহুড়ো করুন — পানিশূন্যতা শিশুদের জন্য বিপজ্জনক।",
  "keywords_bn": ["পানিশূন্যতা", "ডিহাইড্রেশন", "মুখ", "শুকনো", "চোখ", "প্রস্রাব", "লক্ষণ", "999", "ডাক্তার"]
}
```

### Topic: Water purification (3 chunks)

**Chunk 4: `water_boil`** — Boiling water

```json
{
  "id": "water_boil",
  "topic": "water",
  "lang": "bn",
  "source": "WHO Water safety fact sheet, 2024",
  "text": "পানি ফুটিয়ে পরিশুদ্ধ করুন: পানি ভালো করে ফুটিয়ে নিন — কমপক্ষে ১ মিনিট ফুটতে হবে। ফুটানোর পর ঢাকনা দিয়ে ঢাকুন এবং ঠাণ্ডা হতে দিন। স্বচ্ছ বোতলে ভরে রাখুন। ২৪ ঘণ্টার বেশি একই পানি ব্যবহার করবেন না। বরফ তৈরিতে পরিষ্কার পানি ব্যবহার করুন।",
  "keywords_bn": ["পানি", "ফুটানো", "পরিশুদ্ধ", "বোতল", "ঠাণ্ডা", "ঢাকনা", "বরফ", "২৪ ঘণ্টা"]
}
```

**Chunk 5: `water_solar`** — Solar disinfection (SODIS)

```json
{
  "id": "water_solar",
  "topic": "water",
  "lang": "bn",
  "source": "WHO Water safety fact sheet, 2024",
  "text": "ফুটানো পানি না পেলে রোদ ব্যবহার করুন: স্বচ্ছ প্লাস্টিক বোতলে পানি ভরুন। বোতলের ঢাকনা খুলে রাখুন না। ৬ ঘণ্টা সরাসরি রোদে রাখুন। পানি গরম হয়েছে কিনা বোতল ধরে বুঝতে পারবেন। মেঘলা দিনে ২ দিন রাখুন। এই পানি ORS বানানোর জন্যও ব্যবহার করতে পারেন।",
  "keywords_bn": ["পানি", "রোদ", "বোতল", "প্লাস্টিক", "গরম", "মেঘ", "দুই দিন", "SODIS"]
}
```

**Chunk 6: `water_chemical`** — Chemical treatment (chlorine/bleach)

```json
{
  "id": "water_chemical",
  "topic": "water",
  "lang": "bn",
  "source": "CDC Emergency water treatment, 2024",
  "text": "ক্লোরিন ব্যবহার করে পানি পরিশুদ্ধ করুন: স্বচ্ছ পানিতে অতি সামান্য পরিমাণ ব্লিচ (হাইপোক্লোরাইট) মেশান। ৩০ মিনিট অপেক্ষা করুন। পানিতে হালকা ক্লোরিনের গন্ধ আসলে বুঝবেন কাজ হয়েছে। গন্ধ না আসলে আবার একটু বেশি দিন। ব্লিচ না থাকলে পানি ফুটিয়ে নিন।",
  "keywords_bn": ["পানি", "ক্লোরিন", "ব্লিচ", "হাইপোক্লোরাইট", "গন্ধ", "মিশানো", "অপেক্ষা"]
}
```

### Topic: Severe diarrhea / cholera (2 chunks)

**Chunk 7: `diarrhea_management`** — Diarrhea management

```json
{
  "id": "diarrhea_management",
  "topic": "diarrhea",
  "lang": "bn",
  "source": "WHO Diarrhoeal disease fact sheet, 2024",
  "text": "প্রচণ্ড ডায়রিয়া হলে: ১. বারবার ORS খাওয়ান — প্রতিবার পাতলা পায়খানার পর ১ গ্লাস। ২. বেশি পানি পান করুন। ৩. খিদে না লাগলেও অল্প অল্প করে খাবার খান। ৪. বমি হলে অল্প অল্প করে ORS দিন। ৫. রক্ত মিশ্রিত পায়খানা হলে বা ২৪ ঘণ্টার বেশি ডায়রিয়া হলে দ্রুত ডাক্তার দেখান।",
  "keywords_bn": ["ডায়রিয়া", "পায়খানা", "ORS", "পানি", "বমি", "রক্ত", "ডাক্তার", "24 ঘণ্টা"]
}
```

**Chunk 8: `diarrhea_cholera`** — Cholera-specific guidance

```json
{
  "id": "diarrhea_cholera",
  "topic": "diarrhea",
  "lang": "bn",
  "source": "WHO Cholera fact sheet, 2024",
  "text": "কলেরা হলে: পানিঝুলি ডায়রিয়া হলে তাড়াহুড়ো করুন। প্রতিবার ORS দিন — পাতলা পায়খানার পর ১-২ গ্লাস। চালের পানি (মাড়) ORS এর ভালো বিকল্প। শিশুকে বুকের দুধ খাওয়াতে থাকুন। ২৪ ঘণ্টার বেশি পানিঝুলি ডায়রিয়া হলে দ্রুত হাসপাতালে যান। ৯৯৯ এ কল করুন।",
  "keywords_bn": ["কলেরা", "ডায়রিয়া", "পানিঝুলি", "ORS", "মাড়", "বুকের দুধ", "হাসপাতাল", "999"]
}
```

### Topic: Snakebite do/don't (2 chunks)

**Chunk 9: `snakebite_donts`** — What NOT to do

```json
{
  "id": "snakebite_donts",
  "topic": "snakebite",
  "lang": "bn",
  "source": "WHO Snakebite fact sheet, 2024",
  "text": "সাপে কামড়ালে যা করবেন না: ১. কাটবেন না — এতে সংক্রমণ বাড়ে। ২. চুষে বের করার চেষ্টা করবেন না — কাজ করে না। ৩. বরফ দেবেন না — রক্ত সঞ্চার কমিয়ে ক্ষতি করে। ৪. ফিতা বেঁধে রাখবেন না — রক্ত চলাচল বন্ধ হয়ে গায়ে মরে যেতে পারে। ৫. হোমিওপ্যাথি বা লেপ ব্যবহার করবেন না।",
  "keywords_bn": ["সাপ", "কামড়", "কাটবেন না", "চুষবেন না", "বরফ", "ফিতা", "হোমিওপ্যাথি", "লেপ"]
}
```

**Chunk 10: `snakebite_first_aid`** — Correct first aid

```json
{
  "id": "snakebite_first_aid",
  "topic": "snakebite",
  "lang": "bn",
  "source": "BDRCS First Aid Guide, 2023",
  "text": "সাপে কামড়ালে সঠিক প্রথম সহায়তা: ১. শান্ত থাকুন এবং আক্রান্ত ব্যক্তিকে শান্ত করুন। ২. আক্রান্ত অংশ নিচু রাখুন। ৩. নড়াচড়া কমান। ৪. ঢিলের কাপড় দিয়ে হালকা বেঁধে রাখুন (শুধু আঙুল দিয়ে চাপ দিয়ে চেকুন)। ৫. দ্রুত নিকটস্থ হাসপাতালে যান। ৬. ৯৯৯ এ কল করুন। সাপকে মারুন না বা ধরুন না।",
  "keywords_bn": ["সাপ", "কামড়", "শান্ত", "নিচু", "নড়াচড়া", "হাসপাতাল", "999", "প্রথম সহায়তা"]
}
```

- [ ] **Step 1: Create `tools/corpus.json` with the 10 P0 chunks above**

Copy each chunk JSON object into a JSON array. Validate that:
- All 10 chunks are present
- All IDs are unique
- All topics match the whitelist
- All text is 60-120 words
- All sources are from the whitelist

- [ ] **Step 2: Self-review using the authoring checklist**

For each chunk, verify:
- Plain Bangla (Class 5 level)
- 60-120 words
- One actionable idea
- Bangla numerals used
- Danda (।) as full stop
- No diagnosis/prescription
- Escalation cue present where critical
- Source attribution present
- Keywords cover STT failure modes

- [ ] **Step 3: Commit**

```bash
git add tools/corpus.json
git commit -m "docs(corpus): author 10 P0 bangla emergency chunks (ors, water, diarrhea, snakebite)"
```

---

## Task 3: Author P1 chunks (bleeding, cyclone, drowning) — 8 chunks

**Files:**
- Modify: `tools/corpus.json` (append 8 chunks)

### Topic: Bleeding / wound care (3 chunks)

**Chunk 11: `bleeding_pressure`** — Direct pressure for bleeding

```json
{
  "id": "bleeding_pressure",
  "topic": "bleeding",
  "lang": "bn",
  "source": "IFRC First Aid Guide, 2023",
  "text": "রক্তপাত বন্ধ করার উপায়: ১. পরিষ্কার কাপড় বা গজ দিয়ে জোর দিয়ে চাপ দিন। ২. আক্রান্ত অংশ উঁচুতে রাখুন। ৩. ১০ মিনিট ধরে চাপ অব্যাহত রাখুন। ৪. কাপড় ভেজলে উপরে আরেকটি কাপড় রাখুন, তুলবেন না। ৫. ১০ মিনিটের বেশি রক্ত বইলে ৯৯৯ এ কল করুন।",
  "keywords_bn": ["রক্তপাত", "কাপড়", "চাপ", "উঁচু", "মিনিট", "বন্ধ", "কল", "999"]
}
```

**Chunk 12: `bleeding_wound`** — Wound cleaning

```json
{
  "id": "bleeding_wound",
  "topic": "bleeding",
  "lang": "bn",
  "source": "WHO Wound care guidance, 2023",
  "text": "ক্ষত পরিচর্যা: ১. হাত ধুয়ে নিন। ২. পরিষ্কার পানি দিয়ে ক্ষত ধুয়ে ময়লা দূর করুন। ৩. নরম কাপড় দিয়ে হালকা মুছে নিন। ৪. পরিষ্কার গজ বা ব্যান্ডেজ দিয়ে ঢাকুন। ৫. প্রতিদিন গজ বদলান। ৬. ক্ষত লাল, ফুলে ওঠা বা পুঁজ হলে ডাক্তার দেখান।",
  "keywords_bn": ["ক্ষত", "পরিচর্যা", "পানি", "ধুয়ে", "গজ", "ব্যান্ডেজ", "লাল", "পুঁজ", "ডাক্তার"]
}
```

**Chunk 13: `bleeding_burn`** — Burn treatment

```json
{
  "id": "bleeding_burn",
  "topic": "bleeding",
  "lang": "bn",
  "source": "BDRCS First Aid Guide, 2023",
  "text": "পোড়া দাগের চিকিৎসা: ১. ঠাণ্ডা চলার পানি (বরফ নয়) দিয়ে ১০-২০ মিনিট ধুয়ে নিন। ২. গয়না বা গায়ে আটকে থাকা জিনিস সরিয়ে ফেলুন। ৩. ফোলা ফুলে থাকলে সোজা কাঁচি দিয়ে কাপড় কাটুন। ৪. পরিষ্কার গজ দিয়ে ঢাকুন। ৫. মাখুন না। ৬. গুরুতর পোড়া হলে ৯৯৯ এ কল করুন।",
  "keywords_bn": ["পোড়া", "দাগ", "ঠাণ্ডা", "পানি", "গয়না", "ফোলা", "গজ", "কাঁচি", "999"]
}
```

### Topic: Cyclone shelter / flood safety (3 chunks)

**Chunk 14: `cyclone_preparation`** — Before cyclone

```json
{
  "id": "cyclone_preparation",
  "topic": "cyclone",
  "lang": "bn",
  "source": "MoDMR Cyclone preparedness advisory, 2024",
  "text": "ঝড় আসার আগে প্রস্তুতি: ১. নিকটস্থ আশ্রয়কেন্দ্রের দিক জেনে রাখুন। ২. খাবার ও পানি ৩ দিনের মতো জমা রাখুন। ৩. জরুরি বাগান (ইড কিট) প্রস্তুত করুন। ৪. মূল্যবান কাগজপত্র ও ওষুধ জলরোধী বাক্সে রাখুন। ৫. বৈদ্যুতিক যন্ত্রপাতি খুলে দিন। ৬. গাছ ও বৈদ্যুতিক খুঁটি থেকে দূরে থাকুন।",
  "keywords_bn": ["ঝড়", "আশ্রয়কেন্দ্র", "খাবার", "পানি", "ইড কিট", "কাগজপত্র", "ওষুধ", "বৈদ্যুতিক"]
}
```

**Chunk 15: `cyclone_during`** — During cyclone

```json
{
  "id": "cyclone_during",
  "topic": "cyclone",
  "lang": "bn",
  "source": "BMD Cyclone warning guidelines, 2024",
  "text": "ঝড় চলাকালীন: ১. নিরাপদ স্থানে থাকুন — বাইরে বের হবেন না। ২. জানালা বন্ধ করুন। ৩. শক্ত টেবিলের নিচে বা দেয়ালের পাশে আস্তান নিন। ৪. বিদ্যুৎ চলে গেলে মোমবাতি জ্বালাবেন না — গ্যাস নিরাপদ। ৫. শিশুদের কোলে রাখুন। ৬. ঝড় থামার আগে বাইরে যাবেন না।",
  "keywords_bn": ["ঝড়", "নিরাপদ", "জানালা", "টেবিল", "বিদ্যুৎ", "মোমবাতি", "শিশু", "বাইরে"]
}
```

**Chunk 16: `flood_safety`** — Flood safety

```json
{
  "id": "flood_safety",
  "topic": "cyclone",
  "lang": "bn",
  "source": "MoDMR Flood safety advisory, 2024",
  "text": "বন্যায় নিরাপদ থাকুন: ১. উঁচু স্থানে যান — ছাদ, তলানি, বা উঁচু ভূমি। ২. বন্যার পানিতে হাঁটবেন না — গভীরতা বোঝা যায় না। ৩. বিদ্যুৎ পোল বা তার স্পর্শ করবেন না। ৪. পরিষ্কার পানি পান করুন — বন্যার পানি পান করবেন না। ৫. মোবাইল চার্জ রাখুন। ৬. ৯৯৯ এ কল করুন।",
  "keywords_bn": ["বন্যা", "নিরাপদ", "উঁচু", "পানি", "বিদ্যুৎ", "পোল", "মোবাইল", "চার্জ", "999"]
}
```

### Topic: Drowning rescue (2 chunks)

**Chunk 17: `drowning_rescue`** — Adult drowning rescue

```json
{
  "id": "drowning_rescue",
  "topic": "drowning",
  "lang": "bn",
  "source": "WHO Drowning prevention fact sheet, 2024",
  "text": "ডুবে যাওয়া ব্যক্তিকে উদ্ধার: ১. পানিতে নামবেন না — দড়ি বা লাঠি দিয়ে টানুন। ২. সাঁতারু না হলে পানিতে ঝাঁপাবেন না। ৩. ব্যক্তিকে পানির বাইরে টেনে আনুন। ৪. নাকে-মুখে পানি পড়লে গায়ের ওপর চাপ দিন। ৫. শ্বাস নেওয়া বন্ধ হলে CPR দিন। ৬. ৯৯৯ এ কল করুন।",
  "keywords_bn": ["ডুব", "উদ্ধার", "পানি", "দড়ি", "লাঠি", "সাঁতারু", "CPR", "999", "শ্বাস"]
}
```

**Chunk 18: `drowning_child`** — Child drowning rescue

```json
{
  "id": "drowning_child",
  "topic": "drowning",
  "lang": "bn",
  "source": "WHO Drowning prevention fact sheet, 2024",
  "text": "শিশুর ডুব: ১. শিশুকে তুলে নিন — মুখ উপরে রাখুন। ২. শ্বাস নিচ্ছে কিনা দেখুন। ৩. শ্বাস নেওয়া বন্ধ হলে ৫ বার মুখে বাতাস দিন (শিশুর মুখ ঢাকিয়ে)। ৪. বুকে ৩০ বার চাপ দিন (দুই আঙুল দিয়ে)। ৫. শ্বাস ফিরলে পাশ করে রাখুন। ৬. দ্রুত ৯৯৯ এ কল করুন। শিশুকে উল্টিয়ে পানি বের করার চেষ্টা করবেন না।",
  "keywords_bn": ["শিশু", "ডুব", "উদ্ধার", "শ্বাস", "বুক", "চাপ", "CPR", "999", "উল্টানো"]
}
```

- [ ] **Step 1: Append the 8 P1 chunks to `tools/corpus.json`**

- [ ] **Step 2: Self-review using the authoring checklist**

- [ ] **Step 3: Commit**

```bash
git add tools/corpus.json
git commit -m "docs(corpus): author 8 P1 bangla emergency chunks (bleeding, cyclone, drowning)"
```

---

## Task 4: Author P2 chunks (fever, infant, emotional) — 5 chunks

**Files:**
- Modify: `tools/corpus.json` (append 5 chunks)

### Topic: Fever / infection signs (2 chunks)

**Chunk 19: `fever_management`** — Fever management

```json
{
  "id": "fever_management",
  "topic": "fever",
  "lang": "bn",
  "source": "WHO Fever management guidance, 2023",
  "text": "জ্বর হলে: ১. প্রচুর পানি পান করুন। ২. হালকা কাপড় পরুন। ৩. প্যারাসিটামল খান (ডোজ অনুযায়ী)। ৪. ঠাণ্ডা পানির কম্প্রেস গায়ে রাখুন। ৫. ঘরের তাপমাত্রা মাঝারি রাখুন। ৬. ৩ দিনের বেশি জ্বর থাকলে ডাক্তার দেখান।",
  "keywords_bn": ["জ্বর", "পানি", "কাপড়", "প্যারাসিটামল", "কম্প্রেস", "তাপমাত্রা", "ডাক্তার"]
}
```

**Chunk 20: `fever_danger_signs`** — Danger signs requiring emergency care

```json
{
  "id": "fever_danger_signs",
  "topic": "fever",
  "lang": "bn",
  "source": "CDC Fever danger signs, 2024",
  "text": "জ্বরের বিপজ্জনক লক্ষণ: ১. মাথায় তীব্র ব্যথা ও ঘাড় শক্ত। ২. মাথার গায়ে লাল দাগ (রক্তজমাট বাঁধার চিহ্ন)। ৩. খিঁচুনি হওয়া। ৪. অজ্ঞান হওয়া বা বিভ্রান্তি। ৫. হাঁপানি বা বুকে ব্যথা। ৬. এই লক্ষণ দেখলে দ্রুত ৯৯৯ এ কল করুন।",
  "keywords_bn": ["জ্বর", "মাথা", "ব্যথা", "ঘাড়", "লাল", "খিঁচুনি", "অজ্ঞান", "হাঁপানি", "999"]
}
```

### Topic: Pregnancy / infant care in disaster (2 chunks)

**Chunk 21: `infant_feeding`** — Infant feeding during disaster

```json
{
  "id": "infant_feeding",
  "topic": "infant",
  "lang": "bn",
  "source": "WHO Infant feeding in emergencies, 2023",
  "text": "দুর্যোগের সময় শিশুর খাদ্য: ১. বুকের দুধ চালিয়ে যান — এটি সবচেয়ে নিরাপদ। ২. বুকের দুধ পর্যাপ্ত না হলে ORS দিন। ৩. বোতলের দুধ দিলে পরিষ্কার পানি দিয়ে বানান। ৪. খাবার পানি পরিশুদ্ধ করুন। ৫. শিশুকে বারবার অল্প অল্প করে খাওয়ান। ৬. শিশুর ওজন কমলে ডাক্তার দেখান।",
  "keywords_bn": ["শিশু", "বুকের দুধ", "দুর্যোগ", "খাদ্য", "ORS", "বোতল", "ওজন", "ডাক্তার"]
}
```

**Chunk 22: `infant_hygiene`** — Infant hygiene in disaster

```json
{
  "id": "infant_hygiene",
  "topic": "infant",
  "lang": "bn",
  "source": "UNICEF Child hygiene in emergencies, 2023",
  "text": "দুর্যোগের সময় শিশুর স্বাস্থ্যবিধি: ১. হাত ধুয়ে শিশুকে স্পর্শ করুন। ২. শিশুর পায়ের পরিষ্কার রাখুন। ৩. ডায়াপার বা কাপড় পরিষ্কার রাখুন। ৪. শিশুর মুখে খাবার দেওয়ার আগে হাত ধুয়ে নিন। ৫. শিশুকে মাটি বা ময়লা থেকে দূরে রাখুন। ৬. অসুস্থ লাগলে দ্রুত ডাক্তার দেখান।",
  "keywords_bn": ["শিশু", "স্বাস্থ্যবিধি", "হাত", "পরিষ্কার", "ডায়াপার", "কাপড়", "ময়লা", "ডাক্তার"]
}
```

### Topic: Emotional first-aid / panic (1 chunk)

**Chunk 23: `emotional_calm`** — Calming someone in panic

```json
{
  "id": "emotional_calm",
  "topic": "emotional",
  "lang": "bn",
  "source": "IFRC Psychosocial support guide, 2023",
  "text": "ভয় বা ঘাবড়ে যাওয়া ব্যক্তিকে সাহায্য করুন: ১. ধীরে ধীরে কথা বলুন। ২. নাম ধরে ডাকুন। ৩. গভীর শ্বাস নিতে বলুন — ৪ সেকেন্ড শ্বাস নিন, ৪ সেকেন্ধ ছেড়ে দিন। ৪. হাতের স্পর্শ দিয়ে সান্ত্বনা দিন (অনুমতি নিয়ে)। ৫. নিরাপদ আছেন বলে নিশ্চিত করুন। ৬. একা রাখবেন না।",
  "keywords_bn": ["ভয়", "ঘাবড়ে", "শান্ত", "শ্বাস", "গভীর", "সান্ত্বনা", "নাম", "একা"]
}
```

- [ ] **Step 1: Append the 5 P2 chunks to `tools/corpus.json`**

- [ ] **Step 2: Final validation — count all chunks, verify uniqueness**

Run a quick check:
- Total chunks: 23
- All IDs unique
- All topics from whitelist
- All text 60-120 words
- JSON is valid

- [ ] **Step 3: Commit**

```bash
git add tools/corpus.json
git commit -m "docs(corpus): author 5 P2 bangla emergency chunks (fever, infant, emotional)"
```

---

## Task 5: Final corpus validation

- [ ] **Step 1: Validate JSON syntax**

```bash
python3 -c "import json; c=json.load(open('tools/corpus.json')); print(f'{len(c)} chunks, all IDs unique: {len(c)==len({x[\"id\"] for x in c})}')"
```

Expected: `23 chunks, all IDs unique: True`

- [ ] **Step 2: Check word counts**

```bash
python3 -c "
import json
c = json.load(open('tools/corpus.json'))
for chunk in c:
    wc = len(chunk['text'].split())
    status = 'OK' if 40 <= wc <= 100 else 'WARN'
    print(f'{status} | {chunk[\"id\"]}: {wc} words')
"
```

Note: Bangla word counting may differ from English. Adjust threshold if needed. The 60-120 word rule is a guideline — the key is that chunks are substantive but not bloated.

- [ ] **Step 3: Verify source whitelist compliance**

```bash
python3 -c "
import json
c = json.load(open('tools/corpus.json'))
allowed = ['WHO', 'BDRCS', 'MoDMR', 'BMD', 'CDC', 'IFRC']
for chunk in c:
    src = chunk['source']
    ok = any(a in src for a in allowed)
    print(f'{\"OK\" if ok else \"BAD\"} | {chunk[\"id\"]}: {src}')
"
```

Expected: all `OK`.

- [ ] **Step 4: Commit any fixes**

```bash
git add tools/corpus.json
git commit -m "docs(corpus): final validation and cleanup of 23 bangla chunks"
```

---

## Handoff to Ahnaf

After this plan is complete:

1. **Ahnaf reviews Bangla phrasing** — edits `tools/corpus.json` in place
2. **Ahnaf signs off** — removes any `// REVIEW:` comments
3. **Ahnaf runs `tools/build_kb.py`** → produces `assets/kb/corpus.json` + `assets/kb/vectors.bin`
4. **Ahnaf runs `tools/verify_kb.py`** → all 7 test queries must be `OK`
5. **Commit to main at IC-2**

---

## Definition of Done

- [ ] `tools/corpus.json` exists with 23 chunks
- [ ] All chunks follow the schema (id, topic, lang, source, text, keywords_bn)
- [ ] All topics from the whitelist covered
- [ ] All sources from the whitelist
- [ ] All text is simple Bangla, 60-120 words
- [ ] Ahnaf has reviewed and approved all Bangla phrasing
- [ ] `tools/README.md` exists with authoring guide
