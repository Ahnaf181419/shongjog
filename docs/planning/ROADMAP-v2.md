# Shongjog v2 — Comprehensive Implementation Roadmap

> **Source documents:** `docs/plan_v2_extension.md` (10-day extension strategy) +
> `docs/ai_feature_candidates.md` (Gemma 4 feature selection).
>
> **Thesis:** "Gemma thinks harder when it matters, corrects lies when no one can
> fact-check, and speaks clearly to responders when the person can't — all with the
> tower down."
>
> **Verification:** `flutter analyze lib/ test/` clean + `flutter test` all-pass
> after every task. Device testing is user-owned.

---

## Strategic Decisions (self-selected for maximum impact)

From the two source docs, I'm selecting the combination that maximizes rubric
score with the least risk, while staying true to the offline-first thesis.

**Ship (P0):**
1. **Evaluation harness** — 50-query held-out set, reproducible script. Turns
   safety claims into measured facts. This is the credibility engine.
2. **LoRA fine-tune** — the single strongest differentiator. Gemma is Apache 2.0;
   almost no hackathon team fine-tunes. Produces the before/after table centerpiece.
3. **Adaptive Thinking Mode** — reflex vs. deliberation routed by urgency. Near-zero
   implementation cost (SDK supports `enableThinking`), killer eval chart.
4. **Rumour & Misinformation Check** — "Someone told me X — is it true?" Pure
   offline argument. Shares the fine-tune dataset. Sleeper hit.

**Ship (P1):**
5. **Structured SOS via Function Calling** — panicked speech → structured SMS
   dispatch. Uses native `tools` parameter in `createSession`.
6. **Corpus expansion** — 23 → 50+ chunks, expert-reviewed.

