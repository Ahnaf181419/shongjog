# Shongjog — Post-Hackathon Roadmap

> **Internal team-facing document.** What happens *after* the demo: open technical debt,
> corpus expansion, partner integration, multilingual support, multimodal triage, and the
> path to real deployment. This document is a starting point — refine as the team's plans
> evolve.

Companion docs: `docs/team.md` (work division), `docs/corpus.md` (knowledge policy),
`docs/PRE-DEMO.md` (operational roadmap).

---

## 1. Tech debt — must-fix before any user testing

These are items that ship as-is for the demo but would damage credibility if the app
went beyond a hackathon audience.

### 1.1 Vosk STT plugin compatibility

**Status:** `vosk_flutter` plugin has a `compileSdk` version mismatch with modern AGP
(Android Gradle Plugin 9.x). Workaround during demo: use `SpeechToTextProvider` (online)
with a typed-input fallback for offline.

**Options for the post-hackathon fix (ordered by effort):**

1. **Use raw Vosk via FFI.** Implement a thin Dart bridge over the Vosk C API using
   `ffi` package. ~200 lines of glue code. Requires no plugin updates.
2. **Fork `vosk_flutter`.** Bump the plugin's `compileSdk` to current AGP, publish a
   fix-it PR. ~50 lines of build.gradle changes.
3. **Alternative offline STT package.** `whisper_ggml` (Whisper.cpp bindings) has small
   multilingual models including Bangla. Slightly higher accuracy, larger model.
4. **Hybrid.** Use a stripped-down command recognizer (`porcupine`, `picovoice`,
   `snowboy`) for short fixed phrases and rely on typed input for freeform.

**Recommendation:** Option 2 + Option 1. Fork the plugin, ship a PR upstream; use raw
FFI as a long-term fallback.

### 1.2 Model manager race conditions

The current `ModelManager` singleton works for one-user-one-app. Concurrent calls to
`initialize()` can create two `FlutterGemma` instances. Add an `in-flight` Future and
await it on subsequent calls. ~10 lines.

### 1.3 Chat message persistence security

`ChatStore` stores messages as plaintext JSON. For real users with sensitive medical
queries, this should be:
- Encrypted at rest (using `flutter_secure_storage` wrapping encrypted file)
- Auto-purged after session inactivity (configurable TTL)

### 1.4 APK install permissions flow

Currently the app requests `INTERNET`, `RECORD_AUDIO`, location, phone, SMS — all at
once on first run via `permission_handler`. Move to on-demand requests: only request mic
permission when user first taps the mic button, location when they tap shelter, etc.

---

## 2. Corpus expansion — the most impactful future work

The 23-chunk corpus is a demo pilot, not a production knowledge base. Each chunk is
paraphrased from one of the allow-listed sources (WHO, BDRCS, MoDMR, BMD, CDC, IFRC) and
reviewed by an internal team member. Post-hackathon, the corpus needs:

### 2.1 Partner review

- **BDRCS** (Bangladesh Red Crescent Society): Their first-aid trainers should review
  every chunk for medical accuracy. They've already authored similar guidance for their
  volunteer network.
- **MoDMR** (Ministry of Disaster Management): Validate the cyclone and shelter chunks
  against their official advisories.
- **BMD** (Bangladesh Meteorological Department): Source real-time hazard data feed
  (currently out of scope; see §5.2).
- **WHO Bangladesh**: For the ORS / diarrhea / cholera / maternal care chunks.

Target: a published, peer-reviewed corpus version 2.0, ~100 chunks, attrubuted to each
source.

### 2.2 More topics

The current 10 topics cover the most common flood/cyclone first-aid cases. Expand to:
- Burn care
- Heat stroke
- Food safety in floods (esp. in crowded shelters)
- Maternal & newborn care during disaster
- Mental health first-aid (panic, grief, displacement stress)
- Skin infections (waterborne)
- Post-disaster hygiene

### 2.3 Regional dialects

Bangla has regional variants. Add separate chunks or parallel corpora for:
- Sylheti
- Chittagong
- Noakhali (Barisal)
- Rangpur

`lang` field already supports this; just add corpus files per dialect.

### 2.4 Multilingual

- **English**: dual-language mode — show English + Bangla side-by-side for English-
  speaking NGO workers assisting during a crisis.
- **Rohingya**: relevant for the Cox's Bazar refugee camps.
- **Hindi** (close to Bangla): a stretch goal for the broader Bengal region.

### 2.5 HNSW retrieval

At ~100 chunks, brute-force cosine is still fast (<10ms). At 500+ chunks, swap to
HNSW (`hnswlib` or `faiss` via FFI). The `Retriever` interface stays the same; only
the implementation changes.

---

## 3. Partners & deployment

### 3.1 Distribution channels

- **Play Store**: Free, opt-in. Aimed at NGOs and individual preparedness.
- **Direct APK**: Bundled with fleet devices (Red Crescent volunteers, schools,
  hospitals) via MDM tools.
- **Government channel**: Negotiate pre-installation on Bangladesh government-issued
  tablets via a2i / ICT Division.

### 3.2 BDRCS pilot

- Onboard 50 BDRCS volunteers across 5 upazilas with the app as-is on personal devices
- Measure: query volume, answer satisfaction, time-to-resolution
- 1-month pilot, monthly review

