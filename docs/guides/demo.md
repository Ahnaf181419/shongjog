# Shongjog — Demo Runbook

> **Internal team-facing document.** The story arc, live demo script, pre-demo checklist,
> fallback playbook, anticipated judge Q&A, and honest limitations to surface.

This is the script Ahnaf runs on demo day. The whole point of Shongjog — "it works
when the internet doesn't" — lives or dies on the airplane-mode reveal. Everything here
is in service of that moment being undeniable.

Companion docs: product scope in `docs/prd.md`; design in `docs/design.md`; architecture
in `docs/architecture.md`.

---

## 1. The Story Arc (3 minutes)

The demo has one thesis: **the app works in airplane mode, when everything else is
dead.** Structure the three minutes around proving it, not narrating features.

1. **The hook (20s).** "When the flood comes, the internet goes with it. Every AI
   assistant, every chatbot, every helpline app — gone. So we asked: what if the AI
   worked anyway?"
2. **The reveal (10s).** Hold up the phone. Show airplane mode is ON. "This phone has no
   WiFi, no data. Watch."
3. **The proof (~2min).** Run the 5 scenarios below. Speak the Bangla queries aloud so
   the audience hears the language and the answer.
4. **The close (20s).** "Gemma 4 runs entirely on this phone. No servers, no API costs,
   no internet. Bangla, voice-first, grounded in WHO and Red Crescent guidance. This is
   what on-device AI is for."

**Do not** spend time on architecture slides during the live demo. Slides are for the
writeup; the stage is for the reveal.

---

## 2. Live Demo Script (5 scenarios, ~3 min total)

Run these in order. Each has: what to say, what to tap, what to expect, and the time
budget.

### Scenario 1 — Static quick cards work with no model (20s)
- **Say:** "Before the AI even loads, the app is already useful — verified emergency
  cards."
- **Tap:** cards tab in bottom nav (or the cards icon in AppBar on chat).
- **Expect:** list of 8 cards renders instantly. Tap "ORS তৈরি" — expands with numbered
  Bangla steps.
- **Why it matters:** proves the safety net. Even if the model failed, the app works.

### Scenario 2 — Voice query → grounded spoken answer (45s)
- **Say:** "Now the AI. My child has diarrhea and there's no clean water. I'll ask in
  Bangla, by voice."
- **Tap:** mic button. Speak clearly: "আমার বাচ্চার ডায়রিয়া হয়েছে, পরিষ্কার পানি নেই,
  কি করবো?"
- **Expect:** transcript appears in the input field; query submits; assistant bubble
  shows "ভাবছি..." then a grounded step-by-step Bangla answer; TTS reads it aloud; footer
  chip "জরুরি হলে ৯৯৯ এ কল করুন".
- **Why it matters:** the core thesis, end-to-end, offline, by voice.

### Scenario 3 — Snakebite: the "don't" answer (30s)
- **Say:** "Folk myths kill people here — cutting a snakebite, sucking the venom. Let's
  ask."
- **Tap:** mic. Speak: "সাপে কামড়েছে, কি করবো?"
- **Expect:** grounded answer that explicitly says কাটবেন না, চুষবেন না, বরফ দেবেন না;
  elevate the limb; get to a hospital; call 999.
- **Why it matters:** shows the corpus correcting dangerous common knowledge.

### Scenario 4 — Nearest shelter via GPS (40s)
- **Say:** "Now I need to know where to go."
- **Tap:** "নিকটস্থ আশ্রয়কেন্দ্র দেখান" from the answer action row (or shelter icon).
- **Expect:** GPS resolves; map opens centered on the venue; top 3 cyclone shelters
  render as shield markers with distance in km; tap the nearest for name + capacity.
- **Why it matters:** shows the function-call path — Gemma didn't just answer, it
  triggered an app action using offline data.

### Scenario 5 — One-tap emergency + SOS (25s)
- **Say:** "And when it's truly critical — one deliberate slide to dial 999."
- **Tap:** phone icon in AppBar → slide-to-confirm takes over the screen with "জরুরি কল"
  and large ৯৯৯.
- **Expect:** slide knob right to ≥90% of track → haptic feedback → system dialer opens
  with 999 prefilled. Cancel before actually calling (unless the venue is OK with it).
  Alternative path: "পরিবর্তে SOS পাঠান" link sends pre-drafted SMS with real GPS to 999.
- **Why it matters:** closes the loop from "information" to "action."

---

## 3. Pre-Demo Checklist (run the night before)

- [ ] Model `.task` file pre-loaded on device; verified by launching the app once and
  getting an answer.
- [ ] Vosk Bangla model bundled; mic tested with all 5 demo queries.
- [ ] `flutter_tts` `bn-BD` confirmed working through the phone speaker (not just
  headphones).
- [ ] GPS permission granted; last-known location is the venue (so the map centers
  correctly).
