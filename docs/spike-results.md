# Shongjog — Spike Results & Validation Log

> **Internal team-facing document.** Live-record of every spike run, every airplane-mode
> demo session, every on-device measurement. Use this when answering judge questions and
> when deciding whether a feature is demo-ready.

Companion docs: build tasks in `docs/implementation-plan.md`; demo script in `docs/demo.md`;
architecture in `docs/architecture.md`.

---

## How to use this file

Every block under a numbered Phase section is a *measurement record*. Append to it; never
delete prior data. Each block has:

- **What was tested** — the question this spike answers
- **Date / device / build** — reproducibility
- **Steps run** — exact commands
- **Numbers** — measured values, not estimates
- **Verdict** — 🟢 ship / 🟡 ship with mitigation / 🔴 pivot
- **Action items** — what this spike triggers

If a spike comes back 🟡 or 🔴, the action items *must* be addressed before the next phase
starts. A 🟢 spike can still produce improvement notes — append them under "Notes".

---

## Phase 0 — Validation Spikes

### Spike A: Gemma 4 E2B on arm64 (Task 0.1)

**What was tested:** Can `flutter_gemma` load the Gemma 4 E2B 4-bit `.task` file on a
real arm64 Android phone, and is the inference latency acceptable for crisis guidance?

**Date / device / build:** _PENDING — push section below when running_

**Steps run:**

```bash
adb shell getprop ro.product.cpu.abi
# Expected: arm64-v8a

adb push gemma-4-e2b-int4.task /data/local/tmp/shongjog/

adb shell svc wifi disable
adb shell svc data disable

cd tools/spike_gemma
flutter run -d <device-id> --release
```

**Prompts:**

| # | Prompt | Ground-truth answer shape |
|---|---|---|
| 1 | "তুমি কি বাংলায় কথা বলতে পারো? একটি বাক্যে উত্তর দাও।" | বাংলায় হ্যাঁ/সক্ষমতার বাক্য |
| 2 | "ORS কীভাবে বানাতে হয়? ৩টি ধাপে বলো।" | ৩টি সংখ্যাযুক্ত বাংলা ধাপ |
| 3 | "রক্তপাত বন্ধ করার সবচেয়ে গুরুত্বপূর্ণ কাজ কী?" | "চাপ প্রয়োগ করা" বা সমতুল্য |

**Measurements to record:**

| Metric | Target | Measured | Verdict |
|---|---|---|---|
| Cold start to first token | ≤ 15s | _ | _ |
| Steady-state token/s | ≥ 8 tok/s | _ | _ |
| RAM peak (`dumpsys meminfo`) | ≤ 2.0GB | _ | _ |
| Disk after model load | ≤ 1.8GB | _ | _ |
| First prompt response quality | Comprehensible Bangla, no English drift | _ | _ |
| Streamed token coherence | Each token Bangla, no garbled characters | _ | _ |

**Commands:**

```bash
# Cold start timing (in spike app or logcat)
adb logcat | grep -E "FlutterGemma|LiteRT"
adb shell dumpsys meminfo | grep -A 5 shongjog
```

**Verdict:** _ / _ / _

**Action items triggered:**

- [ ] If 🟢: proceed with Phase 3.1 wiring into ChatRepository
- [ ] If 🟡 (e.g. 15-25s cold start): document as "acceptable for demo" or move to
      Gemma 3 1B
- [ ] If 🔴 (OOM, never loads): pivot to Gemma 3 1B, rebuild `ModelManager` URL and
      metadata; re-run spike

### Spike B: Vosk Bangla WER (Task 0.2)

**What was tested:** Is `vosk-model-small-bn-0.22` accurate enough on our 10 target
emergency utterances?

**Date / device / build:** _PENDING_

**Steps run:**

```bash
mkdir -p assets/vosk
curl -L -o /tmp/vosk-bn.zip \
  https://alphacephei.com/vosk/models/vosk-model-small-bn-0.22.zip
unzip /tmp/vosk-bn.zip -d /tmp/
mv /tmp/vosk-model-small-bn-0.22/* assets/vosk/

adb shell svc wifi disable
adb shell svc data disable
```