### 3.3 MoDMR pre-season push

- Pre-monsoon campaign (March-April): push to coastal chatrooms, mosque announcements,
  school networks
- Pre-cyclone (October-November): shelter finder + SOS emphasized

---

## 4. New features (impact-ranked)

### 4.1 Multimodal triage (highest perceived demo impact)

Gemma 4 E2B supports native vision input. Add a "ছবি দেখান" (show photo) affordance:

- **Snake ID**: photograph a snake, app says which family (krait/cobra/viper) and
  whether to approach or back away.
- **Wound severity**: photograph a wound, app says "minor — clean and dress" or
  "severe — go to hospital".
- **Water safety**: photograph floodwater for an off-white float check.

Architecture is already in place (`flutter_gemma` supports vision). Need:
- Camera capture widget
- Image preprocessing (resize, normalize)
- Prompt template additions for vision-grounded answers
- Corpus chunks for visual triage (carefully sourced; defer until corpus 2.0)

### 4.2 Mesh comm — verify & scale

The current `mesh_comm/` works for 2 peers; verify for 5-10 peers in a chaotic mesh
where nodes drop in and out. Implement:
- Message store-and-forward (cache messages for offline peers)
- Encryption (libsodium)
- Group channels (one-per-incident)
- File transfer (small images / location pins)

Stretch: long-range radio (Meshtastic / LoRa) for when Wi-Fi Direct fails. Probably
2 quarters out.

### 4.3 Family-safe board

Crowd-sourced status board. Each user can mark "I am safe" / "I am at shelter X" /
"Need rescue" — visible to a permissioned circle (family, neighbors). Critical for
post-disaster reunification when telecom is congested.

### 4.4 Pre-season household prep checklist

Custom plan per household (number of family members, age range, health conditions,
district hazard profile). Helps the family prep before monsoon season. Stretch
goal, depends on partner-content availability.

### 4.5 Real-time hazard feed (requires connectivity — OUT of core loop)

When network is back: integrate BMD cyclone advisories and MoDMR flood warnings as
push notifications. The core offline loop must continue to work even if the feed
fails to deliver.

---

## 5. Quality & operations

### 5.1 Telemetry pipeline

For real deployment, anonymized usage analytics:
- Query volume per upazila / per week (heat-map of need)
- WER per utterance from Vosk log
- Latency per query (model manager instrumentation already in place)
- Drop-off points in onboarding flow

Use `firebase_crashlytics` (crash only, no analytics) + a local-only analytics
buffer that flushes only when online and only if the user opts in. Never collect:
voice recordings, photos, GPS coordinates, chat content.

### 5.2 Auto-update of corpus via signed bundles

When BDRCS publishes revised guidance, the app should fetch a signed corpus bundle
when online and update. Use:
- Bundle format: `corpus_v{N}.json.zst` + `signature.bin`
- Ed25519 signature check before applying
- A/B test new corpus vs. old via distributed queries (per chunk)

### 5.3 Hardware certification matrix

Test on:
- Samsung Galaxy A-series (most common in Bangladesh)
- Xiaomi Redmi Note (most common sub-$200)
- Motorola entry-level (low-end floor)
- OnePlus / Pixel (flagship reference)

Performance budgets vary; document the floor device's measured numbers, not the
flagship's.

### 5.4 Accessibility audit

- VoiceOver / TalkBack screen reader walkthroughs for every screen
- High-contrast mode verification
- Dynamic type verification
- Motor accessibility (one-handed reach for all critical actions)
- Cognitive load: the static cards are 1-screen each. Verify reading-level via
  feedback from low-literacy user interviews.

---

## 6. The long-term vision

A 3-year view:

```
Year 1:
  - Corpus v2 (100+ chunks, BDRCS-reviewed)
  - Vosk true offline
  - Multimodal vision triage (limited scope: snake + wound)
  - BDRCS pilot in 5 upazilas

Year 2:
  - Real-time BMD hazard feed (online path)
  - Family-safe board
  - Sylheti + Chittagong dialect support
  - 50,000 active users

Year 3:
  - Multilingual (English, Hindi, Rohingya)
  - LoRa backhaul for remote districts
  - Government-tier distribution via MoDMR
  - 1M+ active users across Bangladesh
```

The goal is not to be a startup. The goal is to be the default Bangladesh disaster-
preparedness app, used and trusted by every coastal and flood-prone family. Long-term
sustainability via partnership with BDRCS, MoDMR, and a2i — never via ads or data
collection.

---

## 7. What we will NOT build

To keep the product honest, here are features explicitly out of scope:

- **Cloud AI as the primary path.** The thesis is offline; cloud is fallback only.
- **Ads.** Crises are not a place for monetization.
- **Data collection for analytics.** Voice and chat content never leave the device.
- **Social features that aren't safety-critical.** No chat rooms, no leaderboards, no
  check-ins-with-friends outside the family-safe board.
- **Voice cloning / synthesis of victims.** Off-limits on safety grounds.
- **Medical device certification claims.** We're a guidance app, not a diagnostic tool.
  The app's UI reminds the user of this on every critical answer.

These red lines keep the product useful in a crisis rather than exploitative of one.