- [ ] Shelter GeoJSON spot-checked for the venue's region.
- [ ] 999 dialer tested (call a teammate, not 999).
- [ ] Airplane mode toggled on, then full 5-scenario flow run twice end-to-end.
- [ ] Device charged ≥ 80%; power bank packed.
- [ ] Bluetooth disconnected (so BT headset doesn't intercept TTS).
- [ ] Screen brightness at 70%+ (stage lights wash out dim screens).
- [ ] Notifications silenced (Do Not Disturb on).
- [ ] Fallback video (`docs/demo-fallback.mp4`) on device, opens in gallery, plays with
  screen mirroring.
- [ ] Screen mirroring / casting to the projector tested in the actual demo room.

---

## 4. Fallback Playbook

If the live demo flakes (model OOM, STT misfire, GPS denied, projector failure), switch
to the fallback video without losing momentum.

**Decision tree:**

- **First sign of trouble** (model taking >15s, STT garbled): do not apologize on stage.
  Say "let me show you a recorded run of the same flow" and start the video. Keep moving.
- **App crash:** same — switch to video. Do not relaunch on stage; it eats time and looks
  fragile.
- **Projector/casting fails:** narrate from the phone screen, hold it up. The airplane-mode
  status bar is still visible to the front row.
- **Total device failure:** use a teammate's device (same model file, same build). Every
  teammate has the same APK + model pre-loaded.

**Never:** explain at length what went wrong on stage. The audience remembers the
failure, not the explanation. Switch fast, finish strong.

---

## 5. Anticipated Judge Q&A

Crisp answers. Ahnaf takes all questions; Maruf and Sehab defer unless directly asked.

**Q: Does this really work offline?**
A: Yes — the entire loop runs on-device. Gemma 4 E2B, EmbeddingGemma, and Vosk are all
local. The only thing that touches the network is the one-time model download, which we
pre-loaded. We just demonstrated it in airplane mode.

**Q: Why Gemma specifically?**
A: It's open and efficient enough to run on a real phone in under 2GB of RAM. No cloud
model can do this — the moment the network drops, a cloud model is gone. Gemma 4 E2B is
the reason this product is possible.

**Q: How do you stop it hallucinating medical advice?**
A: RAG grounding. Every answer comes from a small corpus of WHO, Red Crescent, and
government guidance. If retrieval confidence is low, the app says so and points to 999
instead of guessing. The model triages and explains; it never diagnoses or prescribes.

**Q: What about privacy?**
A: Voice, GPS, and health queries never leave the phone. No analytics, no cloud. Zero
per-request cost.

**Q: Why Bangla?**
A: It's the language of the people most exposed. English-only guidance is useless to a
rural parent in a flood.

**Q: How accurate is the voice input?**
A: Vosk with the small Bangla model handles our target phrases well — we measured it in
our Phase 0 spike. For anything it mishears, typed input is always available as a
fallback.

**Q: What's the corpus size? How do you scale it?**
A: ~23 chunks right now, hand-curated and sourced. The brute-force retriever scales to
~500 chunks before we'd swap in an HNSW index. Post-hackathon we'd partner with BDRCS and
MoDMR to expand and medically review it.

**Q: Multimodal — can it see wounds or snakes?**
A: Not in this build. Gemma 4 E2B supports vision, and the architecture is ready for it,
but we scoped it as stretch for the hackathon. It's the first thing on the roadmap.

**Q: What if the model doesn't fit on a low-end phone?**
A: We fall back to Gemma 3 1B, which is smaller and broader-supported. The static quick
cards work even with no model loaded at all — the app is never useless.

**Q: How fast is it?**
A: Cold start to first answer is under 15 seconds. Steady-state question to answer is
under 8 seconds on our demo device. (Cite the actual Phase 5 numbers.)

---

## 6. Honest Limitations (surface these proactively)

Judges trust teams that name their limits. Bring these up if asked, or in the close:

- **Corpus is small and draft-quality.** ~23 chunks, paraphrased from public sources. Not
  medically reviewed by a professional yet — that's a post-hackathon milestone with BDRCS.
- **Vosk Bangla isn't perfect.** It handles our target phrases; freeform medical
  description can trip it. Typed input covers the gap.
- **No multimodal triage yet.** Wound/snake photo assessment is architected but not built.
- **Shelter data is incomplete.** We bundled what's publicly available; national coverage
  needs a government data partnership.
- **One language.** Bangla only; dialects and other languages are roadmap.
- **Demoed on a specific device.** Real-world deployment needs testing across the Android
  fleet Bangladeshis actually own.

---

## 7. Post-Demo (within 1 hour)

- [ ] Save the `screenrecord` capture from the live demo to `docs/demo-live.mp4` (even if
  it went well — it's evidence).
- [ ] Append actual timings and any flakiness to `docs/spike-results.md` §Phase 5.
- [ ] Note any judge questions that stumped us — feed into the writeup.
- [ ] Commit everything; tag the submission commit.
