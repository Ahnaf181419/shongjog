TITLE (Kaggle "Title" field):
Shongjog: A Gemma 4 Emergency Companion That Works When the Network Doesn't

SUBTITLE (Kaggle "Subtitle" field):
Offline, Bangla, voice-first flood and cyclone guidance — running entirely on-device for the people connectivity abandons first.

BODY (Kaggle "Detailed explanation" field, everything below this line):

## The Problem

Bangladesh is one of the most flood- and cyclone-exposed countries on Earth. Every monsoon season, storms and floods displace millions of people — and in the same hours, the infrastructure people would normally turn to for help disappears with them. Cellular data, broadband, and grid power routinely fail for hours or days during and after a major event. Every "AI assistant," chatbot, or web helpline that depends on a live connection goes dark at the exact moment its guidance is needed most.

The people most exposed are also the least served by internet-dependent tools. Official disaster guidance is frequently in English or dense formal Bangla that rural, elderly, or low-literacy users cannot parse quickly under stress. Into that gap flow dangerous folk myths — cutting a snakebite wound, drinking untreated floodwater, treating diarrhea with nothing at all — and preventable deaths from waterborne disease, unsafe water, and mismanaged injuries spike after every major flood or cyclone. Static PDF leaflets and blanket SMS alerts don't answer a person's specific situation, and generic cloud LLM apps both require a connection nobody has right now and are prone to hallucinating medical advice with no way to verify it in the field.

## The Solution

Shongjog ("connection" in Bangla) is a Flutter mobile app built around one non-negotiable constraint: **the core loop must work with every radio on the phone switched off.** A user in a flooded village asks an emergency question in Bangla — by voice or text — and the app:

1. Transcribes the question offline (on-device speech-to-text).
2. Retrieves the most relevant guidance from a 48-chunk, source-attributed Bangla knowledge base (WHO, Bangladesh Red Crescent Society, MoDMR, BMD, CDC, IFRC) using retrieval-augmented generation that runs entirely on-device.
3. Uses **Gemma 4 E2B, running locally on the phone**, to turn that retrieved context into a clear, grounded, step-by-step Bangla answer — never freelanced, never off-corpus.
4. Reads the answer aloud for users who cannot read quickly under stress.
5. Surfaces one-tap actions: dial 999, find the nearest cyclone shelter by GPS, or send a pre-drafted, location-encoded SOS SMS over the cellular voice channel — which frequently survives when mobile data does not.

If the model fails to load on a low-end device, the app doesn't go blank: 15 static, LLM-free emergency cards (ORS recipe, water purification, snakebite do/don't, CPR, choking, burns) and an 8-branch deterministic triage decision tree stay fully usable. Nothing that can save a life depends on inference succeeding.

## Why Gemma 4, and How It's Integrated

Shongjog only exists because Gemma 4 can run *inside the disaster*, not just describe how to survive one from a data center. That fact is the entire product thesis, and it shapes every architectural decision:

- **Gemma 4 E2B (4-bit quantized)** runs on-device via `flutter_gemma` and the LiteRT-LM (`.litertlm`) runtime, in under 2GB of RAM on real, non-flagship arm64 Android phones — thinking mode off for reflex-speed answers, output capped at 256 tokens to keep the longest grounded emergency answer fast.
- **RAG is mandatory, not optional.** A model this size must never freelance medical advice, so every answer is grounded in the curated corpus, embedded at build time and retrieved through a hybrid keyword/cosine retriever gated at a fixed 0.35 confidence floor. Below that floor the app returns a canned "ask a human, call 999" response instead of guessing — an explicit anti-hallucination guardrail, not a fallback of convenience.
- **Native function calling** turns Gemma from a chatbot into an agent: a spoken query like "আমি পটুয়াখালীতে আছি, কোন শেল্টার সবচেয়ে কাছে?" triggers a `find_nearest_shelter` tool call the app dispatches against bundled shelter data and haversine ranking, and a `submit_sos_report` tool populates a full SOS composer — location, hazard, casualties, injuries, needs — straight from natural speech.
- **Five AI-first modules run through the same on-device Gemma session**: a Family Disaster Planner that turns a household questionnaire into a personalized evacuation plan; an Emergency Kit Generator that reuses that profile for a quantified supply checklist (baby formula, insulin, litres of water); a Risk Assessment tool that scores flood/cyclone exposure 1–10 with a Bangla explanation; and a Situation Summary tool that synthesizes recent chat and SOS activity into a prioritized picture. Every one has a deterministic, non-LLM fallback, so the UI never renders a blank result.
- **A cloud tier extends Gemma exactly where the on-device model can't go yet**: `.litertlm` has no vision path, so the AI Damage Scanner routes a user's photo of flood, fire, or structural damage through Gemini vision — explicitly gated behind connectivity, with a clear "needs internet" state instead of a spinner that never resolves. This is the one deliberate, disclosed exception to the offline thesis, kept as small as possible.
- **Adaptive reasoning**: a keyword-based urgency classifier routes critical queries (breathing distress, drowning) to reflex mode and complex ones to deliberation; LoRA adapters hot-swap without reloading the base model, so future domain fine-tuning won't require re-shipping the app.

