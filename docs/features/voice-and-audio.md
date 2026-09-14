# Voice & Audio Architecture

Shongjog is engineered as a **voice-first** emergency companion, recognizing that in high-stress crisis conditions, users may be injured, visually impaired, illiterate, or unable to type on touchscreens while fleeing.

```
                              [ User Speaks (Bangla / English) ]
                                               │
                                               ▼
                                   [ SttService Orchestrator ]
                                               │
                        Is Vosk Offline Model available & compiled?
                                  ├──► YES ──► VoskSttProvider (True Offline Recognition)
                                  │
                                  ▼ NO
                      [ SpeechToTextProvider (Online Platform Fallback) ]
                          (Normalizes bn-BD ──► bn-IN ──► System Default)
                                               │
                                               ▼
                                     [ Text Transcript ]
                                               │
                                     [ LLM / RAG Processing ]
                                               │
                                     [ Response Generated ]
                                               │
                                               ▼
                                      [ TtsService Output ]
                     (Crisis-Tuned: Rate 0.45 [0.9x], Volume 1.0, Auto-Locale)
```

---

## 1. Speech-to-Text Architecture (`SttService`)

The voice input pipeline is managed through an abstract provider pattern ([`lib/features/voice/stt_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/voice/stt_service.dart)):

### Engine Providers & Fallback Hierarchy

1. **Vosk Offline STT (`VoskSttProvider`)**:
   - **Target**: Intended to provide 100% offline acoustic speech recognition using a small, quantized ~40MB Bangla acoustic model bundled in `assets/vosk/model-bn/`.
   - **Current Milestone Status (Known Upstream Issue)**: The upstream plugin `vosk_flutter: 0.1.2` contains a hardcoded `compileSdk 33` constraint in its internal Android build script. Because the Shongjog root app uses Android Gradle Plugin (AGP) 9.x targeting `compileSdk 36`, the native Vosk bridge fails compilation. `VoskSttProvider.isModelBundled()` currently returns `false` until an AGP 9.x compatible fork is integrated.
2. **Platform Speech Recognizer (`SpeechToTextProvider`)**:
   - Primary active fallback using the device native `SpeechRecognizer` (Google STT on Android, Siri on iOS).
   - Requires network connectivity on some OEM builds, but runs locally if the OEM packages an offline Bangla speech pack.

### Bangla Locale Resolution & Normalization

Engines report locale IDs inconsistently across Android OEMs (`bn_BD`, `bn-BD`, `bn`, `bn_IN`). The `resolveLocale` method normalizes and resolves requests:
1. Exact match (`bn-BD`).
2. Same language, alternate region (`bn-IN` will still recognize Bengali phonemes).
3. Fallback to system default if Bangla is entirely absent on the phone (preventing a silent failure where the microphone button does nothing).

### Error Classification (`SttFailure`)
The service classifies platform error strings into actionable UI states:
- `languageUnavailable`: Prompts user to download Google Voice Bangla language pack.
- `networkRequired`: Informs user that the device's built-in STT requires internet.
- `permissionDenied`: Displays direct permission prompt for `RECORD_AUDIO`.
- `noMatch` / `speechTimeout`: Graceful retry prompt.

---

## 2. Text-to-Speech Engine (`TtsService`)

The TTS service ([`lib/features/voice/tts_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/voice/tts_service.dart)) renders spoken responses:

- **Crisis-Tuned Audio Parameters**:
  - **Speech Rate**: Set to `0.45` (~0.9x speed) to maximize comprehension for distressed or elderly listeners.
  - **Volume**: Forced to `1.0` (maximum system volume) for loud ambient disaster environments (storm winds, heavy rain, siren noise).
  - **Pitch**: Standard `1.0` for natural tone.
- **Locale-Adaptive Switching**:
  - When the user is in Bangla mode, TTS selects `bn-BD` (fallback `bn-IN`).
  - When the user toggles English mode, TTS dynamically re-binds to `en-US` (fallback `en-GB`), preventing English words from being mispronounced by a Bengali phonetic engine.
- **Opt-In Auto-Read**: Users can toggle `pref_auto_read` in Settings to have every AI response spoken aloud automatically upon generation.

---

## 3. Off-Grid P2P Mesh Voice Calling

Distinct from voice assistant STT/TTS, Shongjog includes a real-time voice calling service ([`lib/features/mesh_comm/mesh_call_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/mesh_comm/mesh_call_service.dart)) operating over Nearby Connections:

- **Audio Pipeline**: Records and streams uncompressed **8,000 Hz, 16-bit Mono PCM**.
- **Bandwidth Profile**: ~16 KB/sec, well within the throughput constraints of Bluetooth Classic and Wi-Fi Direct peer-to-peer links.
- **Call State Machine**: Manages incoming call handshakes (`idle`, `ringing`, `connected`, `ended`) and deduplicates incoming signals to prevent call screen multi-stacking.
