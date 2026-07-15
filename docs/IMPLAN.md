# Shongjog — Multi-Tier AI System Implementation Plan

> Comprehensive plan for upgrading Shongjog's chat system to a 5-tier intelligent
> fallback chain with personalization, smart notifications, and model marketplace.

Companion docs: `docs/POST-HACKATHON.md` (tech debt), `docs/architecture.md` (system design),
`AGENTS.md` (hard constraints).

---

## Overview

### Current System (3-tier)
```
Cloud AI (gemma-4-31b-it / gemini-3.1-flash-lite) → Local Gemma E2B → RAG corpus → Canned 999
```

### Target System (5-tier)
```
Tier 1: Gemma 4 API (Google AI Studio) — online, user-provided API key
Tier 2: Gemini 3.1 Flash Lite — online, cloud fallback
Tier 3: Local Gemma 4 E2B/E4B/12B — offline, device-capable
Tier 4: RAG corpus (keyword retrieval) — always available
Tier 5: Canned 999 response — last resort
```

### Key Design Decisions
- **Cloud is primary** (when online + API key present), local is offline fallback
- **Personality**: Chillnatural, helpful, joyful, friendly — no restrictions
- **Languages**: Bangla, English, Banglish — user chooses, assistant follows
- **Hardware detection**: Auto-select best model based on RAM (E2B/E4B/12B)
- **Personalization**: On-device only, preference summaries in system prompts

---

## Phase 1: Cloud AI Overhaul

### 1.1 Fix deprecated model IDs
**File**: `lib/features/cloud_ai/cloud_ai_service.dart`
- `gemini-2.0-flash-lite` → `gemini-3.1-flash-lite` (deprecated June 1, 2026)
- Keep `gemma-4-31b-it` as primary (already correct)

### 1.2 Fix auto-read default
**Files**: `lib/features/chat/chat_screen.dart:82`, `lib/features/settings/settings_screen.dart:42`
- Change `?? true` to `?? false` for `pref_auto_read`
- **Hard constraint** from AGENTS.md: no auto-read TTS without opt-in

### 1.3 Runtime API key storage
**New file**: `lib/core/api_key_store.dart`
- Uses `flutter_secure_storage` for encrypted on-device key storage
- Methods: `saveKey(key)`, `getKey()`, `hasKey()`, `deleteKey()`
- Key stored under `'gemini_api_key'` label
- **Why**: User has an API key but current system requires `--dart-define` at compile time

### 1.4 Add dependencies
**File**: `pubspec.yaml`
- Add `flutter_secure_storage: ^9.2.0` for encrypted key storage
- `device_info_plus` already present — will be used for hardware detection in Phase 2

### 1.5 Gemma API provider
**New file**: `lib/features/cloud_ai/gemma_api_provider.dart`
- Direct HTTP client for Google AI Studio API (`generativelanguage.googleapis.com`)
- Primary: `gemma-4-31b-it` via Google AI Studio
- Fallback: `gemini-3.1-flash-lite` via Gemini API
- Both use same API key, different model endpoints
- 10s timeout with 2s retry on 429 (rate limited)

### 1.6 Persona-aware prompt builder
**New file**: `lib/rag/persona_prompt.dart`
- Enhanced system prompt supporting Bangla + English + Banglish
- Personality: chillnatural, helpful, joyful, friendly
- No topic restrictions (user can ask anything)
- Emergency context awareness (mention 999 for urgent queries)
- Personalization summary injection point

---

## Phase 2: Local Model Multi-Tier

### 2.1 Hardware-based model selection
**File**: `lib/core/device_capability.dart`
- Already has `DeviceTier` (low/mid/high) and `ModelVariant` (e2b/e4b/twelveb)
- Enhance with `device_info_plus` for accurate RAM detection on Android
- Auto-recommend best model for device on first launch

### 2.2 Multi-model management
**File**: `lib/core/model_manager.dart`
- Already supports E2B/E4B/12B variants
- Add: auto-select recommended model on first run
- Add: model switching with session reset
- Add: storage management (delete inactive models to free space)

### 2.3 Model marketplace UI
**File**: `lib/features/settings/model_picker_section.dart`
- Already has basic picker with download/activate/delete
- Enhance with: hardware recommendation badge, storage usage display, model comparison info

---

## Phase 3: Smart Fallback Chain

### 3.1 Enhanced connectivity detection
**File**: `lib/core/connectivity_provider.dart`
- Currently: interface-level detection only (WiFi/mobile present = online)
- Add: HTTP reachability check to Google API endpoints
- Add: latency measurement for model selection

### 3.2 Intelligent routing
**File**: `lib/features/chat/chat_repository.dart`
- Already has 3-tier fallback (cloud → local → corpus)
- Enhance to 5-tier with API key check:
  ```
  if (apiKey present && online) → Gemma API
  else if (online) → Gemini Flash Lite
  else if (local model ready) → Local Gemma
  else if (corpus hits) → RAG retrieval
  else → Canned 999
  ```
- Add: response quality tracking (did model return useful answer?)
- Add: automatic tier demotion on repeated failures

### 3.3 Response quality monitoring
**New file**: `lib/features/chat/quality_tracker.dart`
- Track success/failure per tier per query type
- Store on-device only (never ships off device)
- Use for automatic tier selection optimization

---

## Phase 4: On-Device Personalization