## System Architecture

The codebase follows a Flutter adaptation of the dependency rule: pure Dart domain logic — retrieval scoring, prompt assembly, haversine shelter ranking, the triage tree, SOS templating — carries zero Flutter or package dependencies and is fully unit-testable without a device. An adapter layer wraps `flutter_gemma`, `geolocator`, and `flutter_tts`; presentation stays swappable on top. A Python build pipeline (`sentence-transformers`) embeds the vetted corpus at build time into a shipped vector file, so the knowledge base ships inside the APK with no first-run network step — a real disaster is the worst possible moment to discover a download failed.

Two layers extend resilience beyond a single phone. A `nearby_connections` peer-to-peer mesh lets phones relay SOS beacons and "I'm safe" check-ins device-to-device — deduplicated, TTL-bounded, hop-limited — when there is no cell tower at all, independent of Gemma entirely. And a minimal Firestore backend (anonymous auth, offline-persistent, explicitly online-only) syncs campaign requests, broadcasts, and safety reports to an admin coordination panel, so relief coordinators see a live cross-device picture once connectivity returns, without ever gating the core single-phone emergency loop on a backend existing at all.

The result: 149 Dart files, roughly 38,000 lines of application code, 78 test files and 611 automated unit and widget tests, a clean `flutter analyze`, and an APK deliberately restricted to `arm64-v8a` because `.litertlm` inference requires it.

## Technical Challenges We Solved

Building a real on-device LLM pipeline surfaced sharp, specific bugs no tutorial covers. The LiteRT-LM FFI seed parameter is a signed 32-bit integer; seeding it from a microsecond timestamp silently overflowed and truncated negative roughly half the time, degrading sample diversity — fixed by masking to the low 31 bits. Enabling Gemma's "thinking" mode on the `.litertlm` path streamed raw `<|channel|>thought` tokens directly into the user-facing string with no API to separate them, occasionally producing a blank reply bubble; we disabled thinking mode entirely rather than ship an unreliable UX. Bangla voice input silently failed because Android's speech recognizer requires strict BCP-47 locale tags (`bn-BD`) while the codebase used the POSIX form (`bn_BD`) everywhere — a one-character bug with an outsized user-facing effect. Repetition loops in longer generations were tamed not by prompt engineering but by tuning temperature, top-K, and top-P together, since the runtime exposes no stop-string API to cut a response short.

## Real-World Impact

Shongjog targets a recurring, high-stakes, national-scale failure: the exact hours when guidance is needed most are the hours connectivity is guaranteed to be gone. Because inference runs on-device, serving another query costs nothing at the margin — a precondition for reaching rural, low-income, and disaster-displaced users that no per-request cloud API can meet at that scale. Voice access and Bangla-native design extend that reach to low-literacy and elderly users typically excluded from app-based disaster tools. Because voice, GPS, and health details never leave the phone, it asks nothing of users already in crisis except their language.

## User Experience & What's Next

The interface uses a single locked "Deep Ocean Blue" hue with AAA-contrast light and dark ramps and Hind Siliguri typography, so the calmest possible visual register survives a moment when the user is not calm. Giant yes/no triage buttons, Bengali numerals throughout, and auto-read text-to-speech remove reading and fine-motor precision from the critical path. Next: a professionally reviewed and expanded corpus with BDRCS, on-device multimodal triage once `.litertlm` exposes vision, additional Bangla dialects, and community-verified shelter data.

## Repository & Demo

**Code (public GitHub repository):** https://github.com/Ahnaf181419/shongjog — complete source, README with setup/run instructions, full dependency list via `pubspec.yaml`, and extensive internal documentation under `docs/` (architecture, product requirements, corpus policy, demo script).

**Demo:** [demo video link — to be added] recorded per the five-scenario script in `docs/guides/demo.md`: static quick cards with no model loaded, a spoken Bangla query answered fully in airplane mode, snakebite myth-busting, GPS-based nearest-shelter lookup, and one-tap 999 dial — the airplane-mode reveal is the single proof point that makes the offline claim self-evident rather than asserted.