**10 utterances** (from `tools/spike_vosk/test_transcripts.txt`):

```
1.  আমার বাচ্চার ডায়রিয়া হয়েছে
2.  সাপে কামড়েছে কি করবো
3.  বিশুদ্ধ পানি কিভাবে বানাবো
4.  ঘর থেকে বের হতে পারছি না পানিতে
5.  ঝড়ের সময় কোথায় আশ্রয় নেবো
6.  শিশুকে কি খাওয়াবো বমি হচ্ছে
7.  ORS কিভাবে বানাবো
8.  আমি আটকে আছি ছাদে
9.  রক্তপাত বন্ধ হচ্ছে না
10. জ্বর হয়েছে প্রচণ্ড
```

**Measurements to record:**

| Utterance | Expected | Actual | WER | Latency |
|---|---|---|---|---|
| 1 | _ | _ | _ | _ |
| 2 | _ | _ | _ | _ |
| 3 | _ | _ | _ | _ |
| ... | _ | _ | _ | _ |

**Average WER:** _ / 100 (total edits / total words)

**Verdict:** _ / _ / _

**Action items triggered:**

- [ ] If 🟢 (avg WER < 0.3): wire `VoskSttProvider` into `SttService` as primary offline
- [ ] If 🟡 (0.3 ≤ WER < 0.5): use Vosk for command-style phrases only (ORS, snakebite,
      shelter); fall back to typed input for freeform
- [ ] If 🔴 (WER ≥ 0.5): accept typed-input-only in the demo; document honestly to judges

### Spike C: Shelter GeoJSON spot-check (Task 0.3)

**What was tested:** Are the bundled shelter locations plausible for the demo region?

**Date / device / build:** _PENDING_

**Source attribution:**

| Source | URL | Date accessed |
|---|---|---|
| _ | _ | _ |

**5-spot-check coordinates:**

| # | Name (Bangla) | Lat | Lon | Plausible? |
|---|---|---|---|---|
| 1 | _ | _ | _ | ☐ |
| 2 | _ | _ | _ | ☐ |
| 3 | _ | _ | _ | ☐ |
| 4 | _ | _ | _ | ☐ |
| 5 | _ | _ | _ | ☐ |

**Verdict:** _ / _ / _

---

## Phase 5 — Demo Hardening Measurements

### Cold-start to first answer (≤ 15s target)

**Test device:** _  
**Build:** _  
**Date:** _  

| # | Run | Time | Notes |
|---|---|---|---|
| 1 | _ | _s | fresh install, no model cached |
| 2 | _ | _s | model cached on disk |
| 3 | _ | _s | warm app restart |
| 4 | _ | _s | cold phone restart |
| 5 | _ | _s | representative |
| **Avg** | | _s | |

**Verdict:** _

### Steady-state Q → A (≤ 8s target)

**Test device:** _  
**Build:** _  
**Date:** _  

Query: "আমার বাচ্চার ডায়রিয়া হয়েছে, কি করবো?"

| # | Run | Time | Tokens |
|---|---|---|---|
| 1 | _ | _s | _ |
| 2 | _ | _s | _ |
| 3 | _ | _s | _ |
| 4 | _ | _s | _ |
| 5 | _ | _s | _ |
| **Avg** | | _s | |

**Verdict:** _

### TTS first audio (≤ 500ms target)

**Test device:** _  
**Build:** _  
**Date:** _  

| # | Run | Time | Voice |
|---|---|---|---|
| 1 | _ | _ms | bn-BD |
| 2 | _ | _ms | bn-BD |
| 3 | _ | _ms | bn-BD |

**Verdict:** _

### Shelter GPS resolve (≤ 5s target)

**Test device:** _  
**Build:** _  
**Date:** _  

