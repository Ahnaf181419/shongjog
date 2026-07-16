# AI Feature Candidates — Deepening Gemma, Not Widening Scope

**Selection rule:** every feature here exploits a **specific Gemma 4 capability you already ship but don't use**. Nothing generic. Nothing that could be done with a keyword search or an API wrapper.

**Pick 2–3. Shipping three deeply beats shipping eight shallowly — and eight shallow features will cost you the fine-tune and the evals, which are worth more than all of them combined.**

Capabilities you're currently under-using: **native audio input**, **vision**, **configurable thinking mode**, **128K context**, **function calling**.

---

## Tier 1 — Highest leverage. Choose from here first.

### 1. Adaptive Thinking Mode (reflex vs. deliberation)
**Gemma 4 capability:** configurable thinking mode — a headline Gemma 4 feature.

Emergencies aren't uniform in how much thought they deserve. Choking, arterial bleeding, and drowning need an answer in **two seconds** — thinking mode off, retrieve, fire. Multi-symptom triage ("fever, rash, and she's confused, three days after the flood") deserves **reasoning** — thinking mode on.

So route it: the hazard/urgency classifier picks the compute budget. **Reflex path** for time-critical Response-phase queries; **deliberate path** for ambiguous, multi-symptom, or Recovery-phase ones.

**Why it's strong:** this is *adaptive compute allocation on-device, driven by clinical urgency.* It's a real systems-design idea, it's Gemma-4-specific, it costs almost nothing to implement (you already have the router), and it produces a killer eval chart: **latency vs. urgency**. It also directly answers "why does a 2B model matter here?" — because you can afford to think when it counts and not when it doesn't.

**Effort:** Low. **Demo value:** High. **Do this one.**

---

### 2. Native Audio Input (delete your STT layer)
**Gemma 4 capability:** E2B/E4B accept **native audio input**.

Right now you pipe audio → device STT → text → Gemma. That loses everything non-lexical and adds a failure point that's weak on rural dialects.

Feed the audio **straight to Gemma** instead. You gain:
- **Dialect robustness** — a general audio model tends to beat a narrow Bangla STT on regional speech.
- **Paralinguistic signal** — panic, breathlessness, a screaming child, wind and rain in the background. A person gasping between words is triage-relevant information that STT deletes.
- **Architectural elegance** — two models collapse into one. Less RAM, fewer moving parts, one fewer thing that breaks offline.

**Why it's strong:** "We removed the speech-to-text layer because Gemma hears better than it transcribes" is a sentence no other team will write. Keep device STT as a fallback and **A/B them in your eval** — dialect accuracy, base vs. native audio. That comparison is publishable-grade for a hackathon.

**Effort:** Medium. **Demo value:** Very high (speak in dialect, in the rain). **Risk:** verify E2B audio quality on Bangla before committing a day.

---

### 3. Offline Rumour & Misinformation Check
**Gemma 4 capability:** grounded reasoning over your corpus.

This is the feature the Shongjog research is *begging* you to build. Rumour control is the central problem of Communication with Communities — BBC Media Action literally named a programme **"Soiyi Hota" ("correct information")** for it. During disasters, misinformation spreads faster than help: *drink this to cure cholera, the shelter is full, cut the snakebite, the water's fine now.*

Feature: **"Someone told me X — is it true?"** Gemma checks the claim against the verified corpus and returns **confirm / correct / not-covered**, with the source.

**Why it's strong:** it's a *different query type*, not a wider hazard list — genuine depth. It maps onto the myth-correction hard negatives you're already building for the fine-tune, so the training data is nearly free. It directly serves the national CwC mission, which makes your framing land with anyone from DDM or BDRCS. And it's **the purest offline argument in the whole app**: you cannot fact-check a rumour by searching the web when the tower is down. Only a local model can.

**Effort:** Low–Medium (mostly prompt + fine-tune + a UI entry point). **Demo value:** Very high. **This is your sleeper hit.**

---

### 4. Structured SOS via Function Calling
**Gemma 4 capability:** native function calling.