**Defer (P2 — name in writeup, don't build):**
- Native audio input (risk: untested on Bangla dialects; verify in a spike first)
- Vision triage (risk: shaky feature worse than none; only if P0 done)
- Full-context fallback (writeup value only)
- Personalised preparedness plan

---

## SDK Capability Verification (done before writing this roadmap)

flutter_gemma 1.3.0 `createSession()` natively supports:

```dart
Future<InferenceModelSession> createSession({
  double temperature = .8,
  int randomSeed = 1,
  int topK = 1,
  double? topP,
  String? loraPath,                    // ← LoRA adapter support
  bool? enableVisionModality,          // ← Gemma 4 vision
  bool? enableAudioModality,           // ← Gemma 3n E4B audio
  String? systemInstruction,
  bool enableThinking = false,         // ← Gemma 4 thinking mode
  List<Tool> tools = const [],         // ← Native function calling
  int? maxOutputTokens,
});
```

All features below are feasible with the **current SDK** — no version bump needed.

---

## Phase 1 — Evaluation Harness (P0, Days 1-2)

**Goal:** Build a reproducible eval script that measures retrieval accuracy,
groundedness, safety refusals, myth resistance, and language fidelity on a
held-out test set.

### Task 1.1: Create eval test set (50 Bangla queries)
- [ ] Create `eval/test_set.json` — 50 queries across 5 categories:
  - 10 standard emergency (ORS, snakebite, drowning, bleeding, fever)
  - 10 cross-hazard (flood → water contamination → diarrhea)
  - 10 myth-laden ("সাপে কামড়ালে কেটে ফেলা উচিত?")
  - 10 out-of-scope ("আমার মাথাব্যথা কী কারণে?")
  - 10 follow-up / multi-turn ("তারপর কী করবো?")
- [ ] Each entry: `id`, `query` (Bangla), `category`, `expected_chunk_topic`,
      `expected_safety_refusal` (bool), `myth_to_correct` (string, optional)
- [ ] **Verify:** JSON is valid, 50 entries, all categories covered

### Task 1.2: Build eval runner script
- [ ] Create `eval/run_eval.py` — loads test set, runs each query through
      the prompt builder (offline RAG path), saves outputs to
      `eval/results/base_model.jsonl`
- [ ] Metrics computed per query:
  - `retrieved_chunks` (top-3 topics)
  - `recall_at_1`, `recall_at_3` (did the expected topic appear?)
  - `output_text` (the generated Bangla answer)
  - `latency_ms` (time to full answer, placeholder — device-only metric)
- [ ] Aggregate report: `eval/results/base_report.md` with per-category tables
- [ ] **Verify:** `python3 eval/run_eval.py` runs clean, produces report

### Task 1.3: Add manual rubric scoring sheet
- [ ] Create `eval/rubric_template.csv` — columns: query_id, groundedness (1-5),
      safety_correct (Y/N), myth_corrected (Y/N), bangla_only (Y/N),
      action_step_clear (1-5), reviewer_notes
- [ ] For 2 reviewers × 50 queries = 100 ratings
- [ ] **Verify:** Template is copy-pasteable into Google Sheets

### Task 1.4: Tests for eval harness
- [ ] Create `test/unit/eval_test.dart` — tests that the test set JSON is valid,
      all categories present, every query has required fields
- [ ] **Verify:** `flutter test test/unit/eval_test.dart` passes

### Task 1.5: Commit Phase 1
- [ ] Run `flutter analyze lib/ test/` — must be clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(eval): add evaluation harness with 50-query test set + runner`

---

## Phase 2 — LoRA Fine-Tune (P0, Days 3-5)

**Goal:** Fine-tune Gemma 4 E2B on Bangla emergency triage, export adapter, load
on-device, measure before/after.

### Task 2.1: Build SFT dataset scaffold
- [ ] Create `training/sft_dataset.jsonl` — 150 examples minimum, format:
      `{"query": "<Bangla query>", "context": "<retrieved chunks>", 
       "ideal_answer": "<grounded Bangla answer with numbered steps>"}`
- [ ] Cover all corpus domains: ORS/diarrhea, safe water, snakebite, drowning,
      wound care, electrical safety, evacuation, pregnancy/infant/elderly
- [ ] Include hard negatives: myth queries → "না, এটি ভুল। সঠিক উপায়..." 
      + out-of-scope → "আমি নিশ্চিত নই। ৯৯৯ কল করুন।"
- [ ] Enforce output shape: short numbered steps → warning signs → "call 999 if X"
- [ ] **Verify:** 150+ entries, all domains covered, no English in answers

### Task 2.2: Create Colab training notebook
- [ ] Create `training/lora_finetune.ipynb` — Jupyter notebook for Google Colab:
  - Load Gemma 4 E2B base model (from Kaggle/HF)
  - Apply LoRA (rank 16-32, alpha 32, target attention/mlp projections)
  - Train 3-5 epochs on SFT dataset
  - Export adapter weights as `.task` or safetensors
  - Log training loss + eval loss per epoch
- [ ] **Verify:** Notebook runs end-to-end on Colab T4 (free tier)

### Task 2.3: Model manager — LoRA loading support
- [ ] Modify `lib/core/model_manager.dart` — add `_loraPath` field, load LoRA
      adapter in `createSession(loraPath: _loraPath)` when available
- [ ] Add `setLoraAdapter(String path)` method — hot-swap adapter without
      reloading the base model
- [ ] Add `clearLoraAdapter()` method — revert to base model
- [ ] **Verify:** `flutter analyze lib/` clean, `flutter test` passes

### Task 2.4: Tests for LoRA loading
- [ ] Create `test/unit/model_manager_lora_test.dart` — test that:
  - `setLoraAdapter` sets the path
  - `clearLoraAdapter` nulls the path
  - `generate()` passes loraPath to createSession when set
- [ ] **Verify:** `flutter test test/unit/model_manager_lora_test.dart` passes

### Task 2.5: Settings UI — LoRA toggle
- [ ] Modify `lib/features/settings/settings_screen.dart` — add a toggle:
  "ফাইন-টিউনড মডেল" (Fine-tuned model) on/off
  - When on: `modelManager.setLoraAdapter(loraPath)`
  - When off: `modelManager.clearLoraAdapter()`
  - Persist in SharedPreferences: `pref_lora_enabled`
- [ ] **Verify:** `flutter analyze lib/` clean, widget test passes

### Task 2.6: Post-fine-tune eval
- [ ] Run `eval/run_eval.py` with fine-tuned model → `eval/results/finetuned.jsonl`
- [ ] Compare `eval/results/base_report.md` vs `eval/results/finetuned_report.md`
- [ ] Produce before/after comparison table: recall, groundedness, myth correction
- [ ] **Verify:** Improvement on at least 3 metrics

### Task 2.7: Commit Phase 2
- [ ] Run `flutter analyze lib/ test/` — clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(model): add LoRA fine-tune support + eval before/after`

---

## Phase 3 — Adaptive Thinking Mode (P0, Days 5-6)

**Goal:** Route queries by urgency — reflex (thinking off) for time-critical,
deliberation (thinking on) for ambiguous/multi-symptom.

### Task 3.1: Urgency classifier (pure-Dart)
- [ ] Create `lib/rag/urgency_classifier.dart` — classifies a query into:
  - `UrgencyLevel.critical` — keywords: শ্বাসকষ্ট, রক্তক্ষরণ, ডুবে যাওয়া, পুড়ে যাওয়া
  - `UrgencyLevel.urgent` — keywords: সাপ, জ্বর, বমি, ডায়রিয়া, গর্ভবতী
  - `UrgencyLevel.routine` — everything else (preparedness, info)
- [ ] Returns `(UrgencyLevel level, bool enableThinking)`
  - critical → thinking OFF (reflex path, max speed)
  - urgent → thinking ON (deliberation)
  - routine → thinking ON
- [ ] **Verify:** Unit test covers all 3 levels + edge cases

### Task 3.2: Tests for urgency classifier
- [ ] Create `test/unit/urgency_classifier_test.dart` — 10+ test cases:
  - "শিশু ডুবে গেছে" → critical, thinking=false
  - "সাপে কামড়েছে" → urgent, thinking=true
  - "ঘূর্ণিঝড়ের আগে কী প্রস্তুতি নিতে হবে?" → routine, thinking=true
- [ ] **Verify:** `flutter test test/unit/urgency_classifier_test.dart` passes

### Task 3.3: Wire urgency into model manager
- [ ] Modify `lib/core/model_manager.dart` `generate()` — accept optional
      `enableThinking` parameter, pass to `createSession(enableThinking: ...)`
- [ ] Modify `lib/features/chat/chat_repository.dart` `ask()` — call
      `UrgencyClassifier.classify(query)` before generation, pass the thinking
      flag to `modelManager.generate()`
- [ ] **Verify:** `flutter analyze` clean, `flutter test` passes

### Task 3.4: UI — urgency indicator
- [ ] Modify `lib/features/chat/message_bubble.dart` — show a small badge on
      assistant messages: 🔴 জরুরি (critical), 🟡 তাগিদপূর্ণ (urgent), 🟢 সাধারণ (routine)
- [ ] Store the urgency level on the `ChatMessage` model
- [ ] **Verify:** Widget test shows the badge

### Task 3.5: Tests for urgency wiring
- [ ] Create/update `test/unit/chat_repository_test.dart` — test that critical
      queries get thinking=false, routine queries get thinking=true
- [ ] **Verify:** `flutter test` passes

### Task 3.6: Commit Phase 3
- [ ] Run `flutter analyze lib/ test/` — clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(rag): add adaptive thinking mode — urgency-driven compute`

---

## Phase 4 — Rumour & Misinformation Check (P0, Days 6-7)

**Goal:** "Someone told me X — is it true?" — check claims against corpus.

### Task 4.1: Rumour checker prompt builder
- [ ] Create `lib/rag/rumour_checker.dart` — pure-Dart module:
  - Input: a claim string (Bangla)
  - Retrieves top-3 chunks (reuses `KeywordRetriever`)
  - Builds a rumour-check prompt: "এই দাবি সত্য কি মিথ্যা?" + context
  - Returns a prompt string with system instruction for confirm/correct/not-covered
- [ ] **Verify:** Unit test builds correct prompt for sample claims

### Task 4.2: Tests for rumour checker
- [ ] Create `test/unit/rumour_checker_test.dart` — test:
  - "সাপে কামড়ালে কেটে ফেলা উচিত" → prompt contains "ভুল" + snakebite context
  - "ORS খেলে ডায়রিয়া সারে" → prompt contains context
  - Out-of-scope claim → prompt instructs "not covered, call 999"
- [ ] **Verify:** `flutter test test/unit/rumour_checker_test.dart` passes

### Task 4.3: Rumour check UI entry point
- [ ] Modify `lib/features/chat/chat_screen.dart` — add a quick-action chip:
      "গুজব যাচাই" (Verify rumour) below the input field
  - Tapping it prefills the input with "গুজব: " prefix
  - When query starts with "গুজব:" or "কেউ বললো:", route through rumour checker
      instead of normal RAG path
- [ ] Modify `lib/features/chat/chat_repository.dart` — detect rumour queries
      (prefix-based), route to `RumourChecker.buildPrompt()` instead of standard
      `PromptBuilder.build()`
- [ ] **Verify:** `flutter analyze` clean, `flutter test` passes

### Task 4.4: Tests for rumour routing
- [ ] Update `test/unit/chat_repository_test.dart` — test that "গুজব:" prefix
      triggers the rumour checker path, normal queries don't
- [ ] **Verify:** `flutter test` passes

### Task 4.4: Commit Phase 4
- [ ] Run `flutter analyze lib/ test/` — clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(rag): add rumour & misinformation check against corpus`

---

## Phase 5 — Structured SOS via Function Calling (P1, Day 8)

**Goal:** Panicked speech → structured dispatch report → SMS.

### Task 5.1: SOS function definition (pure-Dart)
- [ ] Create `lib/features/emergency/sos_function_schema.dart` — defines the
      tool schema for Gemma function calling:
  ```json
  {
    "name": "submit_sos_report",
    "description": "Submit a structured emergency dispatch report",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {"type": "string"},
        "hazard_type": {"type": "string"},
        "casualty_count": {"type": "integer"},
        "injuries": {"type": "string"},
        "immediate_needs": {"type": "array", "items": {"type": "string"}},
        "access_notes": {"type": "string"}
      }
    }
  }
  ```
- [ ] **Verify:** Schema is valid JSON, compiles as a Dart string constant

### Task 5.2: SOS composer in model manager
- [ ] Modify `lib/core/model_manager.dart` — add `generateStructured()` method:
  - Creates a session with `tools: [sosTool]`
  - Sends the panicked query + system instruction "Extract structured info"
  - Parses the function call response
  - Returns a `Map<String, dynamic>` of the extracted fields
- [ ] **Verify:** Unit test (mock) verifies tool parameter passing

### Task 5.3: SOS composer UI
- [ ] Create `lib/features/emergency/sos_composer_screen.dart` — screen that:
  - Takes voice/text input (panicked description)
  - Calls `modelManager.generateStructured()` 
  - Shows the parsed fields in an editable form (user can correct before sending)
  - "৯৯৯ কল করুন" button → formats as SMS body + opens dialer
- [ ] Register route: `AppRoutes.sosComposer` → `/sos-composer`
- [ ] **Verify:** Widget test renders the form, `flutter analyze` clean

### Task 5.4: Tests for SOS composer
- [ ] Create `test/unit/sos_function_test.dart` — test schema validity
- [ ] Create `test/widget/sos_composer_test.dart` — test form rendering
- [ ] **Verify:** `flutter test` passes

### Task 5.5: Commit Phase 5
- [ ] Run `flutter analyze lib/ test/` — clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(emergency): add structured SOS via function calling`

---

## Phase 6 — Corpus Expansion + Expert Review (P1, Days 4-7 parallel)

**Goal:** 23 → 50+ chunks, covering more hazards, reviewed by a named expert.

### Task 6.1: Author new corpus chunks
- [ ] Add 27+ new chunks to `tools/corpus.json` covering:
  - Heat exposure / heatstroke (3 chunks)
  - Cold exposure / hypothermia (3 chunks)
  - Mental health first aid / panic attack (3 chunks)
  - Post-flood mold and hygiene (3 chunks)
  - Livestock / agricultural safety (2 chunks)
  - Document recovery (2 chunks)
  - Pregnancy-specific emergency (3 chunks)
  - Infant (0-6mo) specific care (3 chunks)
  - Elderly-specific emergency (3 chunks)
  - Electrical safety during floods (2 chunks)
- [ ] All sources from: WHO, BDRCS, MoDMR, BMD, CDC, IFRC
- [ ] **Verify:** `python3 tools/verify_kb.py` — all queries pass

### Task 6.2: Rebuild knowledge base
- [ ] Run `cd tools && python3 build_kb.py` to regenerate embeddings
- [ ] Run `python3 verify_kb.py` — all 7 queries must print "OK"
- [ ] Copy generated `corpus.json` + `vectors.bin` to `assets/kb/`
- [ ] **Verify:** KB builds clean, verify_kb passes

### Task 6.3: Expert review tracking
- [ ] Create `docs/corpus-review.md` — tracks:
  - Reviewer name, title, affiliation (with permission)
  - Date reviewed
  - Chunks reviewed
  - Changes requested + made
  - Sign-off statement
- [ ] **Verify:** Template is ready for reviewer to fill

### Task 6.4: Source attribution in UI
- [ ] Modify `lib/features/chat/message_bubble.dart` — show source attribution
      on grounded answers: "সূত্র: WHO / BDRCS" below the answer
- [ ] Modify `lib/rag/prompt_builder.dart` — include source metadata in the prompt
      so the model can cite it
- [ ] **Verify:** Widget test shows attribution, `flutter test` passes

### Task 6.5: Commit Phase 6
- [ ] Run `flutter analyze lib/ test/` — clean
- [ ] Run `flutter test` — all pass
- [ ] Commit: `feat(corpus): expand to 50+ chunks + expert review template + UI attribution`

---

## Phase 7 — Robustness & Polish (P2, Day 9)

**Goal:** Graceful degradation, crash-free runs, accessibility.

### Task 7.1: Graceful degradation audit
- [ ] Audit all failure paths: model missing, GPS off, no permissions, low battery
- [ ] Every failure path shows a Bangla message + fallback action (not a blank screen)
- [ ] **Verify:** Manual audit checklist, no blank-screen paths

### Task 7.2: Crash-free demo run
- [ ] Run full demo path 10× on device, record any crashes
- [ ] Fix top 3 crash-causing issues
- [ ] **Verify:** 10 consecutive clean runs

### Task 7.3: Accessibility pass
- [ ] Large text support (Semantics labels on all interactive elements)
- [ ] High-contrast colors verified in bright-sun simulation
- [ ] One-handed reach (important buttons in bottom 2/3 of screen)
- [ ] **Verify:** flutter analyze passes with no accessibility warnings

### Task 7.4: Commit Phase 7
- [ ] Commit: `fix(app): robustness + accessibility polish`

---

## Phase 8 — Ship (Day 10)

### Task 8.1: Final eval run
- [ ] Run full eval suite (base vs fine-tuned) → `eval/results/final_report.md`
- [ ] Generate charts (before/after recall, groundedness, myth correction)

### Task 8.2: Demo video
- [ ] Record 60-second airplane-mode demo on real phone
- [ ] Real Bangla query, real voice input, real grounded answer
- [ ] Save to `docs/demo-video.mp4` (or link)

### Task 8.3: Writeup
- [ ] Write ≤1,500-word writeup following the structure in plan_v2_extension.md §3
- [ ] Lead with eval table, not adjectives
- [ ] Save to `docs/writeup.md`

### Task 8.4: Repo hygiene
- [ ] README.md updated with setup, eval, fine-tune instructions
- [ ] All deps pinned in pubspec.yaml
- [ ] eval/ and training/ directories documented
- [ ] License file present
- [ ] **Verify:** `flutter analyze` clean, `flutter test` all pass

### Task 8.5: Submit
- [ ] Kaggle submission
- [ ] Google form filled
- [ ] Tag release: `git tag v2.0`

---

## Definition of Done

- [ ] Evaluation harness in repo with 50-query test set
- [ ] LoRA fine-tuned model running on-device with before/after eval table
- [ ] Adaptive thinking mode routed by clinical urgency
- [ ] Rumour check feature — "গুজব যাচাই" working offline
- [ ] Structured SOS via function calling
- [ ] Corpus at 50+ chunks, expert-reviewed
- [ ] Robustness: 10× crash-free demo runs
- [ ] Demo video + writeup submitted
- [ ] All docs updated to reflect v2 state

---

## File Change Map

| File | Phase | Action |
|---|---|---|
| `eval/test_set.json` | 1 | Create |
| `eval/run_eval.py` | 1 | Create |
| `eval/rubric_template.csv` | 1 | Create |
| `test/unit/eval_test.dart` | 1 | Create |
| `training/sft_dataset.jsonl` | 2 | Create |
| `training/lora_finetune.ipynb` | 2 | Create |
| `lib/core/model_manager.dart` | 2,3,5 | Modify (LoRA, thinking, tools) |
| `test/unit/model_manager_lora_test.dart` | 2 | Create |
| `lib/features/settings/settings_screen.dart` | 2 | Modify (LoRA toggle) |
| `lib/rag/urgency_classifier.dart` | 3 | Create |
| `test/unit/urgency_classifier_test.dart` | 3 | Create |
| `lib/features/chat/chat_repository.dart` | 3,4 | Modify (urgency, rumour routing) |
| `lib/features/chat/message_bubble.dart` | 3,6 | Modify (urgency badge, source) |
| `lib/rag/rumour_checker.dart` | 4 | Create |
| `test/unit/rumour_checker_test.dart` | 4 | Create |
| `lib/features/chat/chat_screen.dart` | 4,5 | Modify (rumour chip, SOS entry) |
| `lib/features/emergency/sos_function_schema.dart` | 5 | Create |
| `lib/features/emergency/sos_composer_screen.dart` | 5 | Create |
| `test/unit/sos_function_test.dart` | 5 | Create |
| `test/widget/sos_composer_test.dart` | 5 | Create |
| `tools/corpus.json` | 6 | Modify (expand to 50+) |
| `docs/corpus-review.md` | 6 | Create |
| `lib/rag/prompt_builder.dart` | 6 | Modify (source attribution) |
| `docs/PROJECT-STATUS.md` | All | Update per phase |
| `docs/architecture.md` | All | Update per phase |
| `AGENTS.md` | All | Update per phase |