| # | Run | Time | GPS permission status |
|---|---|---|---|
| 1 | _ | _s | granted |
| 2 | _ | _s | granted |
| 3 | _ | _s | denied → fallback |

**Verdict:** _

### STT end-to-end (typed input not allowed, mic only)

**Test device:** _  
**Build:** _  
**Date:** _  

| # | Utterance | Recognized | Correct? |
|---|---|---|---|
| 1 | আমার বাচ্চার ডায়রিয়া হয়েছে | _ | ☐ |
| 2 | সাপে কামড়েছে কি করবো | _ | ☐ |
| 3 | বিশুদ্ধ পানি কিভাবে বানাবো | _ | ☐ |
| 4 | ORS কিভাবে বানাবো | _ | ☐ |
| 5 | ঝড়ের সময় কোথায় আশ্রয় নেবো | _ | ☐ |

**Verdict:** _

### 999 dial + SOS SMS end-to-end

**Test device:** _  
**Build:** _  
**Date:** _  

| Action | Status | Notes |
|---|---|---|
| Slide-to-confirm ≥ 90% triggers dial | ☐ pass ☐ fail | |
| Slide knob spring-back < 90% | ☐ pass ☐ fail | |
| 999 dialer opens with prefilled number | ☐ pass ☐ fail | |
| SOS SMS body contains name | ☐ pass ☐ fail | |
| SOS SMS body contains phone | ☐ pass ☐ fail | |
| SOS SMS body contains lat | ☐ pass ☐ fail | |
| SOS SMS body contains lon | ☐ pass ☐ fail | |
| SOS SMS body contains maps URL | ☐ pass ☐ fail | |
| GPS link opens in Maps app | ☐ pass ☐ fail | |

**Verdict:** _

---

## Phase 5 — Airplane-Mode End-to-End Run Log

Run after each successful +1 hour of work on a real device. Append a new row per run.

| Date | Device | Build | Cold (s) | Q→A (s) | All 5 scenarios pass? | Notes |
|---|---|---|---|---|---|---|
| _ | _ | _ | _ | _ | ☐ | |

**5 scenarios:**

1. Quick cards render (no model needed)
2. Voice query → grounded spoken answer
3. Snakebite do/don't
4. Nearest shelter via GPS
5. One-tap dial 999

---

## Phase 5 — Demo-Day Attempts

Append a row per attempt on demo day. Note any flakiness for post-mortem.

| Time | Attempt | Outcome | Notes |
|---|---|---|---|
| _ | _ | ☐ success ☐ fallback used | |

---

## Phase 5 — Post-Demo Findings

(Add bullets as issues surface during Q&A or after.)

- _

---

## Appendix A — Inference timing instrumentation locations

If measuring inference performance, instrument these sites:

```dart
// lib/features/chat/chat_repository.dart
// ask() — total wall-clock time from query received to answer ready
final sw = Stopwatch()..start();
final answer = ...;
debugPrint('[chat.ask] query=${q.text} ttr=${sw.elapsedMilliseconds}ms');
```

```dart
// lib/core/model_manager.dart
// initialize() — cold start time (first model load)
final sw = Stopwatch()..start();
await FlutterGemma.instance.initialize(...);
debugPrint('[model.init] ttr=${sw.elapsedMilliseconds}ms');
```

```dart
// lib/rag/retriever.dart
// topK() — retrieval latency (sub-ms expected)
final sw = Stopwatch()..start();
final hits = topK(query);
debugPrint('[retriever] n=${chunks.length} t=${sw.elapsedMicroseconds}μs');
```

---

## Appendix B — Reproducibility

- **Lockstep model file:** every team member uses the same `gemma-4-e2b-int4.task`
  sha256. Record it once below and never change it.

| Artifact | sha256 |
|---|---|
| `gemma-4-e2b-int4.task` | _ |
| `vosk-model-small-bn-0.22` | _ |

- **Build hash:** every device run logs the commit hash. Check
  `adb logcat | grep shongjog` for `version.commit`.