A panicking person writes a terrible emergency message. Gemma turns their rambling voice input into a **structured dispatch report** — location, hazard, phase, casualty count, injuries, immediate needs, access notes — formatted for a 999 operator and sent as **SMS** (which survives when data doesn't).

**Why it's strong:** it flips the beneficiary. Everything else in your app helps the *victim*; this helps the *responder*, and responders are drowning in unstructured calls. It makes function calling load-bearing rather than decorative. And it's a rare feature that's *better* because it's offline-first.

**Effort:** Low–Medium. **Demo value:** High — showing a clean structured SMS composed from panicked speech is memorable.

---

## Tier 2 — Strong, but only if Tier 1 is solid.

### 5. Vision Triage (pick ONE subject, not five)
**Gemma 4 capability:** vision, all sizes.

Options, best first:
- **Medicine strip identification** — people grab medicines while evacuating and don't know what they are, and the pharmacy is gone. Photo → what it is, what it's for, obvious cautions. **Novel, useful, and low-drama.** Nobody has built this.
- **Wound assessment** — infection signs, escalate-or-not.
- **Water clarity** — is this safe, how do I treat it.
- **Building damage** — safe to re-enter after a quake/flood?
- **Snake identification** — ⚠️ **avoid.** Species ID drives treatment decisions; a 2B model getting this wrong could kill someone. If you must, output *only* generic snakebite protocol regardless of the photo.

**Rule:** one subject, done well, framed strictly as **assessment support, never diagnosis.** A shaky vision feature is worse than none.

**Effort:** Medium. **Demo value:** High.

---

### 6. Full-Context Fallback for Hard Cases
**Gemma 4 capability:** **128K context** on E2B.

Your entire corpus is ~80–120 chunks. **That probably fits in context.** So: RAG for the fast path; when retrieval confidence is low or the query spans hazards (earthquake → fire → burns), **skip retrieval and put the whole corpus in the prompt.**

**Why it's strong:** it's a genuinely interesting architectural point — *"our corpus is small enough that retrieval is an optimization, not a necessity"* — and it directly attacks your #1 technical risk (cross-hazard retrieval confusion). Pairs naturally with adaptive thinking: hard case → full context + thinking on.

**Effort:** Low. **Demo value:** Low (invisible). **Writeup value:** High. Cheap to try, measure it in the eval.

---

### 7. Personalised Preparedness Plan (uses your new `phase` axis)
Short conversation — how many children, elderly, pregnant, livestock, pucca or kutcha house, distance to shelter — and Gemma generates a **household-specific** prep checklist and evacuation plan, stored offline.

**Why it's strong:** it's the answer to *"why is this app on my phone in February?"* — your retention argument made concrete. It exercises the Preparedness phase you just added. And it makes the 1.5GB download rational: people install it **before** the flood.

**Effort:** Low–Medium. **Demo value:** Medium. **Strategic value:** High — it closes the loop on your strongest pitch.

---

## Tier 3 — Future work. Name them; don't build them.

- **Mesh relay** — Bluetooth/Wi-Fi Direct sharing of alerts and corpus between phones when towers are down; Gemma compresses situation reports to packet size. Genuinely exciting, far too big for 10 days.
- **Mass-casualty triage (START)** — who to help first. Ethically heavy, needs real clinical governance.
- **Symptom progression tracking** — log over days in Recovery, flag deterioration.
- **Register adaptation** — same content re-voiced for a child, an elder, a low-literacy user.

Listing these in the writeup shows vision. Building them shows poor judgment.

---

## Recommended Combination

**Ship: #1 Adaptive Thinking + #3 Rumour Check + #4 Structured SOS.**

They're all low-to-medium effort, they share the router and the fine-tune dataset you're already building, and together they tell one coherent story:

> *Gemma thinks harder when it matters, corrects lies when no one can fact-check, and speaks clearly to responders when the person can't — all with the tower down.*

Add **#2 Native Audio** if the E2B Bangla audio test passes early. Add **#5 Medicine Strip** only if you're ahead on Day 8.

**Do not let any of this displace the fine-tune, the evals, the device matrix, or Days 9–10.** Those are still worth more than every feature on this page.