### 4.1 User behavior tracker
**New file**: `lib/features/chat/user_tracker.dart`
- Track: query categories, time of day, language preference, response satisfaction
- Store: on-device only using `shared_preferences` or local file
- Privacy: never ships voice, GPS, chat content off device (AGENTS.md constraint)

### 4.2 Preference summaries
**File**: `lib/rag/persona_prompt.dart`
- Inject user preference summary into system prompts
- Examples: "User often asks about flood safety", "User prefers Banglish"
- Keep summaries small (<100 tokens) to avoid context bloat

### 4.3 Dynamic suggestion chips
**File**: `lib/features/chat/chat_screen.dart`
- Current: static suggestions ('ORS কীভাবে বানাবো?', 'নিকটস্থ আশ্রয়কেন্দ্র', 'সাপে কামড়ালে কী করবো?')
- Enhance: rotate suggestions based on user history, time of day, season
- Example: monsoon season → flood-related suggestions, morning → daily prep tips

---

## Phase 5: Smart Notifications

### 5.1 Time-based triggers
**New file**: `lib/features/notifications/notification_service.dart`
- Monsoon season (June-October): flood preparedness tips
- Cyclone season (April-June, October-December): cyclone shelter reminders
- Morning/evening: daily safety check-in

### 5.2 Location-based triggers
- When user is near a shelter: "আশ্রয়কেন্দ্র কাছেই আছে"
- When user is in flood-prone area during monsoon: safety alerts

### 5.3 Usage-based triggers
- If user hasn't opened app in 7 days: gentle reminder
- If user asked emergency question but didn't call 999: follow-up

### 5.4 Weather integration
**File**: `lib/features/weather/weather_service.dart` (already exists)
- Integrate with Open-Meteo API for local weather data
- Trigger notifications based on weather conditions

---

## Phase 6: Testing Strategy

### 6.1 Unit tests
- `test/unit/` for pure Dart logic (RAG, persona prompts, quality tracker)
- No widget tree, no IO — fast execution

### 6.2 Widget tests
- `test/widget/` for UI components
- Mock model manager, cloud AI service
- Avoid `pumpAndSettle` on animations (use `pump(Duration)`)

### 6.3 Integration tests
- `integration_test/` for full app flow on device
- Test: API key storage, model download, multi-tier fallback
- Run manually before demo, not in CI

### 6.4 Test commands
```bash
flutter test test/unit/                    # pure Dart (fast)
flutter test test/widget/                  # widget tests
flutter test integration_test/...          # requires device
flutter analyze                            # must be clean
```

---

## File Map

### New files to create
```
lib/core/api_key_store.dart                    # Encrypted API key storage
lib/features/cloud_ai/gemma_api_provider.dart  # Google AI Studio API client
lib/rag/persona_prompt.dart                    # Enhanced system prompt
lib/features/chat/quality_tracker.dart         # Response quality monitoring
lib/features/chat/user_tracker.dart            # On-device user behavior tracking
lib/features/notifications/notification_service.dart  # Smart notifications
```

### Files to modify
```
pubspec.yaml                                   # Add flutter_secure_storage
lib/features/cloud_ai/cloud_ai_service.dart    # Update model IDs, add API key support
lib/features/chat/chat_screen.dart             # Fix auto-read default, dynamic suggestions
lib/features/settings/settings_screen.dart     # Fix auto-read default, API key UI
lib/features/chat/chat_repository.dart         # 5-tier fallback chain
lib/core/device_capability.dart                # Enhanced hardware detection
lib/core/model_manager.dart                    # Auto-select model, storage management
lib/features/settings/model_picker_section.dart # Enhanced marketplace UI
lib/core/connectivity_provider.dart            # HTTP reachability check
lib/rag/prompt_builder.dart                    # Integrate persona prompts
```

---

## Constraints & Guardrails

### Hard constraints (from AGENTS.md)
- **arm64-v8a only** — no x86 emulator support
- **No network in core chat loop** — offline-first thesis
- **Single model path** — all LLM access through `modelManager` singleton
- **No medical content from outside whitelist** — WHO, BDRCS, MoDMR, BMD, CDC, IFRC only
- **No English in user UI** — Bangla surface only
- **Bangla numerals (০-৯)** in user-facing strings
- **No auto-read TTS** — `pref_auto_read` must default `false`
- **No analytics that ship user content** — voice, GPS, chat never leave device

### Security
- API keys stored via `flutter_secure_storage` (encrypted at rest)
- Never commit API keys to code or git
- User behavior data stays on device
- No off-device analytics of user content

### Performance
- Model download: background with progress UI
- Cloud API: 10s timeout, 2s retry on 429
- Local inference: 3-10s cold start on arm64
- RAG retrieval: <10ms for keyword matching
- Personalization summaries: <100 tokens

---

## Implementation Order

1. **Phase 1** (Cloud AI) — foundation, enables online intelligence
2. **Phase 2** (Local models) — ensures offline capability
3. **Phase 3** (Smart fallback) — connects cloud + local
4. **Phase 4** (Personalization) — makes AI smarter per user
5. **Phase 5** (Notifications) — proactive engagement
6. **Phase 6** (Testing) — quality assurance throughout

Each phase is independently deployable. Phases 1-3 are critical for the core experience. Phases 4-5 enhance engagement. Phase 6 runs in parallel.
