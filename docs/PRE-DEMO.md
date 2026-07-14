# Shongjog — Pre-Demo Operational Runbook

> **Internal team-facing document.** Everything needed to take the app from "code complete"
> to "demo-ready on stage, tonight or tomorrow morning." This document is the *operational*
> checklist that complements the *narrative* demo script in `docs/demo.md`.

Companion docs: `docs/demo.md` (live script), `docs/spike-results.md` (measurements),
`docs/architecture.md` (technical reference).

---

## Phase 1 — Code complete

✅ = verified by automated / static checks; 🟦 = verified by manual run on device.

### Code quality gates (must ALL pass)

```bash
flutter pub get
flutter analyze                        # must report "No issues found"
flutter test                           # must show 91 pass, 1 skip
```

### Build verification

```bash
flutter build apk --release            # arm64-v8a only
flutter build appbundle --release      # for Play submission (post-hackathon)
```

### Git hygiene (no demo-day surprises)

```bash
git status                             # clean working tree
git log --oneline -10                  # all work committed
git tag hackathon-final vX.Y.Z         # tag the demo build
```

### Repo artifacts to verify

- [ ] `lib/` has no commented-out code or TODO comments in critical paths
- [ ] `assets/kb/corpus.json` is current (23 chunks)
- [ ] `assets/kb/vectors.bin` is current (matches corpus via tools/verify_kb.py)
- [ ] `assets/kb/meta.json` reflects the same build
- [ ] `assets/shelter/cyclone_shelters.geojson` spot-checked
- [ ] `assets/fonts/HindSiliguri-*.ttf` bundled
- [ ] `assets/sound/chime.wav` and `knock.wav` present (auto-no-op if missing — check
      `sound_service.dart` confirms)
- [ ] `assets/vosk/` populated (if Vosk is online path); otherwise `VoskSttProvider` stub
      remains

---

## Phase 2 — Device setup (the night before)

### Required hardware

- 1× **primary demo Android phone** (arm64-v8a) — owned by Ahnaf
- 1× **backup phone** with same APK + model file pre-loaded (per teammate)
- USB-C cable(s) for adb access
- Power bank (≥ 10,000 mAh)
- HDMI / wireless display adapter for projector
- Chargers for each device

### Software on the primary device

| App / setting | Value |
|---|---|
| Android version | ≥ 10 (TTS voice availability varies; test bn-BD) |
| Bangla language installed? | Yes (`Settings → System → Languages → Add → বাংলা`) |
| Locale set to `bn-BD` | System → Languages → move to top |
| TTS engine | Google Speech Services (default on most devices), bn-BD voice downloaded |
| Developer options | Enabled (tap Build Number 7×) |
| USB debugging | ON |
| Battery saver | OFF (limits background work) |
| Bluetooth | OFF (avoid TTS redirect to paired devices) |
| Wi-Fi | OFF during demo (proof of offline) |
| Mobile data | OFF during demo (proof of offline) |
| Airplane mode | ON during demo |
| Notifications | DND on |
| Brightness | ≥ 70% (stage lighting washes out dim screens) |
| Location | ON, high accuracy |
| Microphone permission for Shongjog | Granted |

### Model pre-load verification

After installing the APK, verify the model file is present and recognized by the app:

```bash
adb shell run-as com.shongjog sh -c 'ls -lh files/gemma4_e2b_int4.task'
# Should show ≥ 1,500,000,000 bytes
```

In-app verification:
- Launch app → onboarding appears (or skips if already completed)
- Quick cards work instantly
- AI tab: tap "এআই প্রস্তুত করুন" (or similar) if model not detected → wait ≤ 15s
  for AppBar subtitle "AI প্রস্তুত" status
- AppBar subtitle should read "AI প্রস্তুত" when ready

### Vosk verification (if Vosk is the active STT)

- Mic permission granted
- Tap mic on chat screen, speak "আমার বাচ্চার ডায়রিয়া হয়েছে"
- Transcript appears in input field

### Fallback verification (if Vosk unavailable)

- App uses `SpeechToTextProvider` (online) as default
- Mic still works, but needs network
- **Demo fallback**: turn off airplane mode briefly to allow STT, then turn back on
  for Q&A — document this honestly to judges

---

## Phase 3 — Demo-day morning (3 hours before)

### Airplane-mode end-to-end rehearsal

Run all 5 demo scenarios from `docs/demo.md` twice through. Record timings in
`docs/spike-results.md` § Phase 5.

**Verification:**

- [ ] Scenario 1: Cards render, expand → Bangla steps
- [ ] Scenario 2: Voice → answer (typed fallback if mic flaky)
- [ ] Scenario 3: Snakebite — confirm "কাটবেন না" appears in answer
- [ ] Scenario 4: GPS resolves, shelters appear with km distance
- [ ] Scenario 5: Slide ≥ 90% triggers dial; < 90% springs back

### Backup capture

Record screen with `adb shell screenrecord`:

```bash
adb shell screenrecord --bit-rate 8000000 --time-limit 180 /sdcard/demo-rehearsal.mp4
adb pull /sdcard/demo-rehearsal.mp4 docs/demo-rehearsal-$(date +%Y%m%d).mp4
```

### Fallback video

Record the 5-scenario flow trimmed to 60 seconds. Add Bangla subtitles. Save as
`docs/demo-fallback.mp4`. Test on:

- [ ] Demo phone's gallery app (no player download needed)
- [ ] Mirrored to projector (video, not screen share)
- [ ] Offline playback (airplane mode ON, still works)

### Backup phones in sync

All backup devices must have:
- [ ] Same APK build (commit hash matches)
- [ ] Same `gemma-4-e2b-int4.task` sha256
- [ ] Same shared_preferences defaults cleared

### Projector / screen-mirror setup

- [ ] Test wireless cast on actual venue WiFi (or via adapter)
- [ ] Verify Bangla text renders crisply on projector (no anti-aliasing artifacts)
- [ ] Test phone speaker audio (not headphones)
- [ ] Verify mic picks up your voice from standing position

### Power and ambient

- [ ] Demo phone ≥ 80% battery
- [ ] Power bank plugged in
- [ ] Brightness at 70%+
- [ ] Phone in landscape-stable orientation or hand-held
- [ ] No phone calls scheduled

---

## Phase 4 — Demo-day runtime (just before taking the stage)

### 5 minutes before: zero-state reset

```bash
# Watch the logcat for the model manager
adb logcat -c
adb logcat | grep -E "shongjog|flutter_gemma|GemmaLiteRT|ModelManager"
```

- [ ] Open app — landing on Home or AI tab (whichever you set as initial route)
- [ ] Quick tap through tabs to verify they're responsive (no jank)
- [ ] Quick voice test: tap mic, say "তৈরি", verify partial transcript appears
- [ ] Slide-to-dial test: tap emergency icon, drag knob to 50%, release — verify
      spring-back (no accidental 999)
- [ ] Turn airplane mode ON
- [ ] Power bank plugged in

### Pre-demo announcement to judges

> "I want to be honest before we start: we're running this in airplane mode.
> The model is already on the device. Everything you'll see is local."

This sets expectations and creates the reveal moment in the script.

### During demo

- **If voice fails**: silently type the query, narrate, "I'll type this so you can read
  it." Do NOT apologize at length.
- **If model hangs > 15s**: "Let me switch to a previous run, this kind of cold cache
  is exactly why we built a fallback video." → fire up `docs/demo-fallback.mp4`.
- **If GPS fails**: "GPS denied — that's actually a feature. Watch what happens." →
  confirm Bangladesh default map renders with disclaimer banner.
- **If answer is wrong**: "This is exactly why we built the static cards as a
  safety net." → open cards tab. Never argue with the model in front of judges.

### Post-demo hygiene (within 30 minutes)

- [ ] Save `adb shell screenrecord` capture to `docs/demo-live-$(date).mp4`
- [ ] Capture all spike timing data into `docs/spike-results.md`
- [ ] Note any judge questions into `docs/spike-results.md` §Post-Demo Findings
- [ ] Tag the submission commit: `git tag hackathon-final v1.0.0`
- [ ] Commit any post-demo cleanups

---

## Phase 5 — Common failure modes & pre-staged fixes

| Failure | Cause | Pre-staged fix |
|---|---|---|
| 999 dialer doesn't open | url_launcher permission issue on OEM | Show `tel:999` call link in emergency sheet as fallback |
| TTS silent | `bn-BD` voice not installed | Pre-install on device; fallback to `bn-IN`; bare-fallback to on-screen text only |
| Chat bubble empty after submit | Embedder hangs / Cloud timeout | Try-catch in ChatRepository → canned response; status bar "আমি নিশ্চিত নই" |
| Shelter map blank | OSM tile cache empty, no network | `cached_tile_provider.dart` shows styled background; offline markers still overlay |
| Vosk crashes at startup | `vosk_flutter` plugin compileSdk issue | Falls back to `SpeechToTextProvider` (online) silently; demo flow uses typed input |
| Model file missing | APK didn't pre-bundle | Tell user to download: "If you'd like to try offline mode, here's the model" — defer to live internet |
| Phone freezes mid-demo | OOM from background services | Reboot phone; show fallback video while restarting |
| Auto-rotate changes layout | Settings → Display | Set to portrait lock on demo phone |

---

## Phase 6 — Build artifacts to package for judges

After the live demo:

```
shongjog-submission/
├── README.md
├── docs/                       # all project docs
├── apk/Shongjog-v1.0.0-release.apk
├── models/gemma-4-e2b-int4.task.sha256.txt  # pointer to download
├── demo/demo-fallback.mp4      # 60s airplane-mode recording
├── demo/demo-live.mp4          # screen recording of actual demo
└── LICENSE                      # Apache 2.0 (or team choice)
```

A judge should be able to inspect the docs, install the APK, point to the model file
(already on their device if part of the Bangla test pool), and reproduce the demo offline.

---

## Phase 7 — Post-demo reflection (within 24h)

- What went well? (Refine and amplify.)
- What flaked? (Fix the root cause, not the symptom.)
- Which judge questions stumped the team? (Add to FAQ.)
- Which features got the most "wow"? (Keep these.)
- Which features got "is this actually safe?" (Strengthen corpus / disclaimers.)
- Onboard a BDRCS or MoDMR contact if possible — that's the corpus-review path.

Use `docs/POST-HACKATHON.md` for the longer-term roadmap.
