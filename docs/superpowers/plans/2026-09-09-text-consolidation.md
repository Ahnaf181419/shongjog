# Text Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every user-facing Bangla and English string in the codebase into a single source-of-truth location (the existing `lib/l10n/app_*.arb` ARB pair for UI copy, plus a new family of bilingual JSON assets under `assets/data/` and `assets/prompts/`), then add a custom lint rule and a CI sweep test so no hard-coded text can ever sneak back in.

**Architecture:** Three coupled moves:
1. **UI copy** extends the existing Flutter ARB pair — `lib/l10n/app_bn.arb` + `lib/l10n/app_en.arb` are already wired through `gen-l10n`. The sweep just makes them exhaustive.
2. **Data tables** (quick cards, districts, emergency directory, RAG corpus) move from `.dart` / `assets/kb/corpus.json` to a new bilingual shape `{"bn": {...}, "en": {...}}` under `assets/data/*.json`. Loader pattern borrowed from `kb_loader.dart`.
3. **LLM prompts** move from `const String` literals in `lib/rag/prompt_builder.dart` and the eight `*_prompt_builder.dart` files to `assets/prompts/<name>.json`. A single `lib/core/text_loader.dart` (cached async JSON loader with locale dispatch) backs both.

After each step the codebase must compile + every test must still pass. After phase 6 a grep over `lib/**/*.dart` for the Bengali Unicode block `[U+0980–U+09FF]` returns *only* the generated `app_localizations_*.dart` files and explicitly allow-listed comment sites.

**Tech Stack:** Flutter 3.x stable, Dart 3.x, `flutter_localizations` (already in `pubspec.yaml`), `intl` (already a dep), `shared_preferences` (locale persistence, already a dep), `flutter_test` (already a dev-dep), `custom_lint` (new dev-dep for the guard rule), `package:lints/recommended.yaml` (project lints), `flutter analyze --fatal-infos`, `flutter test`.

---

## File map (locked in up-front)

### Created (new files)
```
assets/data/cards.json                       ← 25 quick cards, bilingual
assets/data/districts.json                   ← 64 districts × 8 divisions, bilingual
assets/data/emergency_directory.json         ← moved from assets/emergency/directory.json + bilingual
assets/data/corpus.json                      ← moved from assets/kb/corpus.json + bilingual

assets/prompts/persona.json                  ← persona + rules + escalation + emergency keywords
assets/prompts/planner.json
assets/prompts/kit.json
assets/prompts/risk.json
assets/prompts/urgency.json
assets/prompts/rumour.json
assets/prompts/repetition.json
assets/prompts/damage_scan.json
assets/prompts/situation_summary.json
assets/prompts/shelter.json

lib/core/text_loader.dart                    ← shared async JSON loader + locale-dispatch helper
lib/features/quick_cards/cards_loader.dart   ← per-feature loader
lib/features/profile/districts_loader.dart   ← per-feature loader
lib/features/intelligence/intelligence_text.dart   ← status/severity label helper
lib/features/rag/persona_loader.dart         ← per-feature prompt loader
lib/features/planner/prompt_loaders.dart     ← per-feature prompt loaders (kit, risk, planner)
lib/features/intelligence/summary_loader.dart
lib/features/damage_scanner/scan_loader.dart
lib/features/shelter/shelter_loaders.dart    ← shelter brief + semantic search + dispatcher + formatter + nominatim

lib/lints/no_user_facing_bangla.dart         ← custom_lint rule
test/lint/no_scattered_bangla_test.dart      ← static-analysis CI sweep
test/lint/one_source_of_truth_test.dart      ← asserts every prompt_builder is now a 1-liner

docs/superpowers/plans/2026-09-09-text-consolidation.md     ← THIS document
docs/content-i18n-sweep.md                   ← project-facing summary of the new content model
```

### Modified (existing files)
```
l10n.yaml                                              ← (no change)
lib/l10n/app_bn.arb                                    ← add ~50 keys (Group A + metadata)
lib/l10n/app_en.arb                                    ← sync metadata + EN values for all new keys
pubspec.yaml                                           ← add `custom_lint` to dev_dependencies; declare new asset dirs
analysis_options.yaml                                  ← enable `lint` plugin entry

lib/rag/prompt_builder.dart                            ← replace const _kPersona/_kRules with PersonaBundle calls
lib/rag/rumour_checker.dart                            ← replace hard-coded prompt template
lib/rag/urgency_classifier.dart                        ← replace hard-coded prompt + Bangla think-mode markers
lib/rag/repetition_detector.dart                       ← replace regex exemplar

lib/features/planner/planner_prompt_builder.dart        ← replace buildPlan / fallbackPlan literals
lib/features/planner/kit_prompt_builder.dart
lib/features/planner/risk_prompt_builder.dart
lib/features/planner/family_profile.dart               ← UI labels go to ARB

lib/features/intelligence/situation_summary_service.dart
lib/features/intelligence/intelligence_engine.dart
lib/features/intelligence/notification_service.dart
lib/features/intelligence/proximity_notification_service.dart
lib/features/intelligence/user_profile.dart
lib/features/intelligence/situation_summary_screen.dart

lib/features/damage_scanner/damage_scan_service.dart

lib/features/shelter/shelter_brief_builder.dart
lib/features/shelter/semantic_search_service.dart
lib/features/shelter/shelter_tool_dispatcher.dart
lib/features/shelter/shelter_tool_result_formatter.dart
lib/features/shelter/nominatim_service.dart
lib/features/shelter/widgets/shelter_route_info_card.dart

lib/features/chat/chat_repository.dart                 ← canned chat fallback + parser regex annotation
lib/features/chat/demo_seeder.dart                     ← 3 demo queries

lib/features/emergency/sos_sms_template.dart           ← `gpsWarning` default + body copies
lib/features/emergency/sos_function_schema.dart
lib/features/emergency/sos_composer_screen.dart
lib/features/emergency/emergency_sheet.dart

lib/features/safe_beacon/safe_beacon_payload.dart      ← `মিsos message default
lib/features/safe_beacon/safety_status_service.dart
lib/features/safe_beacon/safety_status_screen.dart

lib/features/admin/admin_pages.dart
lib/features/about/about_screen.dart
lib/features/home/live_hazards_card.dart
lib/features/home/air_quality_card.dart
lib/features/home/hazards_list_screen.dart
lib/features/weather/weather_service.dart
lib/features/hazards/eonet_service.dart
lib/features/hazards/gdacs_service.dart
lib/features/mesh_comm/mesh_chat_screen.dart
lib/features/mesh_comm/mesh_radar_screen.dart
lib/features/triage/triage_state.dart
lib/features/triage/triage_wizard_screen.dart
lib/features/voice/speech_to_text_provider.dart
lib/features/profile/district_data.dart                ← become a thin loader wrapper around districts_loader
lib/features/quick_cards/cards_data.dart               ← become a thin loader wrapper around cards_loader

lib/core/local_notification_service.dart               ← Android tray title "জরুরি ঘোষণা" → ARB
lib/core/admin_broadcast_service.dart                  ← admin copy → ARB
lib/core/device_capability.dart                        ← comment-only Bangla, allow-listed
lib/app/theme.dart                                     ← comment-only Bangla, allow-listed
lib/features/chat/typewriter_text.dart                 ← comment-only Bangla, allow-listed

docs/architecture.md                                   ← add "Content model" section
docs/PROJECT-STATUS.md                                 ← refresh stale copy references
docs/CHANGELOG.md                                      ← Unreleased entry: text consolidation
docs/README.md                                         ← link to docs/content-i18n-sweep.md
```

### Removed (only after the migration finishes)
```
assets/emergency/directory.json                        ← replaced by assets/data/emergency_directory.json
assets/kb/corpus.json                                  ← replaced by assets/data/corpus.json
```

---

## Phase 0 — Pre-flight (must finish before everything else)

### Task 0.1: Establish the baseline test count

**Files:**
- Inspect: `test/unit/`, `test/widget/`

- [ ] **Step 1: Capture the current test count and analyzer state**

```bash
flutter test 2>&1 | tee /tmp/text-consolidation-baseline.txt | tail -5
flutter analyze --fatal-infos 2>&1 | tee /tmp/text-consolidation-baseline-analyze.txt | tail -5
```

Expected: a final line like `All tests passed!` with a number, and `No issues found!` from analyze.

- [ ] **Step 2: Record both numbers in a `BEFORE.md` log at the repo root (gitignored build artifact, not committed)**

```bash
cat > BEFORE.md <<'EOF'
# Text Consolidation — Pre-flight
captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)

- tests passing: <paste from /tmp/text-consolidation-baseline.txt>
- analyze: <paste from /tmp/text-consolidation-baseline-analyze.txt>
EOF
git worktree add .git 2>/dev/null   # ensure we're not on a feature branch mishap
```

- [ ] **Step 3: Snapshot the current Bangla-literal count**

```bash
grep -rP "[\x{0980}-\x{09FF}]" lib --include="*.dart" -c \
  | grep -v ":0$" | grep -v "app_localizations_" \
  | awk -F: '{sum+=$2} END {print sum}' | tee BEFORE-bangla-count.txt
```

Expected: `1451` (the audit number). If different, investigate new files added since the audit.

- [ ] **Step 4: Commit baseline**

```bash
git add BEFORE.md BEFORE-bangla-count.txt
git commit -m "chore(text): capture baseline before text-consolidation sweep"
```

### Task 0.2: Sync `app_en.arb` metadata to mirror `app_bn.arb`

The audit confirmed `app_bn.arb` (the `template-arb-file` per `l10n.yaml`) carries several `@-prefixed` metadata blocks that `app_en.arb` is missing. Before we add any new keys, we equalise the existing pair so `gen-l10n` runs cleanly from this point.

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Test (manual): `flutter gen-l10n`

- [ ] **Step 1: Run `flutter gen-l10n` to surface the existing drift**

```bash
flutter gen-l10n 2>&1 | tail -20
```

Expected: warnings like `Missing associated key '<key>' in app_en.arb for placeholders` or `Missing description '<key>'`. Capture the list.

- [ ] **Step 2: Insert the missing `@-prefixed` metadata blocks into `app_en.arb`**

For each missing key the previous step reported, append a sibling metadata entry in `app_en.arb`:

```jsonc
"@<keyName>": {
  "description": "<english description of the key>"
}
```

The English description should be identical in meaning to the Bangla description already present in `app_bn.arb`. Do NOT change the order of existing entries in either file. Do NOT introduce new translation values.

- [ ] **Step 3: Re-run `flutter gen-l10n`**

```bash
flutter gen-l10n 2>&1 | tail -20
```

Expected: clean run, no key-drift warnings.

- [ ] **Step 4: Re-run the test suite**

```bash
flutter test 2>&1 | tail -5
```

Expected: same `All tests passed!` count as baseline.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_localizations*.dart
git commit -m "chore(l10n): sync app_en.arb metadata to mirror app_bn.arb template"
```

### Task 0.3: Confirm asset-bundle declarations

We are about to add `assets/data/*.json` and `assets/prompts/*.json`. The two `corpus.json` and `directory.json` already live in declared locations, but we want them to be discoverable by `rootBundle.loadString` without surprises.

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Verify current asset declarations**

```bash
sed -n '/^flutter:/,/^dev_dependencies:/p' pubspec.yaml
```

Expected: a `flutter.assets` list that includes `assets/kb/`, `assets/shelter/`, `assets/emergency/`.

- [ ] **Step 2: Add the two new asset directories**

Append under `flutter.assets:`:

```yaml
    - assets/data/
    - assets/prompts/
```

- [ ] **Step 3: `flutter pub get` + smoke test**

```bash
flutter pub get
flutter test test/unit/kb_loader_test.dart 2>&1 | tail -5
```

Expected: existing `kb_loader_test` still passes (proves we didn't break the existing asset pipeline).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(assets): declare assets/data/ and assets/prompts/ for new content"
```

---

## Phase 1 — Loader scaffolding

### Task 1.1: Write the failing test for the shared text loader

**Files:**
- Create: `test/unit/text_loader_test.dart`

- [ ] **Step 1: Write the test (it will fail because `lib/core/text_loader.dart` does not exist)**

```dart
// test/unit/text_loader_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/text_loader.dart';

void main() {
  group('TextLoader', () {
    test('loadJson parses and caches the asset', () async {
      // Test against an asset we know exists, the emergency-directory shape we
      // will move into assets/data/ in Task 2.x.
      final result = await TextLoader.loadJson<Map<String, dynamic>>(
        'assets/emergency/directory.json',
        // It's a top-level array; we test via an inline parser below.
        (raw) => jsonDecode(raw) as Map<String, dynamic>,
      );
      // The directory.json file is a JSON array. Our parser above expects an
      // object, so we expect a TypeError here — this assertion exists to
      // prove the loader round-trips, not to validate the asset content.
      expect(result, isA<Map<String, dynamic>>());
    });

    test('localeFor falls back to bn when tag is unknown', () {
      expect(TextLoader.localeFor('xx'), 'bn');
      expect(TextLoader.localeFor('bn'), 'bn');
      expect(TextLoader.localeFor('en'), 'en');
      expect(TextLoader.localeFor('EN'), 'en');
    });

    test('pickBundle returns the bn block by default', () {
      final fake = <String, dynamic>{
        'bn': {'a': 1},
        'en': {'a': 2},
      };
      expect(TextLoader.pickBundle(fake, 'en')['a'], 2);
      expect(TextLoader.pickBundle(fake, 'bn')['a'], 1);
      expect(TextLoader.pickBundle(fake, 'xx')['a'], 1);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/unit/text_loader_test.dart 2>&1 | tail -15
```

Expected: `Target of URI doesn't exist: 'package:shongjog/core/text_loader.dart'`.

- [ ] **Step 3: Commit the failing test**

```bash
git add test/unit/text_loader_test.dart
git commit -m "test(text_loader): scaffold failing tests for shared async JSON loader"
```

### Task 1.2: Implement the shared text loader

**Files:**
- Create: `lib/core/text_loader.dart`

- [ ] **Step 1: Implement `TextLoader` with caching**

```dart
// lib/core/text_loader.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Shared async JSON loader for content assets and LLM prompts.
///
/// All content assets under `assets/data/*.json` and `assets/prompts/*.json`
/// are loaded through this. The first read materialises the asset and caches
/// the *parsed* result keyed by asset path. Subsequent reads return the same
/// parsed object — including `null`/missing-asset sentinel, so a missing
/// asset is loud on the first call and silent on every subsequent call.
///
/// Prompts in `assets/prompts/*.json` always use the bilingual shape
/// `{"bn": {...}, "en": {...}}`. [pickBundle] returns the right block for
/// the active locale, with `bn` as the fallback (matches the project's
/// default locale in [LocaleController]).
abstract final class TextLoader {
  static final Map<String, Object?> _cache = <String, Object?>{};
  static final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  /// Load and parse a JSON asset, with a typed parser.
  ///
  /// [parseRaw] receives the raw UTF-8 string and must return the typed value.
  /// Same parser must be used for the same path (caching is per-path).
  static Future<T> loadJson<T>(
    String assetPath,
    T Function(String raw) parseRaw,
  ) async {
    final cached = _cache[assetPath];
    if (cached != null) {
      return cached as T;
    }
    final completer = _inFlight[assetPath];
    if (completer != null) {
      return completer as Future<T>;
    }
    final fut = _doLoad<T>(assetPath, parseRaw);
    _inFlight[assetPath] = fut;
    try {
      final v = await fut;
      _cache[assetPath] = v;
      return v;
    } finally {
      _inFlight.remove(assetPath);
    }
  }

  static Future<T> _doLoad<T>(
    String assetPath,
    T Function(String) parseRaw,
  ) async {
    final raw = await rootBundle.loadString(assetPath);
    return parseRaw(raw);
  }

  /// Coerce a language tag (lowercase or upper-case) to one of `bn` | `en`.
  /// Returns `bn` for anything unrecognised.
  static String localeFor(String? languageTag) {
    final tag = (languageTag ?? '').toLowerCase();
    if (tag.startsWith('bn')) return 'bn';
    if (tag.startsWith('en')) return 'en';
    return 'bn';
  }

  /// Pick the bn|en block out of a bilingual content bundle.
  ///
  /// Returns the `bn` block if [activeLocale] is `bn`, missing, or `xx`.
  /// Returns the `en` block if [activeLocale] is `en`.
  static Map<String, dynamic> pickBundle(
    Map<String, dynamic> bundle,
    String? activeLocale,
  ) {
    final key = localeFor(activeLocale);
    final bn = bundle['bn'];
    final en = bundle['en'];
    if (key == 'en' && en is Map<String, dynamic>) return en;
    if (key == 'bn' && bn is Map<String, dynamic>) return bn;
    // Defensive defaults.
    if (bn is Map<String, dynamic>) return bn;
    if (en is Map<String, dynamic>) return en;
    throw StateError('Bundle has neither bn nor en block: $bundle');
  }

  /// For tests.
  static void debugClearCache() => _cache.clear();
}
```

- [ ] **Step 2: Run the test suite**

```bash
flutter test test/unit/text_loader_test.dart 2>&1 | tail -15
flutter test 2>&1 | tail -5
```

Expected: 3 new tests pass, full suite stays green.

- [ ] **Step 3: Commit**

```bash
git add lib/core/text_loader.dart
git commit -m "feat(text_loader): shared async JSON loader with locale dispatch"
```

### Task 1.3: Implement the per-locale prompt bundle structure

**Files:**
- Create: `test/unit/persona_loader_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/persona_loader_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/text_loader.dart';
import 'package:shongjog/features/rag/persona_loader.dart';

void main() {
  group('PersonaLoader', () {
    setUp(() {
      TextLoader.debugClearCache();
    });

    test('loads persona for bn', () async {
      final bundle = await loadPersona('bn');
      expect(bundle.persona, contains('Shongjog'));
      expect(bundle.rules, contains('Safety rules'));
      expect(bundle.escalation, contains('৯৯৯'));
    });

    test('loads persona for en', () async {
      final bundle = await loadPersona('en');
      expect(bundle.persona, contains('Shongjog'));
      expect(bundle.escalation.toLowerCase(), contains('999'));
    });
  });
}
```

- [ ] **Step 2: Run; expect compile failure (PersonaLoader + asset missing)**

```bash
flutter test test/unit/persona_loader_test.dart 2>&1 | tail -10
```

Expected: `Target of URI doesn't exist: 'package:shongjog/features/rag/persona_loader.dart'`.

- [ ] **Step 3: Commit**

```bash
git add test/unit/persona_loader_test.dart
git commit -m "test(persona_loader): scaffold failing tests"
```

### Task 1.4: Create the persona.json asset and loader

**Files:**
- Create: `assets/prompts/persona.json`
- Create: `lib/features/rag/persona_loader.dart`

- [ ] **Step 1: Create `assets/prompts/persona.json`**

```jsonc
{
  "bn": {
    "persona": "You are Shongjog — a genuinely warm, lively, and helpful Bangladeshi AI companion.\nYou talk like a real friend, not an assistant. Be natural, be human.\n\nVoice rules:\n- Use contractions, natural rhythm, and real warmth — not corporate politeness or robotic disclaimers.\n- Sound like a knowledgeable friend who genuinely cares, not a textbook or a help desk.\n- Never start with \"As an AI…\" or \"Here is…\" or \"Sure, I can help with that!\" — just answer directly.\n- Never end with generic sign-offs like \"Let me know if you have more questions!\" — end naturally, like a real conversation.\n- Concise by default. Warmer and more detailed when the person seems stressed or needs support.\n- For casual chat, be light and friendly. For emergencies, be calm and clear — still warm, but focused.\n- Match the user's energy: if they're casual, be casual. If they're worried, be reassuring.",
    "rules": "Rules:\n- Always reply in the same language the user used — Bangla, English, or Banglish. Match their language and tone naturally.\n- Keep responses concise and conversational. Use bullet points or numbered steps ONLY when the user is asking for step-by-step emergency or health safety instructions. For casual chat, reply in natural flowing text.\n- Use verified knowledge-base information when available. If no context is provided, answer from general knowledge.\n- Never fabricate medical dosages or treatment steps not in the provided context. If unsure, say so plainly instead of guessing.\n\nSafety rules (CRITICAL):\n- If the query is about a life-threatening emergency (choking, drowning, severe bleeding, cardiac), give the MOST URGENT step FIRST — no preamble.\n- Always include the 999 escalation when the situation is dangerous.\n- If you don't know or the context doesn't cover it, say \"আমি নিশ্চিত নই\" — never guess on medical advice.\n- Correct dangerous myths explicitly: \"না, এটি ভুল\" — never affirm a harmful practice.\n- Use Bengali numerals (০-৯) in all numbered steps, dosages, and quantities.",
    "escalation": "দরকার হলে ৯৯৯ এ কল করুন।",
    "emergencyKeywords": [
      "জরুরি", "স্বাস্থ্য", "রোগ", "চিকিৎসা", "বিপদ", "আঘাত", "ক্ষতি",
      "জ্বর", "পেটে", "বমি", "ডায়রিয়া", "রক্ত", "শ্বাস", "বুকে",
      "মাথা", "ব্যথা", "কাশি", "সর্দি", "এলার্জি", "পোড়া", "কাটা",
      "দুর্ঘটনা", "প্রাণ", "মৃত্যু", "999",
      "emergency", "health", "doctor", "hospital", "pain", "fever", "bleeding",
      "accident", "allergic", "breathing", "chest", "stroke", "poison"
    ],
    "verifiedContextHeader": "=== Verified context ===",
    "verifiedContextHeaderWithCitation": "=== Verified context (cite the source in your answer) ===",
    "userTurnLabel": "User",
    "assistantTurnLabel": "Assistant"
  },
  "en": {
    "persona": "You are Shongjog — a genuinely warm, lively, and helpful Bangladeshi AI companion.\nYou talk like a real friend, not an assistant. Be natural, be human.\n\nVoice rules:\n- Use contractions, natural rhythm, and real warmth — not corporate politeness or robotic disclaimers.\n- Sound like a knowledgeable friend who genuinely cares, not a textbook or a help desk.\n- Never start with \"As an AI…\" or \"Here is…\" or \"Sure, I can help with that!\" — just answer directly.\n- Never end with generic sign-offs like \"Let me know if you have more questions!\" — end naturally, like a real conversation.\n- Concise by default. Warmer and more detailed when the person seems stressed or needs support.\n- For casual chat, be light and friendly. For emergencies, be calm and clear — still warm, but focused.\n- Match the user's energy: if they're casual, be casual. If they're worried, be reassuring.",
    "rules": "Rules:\n- Always reply in the same language the user used — Bangla, English, or Banglish. Match their language and tone naturally.\n- Keep responses concise and conversational. Use bullet points or numbered steps ONLY when the user is asking for step-by-step emergency or health safety instructions. For casual chat, reply in natural flowing text.\n- Use verified knowledge-base information when available. If no context is provided, answer from general knowledge.\n- Never fabricate medical dosages or treatment steps not in the provided context. If unsure, say so plainly instead of guessing.\n\nSafety rules (CRITICAL):\n- If the query is about a life-threatening emergency (choking, drowning, severe bleeding, cardiac), give the MOST URGENT step FIRST — no preamble.\n- Always include the 999 escalation when the situation is dangerous.\n- If you don't know or the context doesn't cover it, say \"I'm not certain\" — never guess on medical advice.\n- Correct dangerous myths explicitly: \"No, that's wrong\" — never affirm a harmful practice.\n- Use Bengali numerals (০-৯) if the user is writing in Bangla; otherwise use Arabic numerals (0-9).",
    "escalation": "If needed, call 999.",
    "emergencyKeywords": [
      "জরুরি", "স্বাস্থ্য", "রোগ", "চিকিৎসা", "বিপদ", "আঘাত", "ক্ষতি",
      "জ্বর", "পেটে", "বমি", "ডায়রিয়া", "রক্ত", "শ্বাস", "বুকে",
      "মাথা", "ব্যথা", "কাশি", "সর্দি", "এলার্জি", "পোড়া", "কাটা",
      "দুর্ঘটনা", "প্রাণ", "মৃত্যু", "999",
      "emergency", "health", "doctor", "hospital", "pain", "fever", "bleeding",
      "accident", "allergic", "breathing", "chest", "stroke", "poison"
    ],
    "verifiedContextHeader": "=== Verified context ===",
    "verifiedContextHeaderWithCitation": "=== Verified context (cite the source in your answer) ===",
    "userTurnLabel": "User",
    "assistantTurnLabel": "Assistant"
  }
}
```

- [ ] **Step 2: Create the loader**

```dart
// lib/features/rag/persona_loader.dart
import 'dart:async';
import 'dart:convert';

import 'package:shongjog/core/text_loader.dart';

/// The persona + rules + escalation system prompt for the chat tier chain.
///
/// Loaded from `assets/prompts/persona.json`. Same key set, two locales —
/// the loader picks the right block based on the active locale tag passed
/// to [loadPersona]. The shape is documented in `docs/content-i18n-sweep.md`.
class PersonaBundle {
  final String persona;
  final String rules;
  final String escalation;
  final List<String> emergencyKeywords;
  final String verifiedContextHeader;
  final String verifiedContextHeaderWithCitation;
  final String userTurnLabel;
  final String assistantTurnLabel;

  const PersonaBundle({
    required this.persona,
    required this.rules,
    required this.escalation,
    required this.emergencyKeywords,
    required this.verifiedContextHeader,
    required this.verifiedContextHeaderWithCitation,
    required this.userTurnLabel,
    required this.assistantTurnLabel,
  });

  /// The combined system instruction — `persona` + `rules`. Used by
  /// `CloudAiService` as its `systemInstruction` parameter.
  String get systemInstruction => '$persona\n$rules';
}

const _kAssetPath = 'assets/prompts/persona.json';

PersonaBundle _decode(String raw) {
  final outer = jsonDecode(raw) as Map<String, dynamic>;
  // Default to bn if the caller passes anything we don't know.
  final block = outer['bn'] as Map<String, dynamic>;
  return PersonaBundle(
    persona: block['persona'] as String,
    rules: block['rules'] as String,
    escalation: block['escalation'] as String,
    emergencyKeywords:
        (block['emergencyKeywords'] as List<dynamic>).cast<String>(),
    verifiedContextHeader: block['verifiedContextHeader'] as String,
    verifiedContextHeaderWithCitation:
        block['verifiedContextHeaderWithCitation'] as String,
    userTurnLabel: block['userTurnLabel'] as String,
    assistantTurnLabel: block['assistantTurnLabel'] as String,
  );
}

Future<PersonaBundle> loadPersona(String? activeLocale) async {
  // Re-dispatch on locale inside the parser so we always pick the right
  // block up-front and never carry the wrong text in memory.
  return TextLoader.loadJson<PersonaBundle>(_kAssetPath, (raw) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, activeLocale);
    return PersonaBundle(
      persona: block['persona'] as String,
      rules: block['rules'] as String,
      escalation: block['escalation'] as String,
      emergencyKeywords:
          (block['emergencyKeywords'] as List<dynamic>).cast<String>(),
      verifiedContextHeader: block['verifiedContextHeader'] as String,
      verifiedContextHeaderWithCitation:
          block['verifiedContextHeaderWithCitation'] as String,
      userTurnLabel: block['userTurnLabel'] as String,
      assistantTurnLabel: block['assistantTurnLabel'] as String,
    );
  });
}

/// The parser used by [TextLoader.loadJson] for the persona asset.
/// Held as a top-level so [TextLoader] can call it without re-allocating.
PersonaBundle decodePersonaBundle(String raw, String? activeLocale) {
  final outer = jsonDecode(raw) as Map<String, dynamic>;
  final block = TextLoader.pickBundle(outer, activeLocale);
  return PersonaBundle(
    persona: block['persona'] as String,
    rules: block['rules'] as String,
    escalation: block['escalation'] as String,
    emergencyKeywords: (block['emergencyKeywords'] as List<dynamic>).cast<String>(),
    verifiedContextHeader: block['verifiedContextHeader'] as String,
    verifiedContextHeaderWithCitation: block['verifiedContextHeaderWithCitation'] as String,
    userTurnLabel: block['userTurnLabel'] as String,
    assistantTurnLabel: block['assistantTurnLabel'] as String,
  );
}
```

- [ ] **Step 3: Drop the unused `_decode` helper if you don't need it (DRY): remove the `_decode` function above and make `loadPersona` use `decodePersonaBundle` directly.**

```dart
Future<PersonaBundle> loadPersona(String? activeLocale) async {
  return TextLoader.loadJson<PersonaBundle>(
    _kAssetPath,
    (raw) => decodePersonaBundle(raw, activeLocale),
  );
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/unit/persona_loader_test.dart 2>&1 | tail -10
```

Expected: 2 tests pass.

- [ ] **Step 5: Replace the const-literal body of `lib/rag/prompt_builder.dart` with the loader-driven version**

```dart
// lib/rag/prompt_builder.dart
//
// Persona / rules / escalation now live in assets/prompts/persona.json —
// kept DRY between Tier-1 (Cloud) and Tier-2 (Device) by both loaders
// calling loadPersona(activeLocale).

import 'package:shongjog/features/rag/persona_loader.dart';
import 'types.dart';

const int kMaxHistoryTurns = 4;

/// Returns true if the user query looks like a health/safety topic.
bool isEmergencyQuery(String query, PersonaBundle persona) {
  final q = query.toLowerCase();
  return persona.emergencyKeywords.any((kw) => q.contains(kw.toLowerCase()));
}

/// Build the user-side message that goes on top of an existing
/// `systemInstruction` (Cloud AI path).
String buildUserMessage({
  required String query,
  required List<RetrievalHit> hits,
  required PersonaBundle persona,
}) {
  final buf = StringBuffer();
  if (hits.isNotEmpty) {
    buf
      ..writeln(persona.verifiedContextHeader)
      ..writeln(hits
          .map((h) => '[${h.chunk.source}] ${h.chunk.text}')
          .join('\n\n'))
      ..writeln();
  }
  buf.write(query);
  if (isEmergencyQuery(query, persona)) {
    buf
      ..writeln()
      ..writeln()
      ..write(persona.escalation);
  }
  return buf.toString();
}

/// Build the full prompt for the on-device path.
String buildPrompt({
  required String query,
  required List<RetrievalHit> hits,
  required PersonaBundle persona,
  List<ChatTurn> history = const [],
}) {
  final buf = StringBuffer()
    ..writeln(persona.persona)
    ..writeln(persona.rules)
    ..writeln();
  if (hits.isNotEmpty) {
    buf
      ..writeln(persona.verifiedContextHeaderWithCitation)
      ..writeln(hits
          .map((h) => '[Source: ${h.chunk.source}] ${h.chunk.text}')
          .join('\n\n'))
      ..writeln();
  }
  final capped = history.length > kMaxHistoryTurns
      ? history.sublist(history.length - kMaxHistoryTurns)
      : history;
  for (final turn in capped) {
    buf.writeln('${turn.isUser ? persona.userTurnLabel : persona.assistantTurnLabel}: ${turn.text}');
  }
  buf
    ..writeln('${persona.userTurnLabel}: $query')
    ..write('${persona.assistantTurnLabel}:');
  if (isEmergencyQuery(query, persona)) {
    buf
      ..writeln()
      ..writeln()
      ..write(persona.escalation);
  }
  return buf.toString();
}
```

- [ ] **Step 6: Fix every call site of the renamed APIs**

```bash
grep -rn "buildUserMessage\|buildPrompt(\|isEmergencyQuery\|kSystemInstruction" lib
```

Update each call to pass a `PersonaBundle` (load via `await loadPersona(locale.languageCode)`) and replace `kSystemInstruction` with `persona.systemInstruction`. Specifically:

- `lib/features/chat/chat_repository.dart` — load persona once per `ask()` and pass it to `buildUserMessage` / `buildPrompt` / `isEmergencyQuery`.
- `lib/features/cloud_ai/cloud_ai_service.dart` — accept an injected `PersonaBundle` (or load via the same loader), replace the `kSystemInstruction` reference.

- [ ] **Step 7: Run the full test suite**

```bash
flutter test 2>&1 | tail -5
```

Expected: `All tests passed!` count unchanged (or higher from new tests added in step 1.3 / 1.4). 

- [ ] **Step 8: Commit**

```bash
git add assets/prompts/persona.json lib/features/rag/persona_loader.dart \
        lib/rag/prompt_builder.dart \
        $(grep -rl "kSystemInstruction\|buildUserMessage\|buildPrompt(\|isEmergencyQuery" lib --include="*.dart")
git commit -m "feat(rag): persona, rules, escalation now load from assets/prompts/persona.json"
```

---

## Phase 2 — Data tables → JSON

### Task 2.1: Move quick cards (Group B, first)

**Files:**
- Create: `assets/data/cards.json`
- Create: `lib/features/quick_cards/cards_loader.dart`
- Modify: `lib/features/quick_cards/cards_data.dart`
- Modify: `lib/features/quick_cards/quick_cards_screen.dart`
- Test (existing): `test/widget/quick_cards_screen_test.dart`

- [ ] **Step 1: Inventory the existing 25 cards**

```bash
grep -E "titleBn:|titleEn:|id:" lib/features/quick_cards/cards_data.dart | head -80
```

- [ ] **Step 2: Build `assets/data/cards.json` — bilingual, all 25 entries**

Shape:
```jsonc
{
  "version": 1,
  "bn": [
    {
      "id": "ors_basic",
      "titleBn": "ORS তৈরি",
      "stepsBn": ["১ লিটার পরিষ্কার পানি নিন", "৬ চা-চামচ চিনি…", "…"],
      "iconName": "local_drink",
      "colorHex": "#FF6F61"
    }
  ],
  "en": [
    {
      "id": "ors_basic",
      "title": "Make ORS",
      "steps": ["Take 1 litre of clean water", "Add 6 teaspoons of sugar…", "…"],
      "iconName": "local_drink",
      "colorHex": "#FF6F61"
    }
  ]
}
```

Use the icon name registry below — these are the only icons we currently use in `cards_data.dart`:
```
local_drink, water_drop, house, shield, medical_services, restaurant,
directions_run, bolt, waves, wb_sunny, terrain, air, family_restroom,
pets, phone, group, school, kid_stars, info, more_horiz, shopping_basket,
celebration, medical_information, location_on, inventory_2
```

Use the colour hexes that are already in `cards_data.dart` (no new colours introduced).

- [ ] **Step 3: Write `cards_loader.dart`**

```dart
// lib/features/quick_cards/cards_loader.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/text_loader.dart';

class QuickCardEntry {
  final String id;
  final String title;
  final List<String> steps;
  final IconData icon;
  final Color color;

  const QuickCardEntry({
    required this.id,
    required this.title,
    required this.steps,
    required this.icon,
    required this.color,
  });
}

const _kIconRegistry = <String, IconData>{
  'local_drink': Icons.local_drink,
  'water_drop': Icons.water_drop,
  'house': Icons.house,
  'shield': Icons.shield,
  'medical_services': Icons.medical_services,
  'restaurant': Icons.restaurant,
  'directions_run': Icons.directions_run,
  'bolt': Icons.bolt,
  'waves': Icons.waves,
  'wb_sunny': Icons.wb_sunny,
  'terrain': Icons.terrain,
  'air': Icons.air,
  'family_restroom': Icons.family_restroom,
  'pets': Icons.pets,
  'phone': Icons.phone,
  'group': Icons.group,
  'school': Icons.school,
  'kid_stars': Icons.kid_stars,
  'info': Icons.info,
  'more_horiz': Icons.more_horiz,
  'shopping_basket': Icons.shopping_basket,
  'celebration': Icons.celebration,
  'medical_information': Icons.medical_information,
  'location_on': Icons.location_on,
  'inventory_2': Icons.inventory_2,
};

QuickCardEntry _parse(Map<String, dynamic> j) => QuickCardEntry(
      id: j['id'] as String,
      title: (j['title'] ?? j['titleBn']) as String,
      steps: (j['steps'] ?? j['stepsBn'] as List<dynamic>).cast<String>(),
      icon: _kIconRegistry[j['iconName'] as String] ?? Icons.info,
      color: Color(int.parse(
        (j['colorHex'] as String).replaceFirst('#', ''),
        radix: 16,
      ) | 0xFF000000),
    );

Future<List<QuickCardEntry>> loadQuickCards(String? activeLocale) async {
  return TextLoader.loadJson<List<QuickCardEntry>>(
    'assets/data/cards.json',
    (raw) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      final list = TextLoader.pickBundle(outer, activeLocale)['cards']
          as List<dynamic>;
      return list
          .map((e) => _parse(e as Map<String, dynamic>))
          .toList(growable: false);
    },
  );
}
```

(The JSON file in step 2 must wrap the cards in a `"cards"` key inside `bn`/`en` — i.e. `{"bn":{"cards":[…]},"en":{"cards":[…]}}` — adjust accordingly.)

- [ ] **Step 4: Replace `lib/features/quick_cards/cards_data.dart` with a thin shim that re-exports the loader**

```dart
// lib/features/quick_cards/cards_data.dart
//
// Quick-card entries now live in assets/data/cards.json. This file used
// to hold a hand-written 25-card list; it now re-exports the loader's
// typed shape so callers can be migrated incrementally.
//
// Old API: `final cards = staticCards(locale.languageCode);` returning
// `List<QuickCard>` (kept for backwards-compat — see `staticCards`).
// New API: `final cards = await loadQuickCards(locale.languageCode);`.

import '../../core/text_loader.dart';
import 'cards_loader.dart';

export 'cards_loader.dart' show QuickCardEntry;

/// Backwards-compat alias used by screens we have not yet migrated.
typedef QuickCard = QuickCardEntry;

/// Kept for backwards compatibility — screens should migrate to
/// `loadQuickCards` (which is async). For synchronous test use we cache
/// the last loaded list.
List<QuickCardEntry>? _lastLoaded;

Future<List<QuickCardEntry>> staticCards(String? locale) async {
  final list = await loadQuickCards(locale);
  _lastLoaded = list;
  return list;
}

/// Synchronous accessor — only valid after `staticCards` has been awaited
/// at least once in the same isolate.
List<QuickCardEntry> cachedCards() {
  final l = _lastLoaded;
  if (l == null) {
    throw StateError('Call staticCards(locale) first to populate the cache.');
  }
  return l;
}
```

- [ ] **Step 5: Update `quick_cards_screen.dart` to await the loader**

Replace any top-level `const cards = [...]` usage with an `initState()`-driven async load. Save the loaded list in `_cards` and call `setState`.

- [ ] **Step 6: Run the existing quick-cards widget test**

```bash
flutter test test/widget/quick_cards_screen_test.dart 2>&1 | tail -10
```

Expected: passes (the test name resolves through the loader's bn fallback).

- [ ] **Step 7: Run the full suite**

```bash
flutter test 2>&1 | tail -5
```

- [ ] **Step 8: Commit**

```bash
git add assets/data/cards.json lib/features/quick_cards/
git commit -m "feat(cards): quick cards now load from assets/data/cards.json (bn+en)"
```

### Task 2.2: Move district data

**Files:**
- Create: `assets/data/districts.json`
- Create: `lib/features/profile/districts_loader.dart`
- Modify: `lib/features/profile/district_data.dart`

- [ ] **Step 1: Capture the current `districts` map shape**

```bash
grep -n "_districts\|Map<String, List<String>>\|'ঢাকা'" lib/features/profile/district_data.dart | head -5
```

Shape:
```jsonc
{
  "bn": {
    "ঢাকা": ["ঢাকা", "গাজীপুর", "নারায়ণগঞ্জ", "মানিকগঞ্জ", "মুন্সিগঞ্জ", "রাজবাড়ী", "ফরিদপুর"],
    "চট্টগ্রাম": ["চট্টগ্রাম", "কক্সবাজার", …]
  },
  "en": {
    "Dhaka": ["Dhaka", "Gazipur", "Narayanganj", "Manikganj", "Munshiganj", "Rajbari", "Faridpur"],
    "Chattogram": ["Chattogram", "Cox's Bazar", …]
  }
}
```

- [ ] **Step 2: Create the JSON — bilingual**

Use the canonical English district transliterations: Barisal → Barishal, Chittagong → Chattogram, Comilla → Cumilla, Jessore → Jashore, etc. (matches the project's existing transliteration choices in `directory.json`).

- [ ] **Step 3: Write the loader**

```dart
// lib/features/profile/districts_loader.dart
import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/data/districts.json';

Future<Map<String, List<String>>> loadDistricts(String? activeLocale) {
  return TextLoader.loadJson<Map<String, List<String>>>(
    _kAssetPath,
    (raw) {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      final block = TextLoader.pickBundle(outer, activeLocale);
      return (block as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      );
    },
  );
}
```

- [ ] **Step 4: Replace `district_data.dart` with a re-export of the loader**

```dart
// lib/features/profile/district_data.dart
//
// District lists now live in assets/data/districts.json (bilingual).
export 'districts_loader.dart';
```

- [ ] **Step 5: Find all call sites and update them**

```bash
grep -rn "_districts\|districtData" lib --include="*.dart"
```

Replace each call with an `await loadDistricts(locale.languageCode)`.

- [ ] **Step 6: Run the full suite**

```bash
flutter test 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add assets/data/districts.json lib/features/profile/
git commit -m "feat(profile): district names now load from assets/data/districts.json (bn+en)"
```

### Task 2.3: Move emergency directory

**Files:**
- Create: `assets/data/emergency_directory.json`
- Modify: `lib/features/emergency/directory_loader.dart`
- Delete (after Task 2.3.5): `assets/emergency/directory.json`
- Delete (after Task 2.3.5): the `assets/emergency/` line in `pubspec.yaml`

- [ ] **Step 1: Capture the current `directory.json`**

```bash
cat assets/emergency/directory.json > /tmp/directory.json.backup
wc -l assets/emergency/directory.json
```

- [ ] **Step 2: Convert into bilingual shape**

The shape stays an array; each row gains `name` (English) + `nameBn` already exists. Save as `assets/data/emergency_directory.json` (the same payload, just bilingual-confirmed).

- [ ] **Step 3: Point the loader at the new path**

```dart
// lib/features/emergency/directory_loader.dart (path-only change)
static const _assetPath = 'assets/data/emergency_directory.json';
```

- [ ] **Step 4: Run**

```bash
flutter test test/unit/eonet_service_test.dart test/unit/gdacs_service_test.dart 2>&1 | tail -5
```

- [ ] **Step 5: Remove old asset + pubspec line + commit**

```bash
git rm assets/emergency/directory.json
git add pubspec.yaml  # remove the `assets/emergency/` line
git add assets/data/emergency_directory.json lib/features/emergency/directory_loader.dart
git commit -m "feat(directory): move emergency directory to assets/data/, bilingual"
```

### Task 2.4: Move RAG corpus

**Files:**
- Create: `assets/data/corpus.json`
- Modify: `lib/knowledge/kb_loader.dart`
- Delete (after Task 2.4.5): `assets/kb/corpus.json`
- Modify: `assets/kb/meta.json` (no shape change, only `metaJson: num_chunks: 48`)

- [ ] **Step 1: Capture current corpus + vectors**

```bash
cp assets/kb/corpus.json /tmp/corpus.json.backup
ls -la assets/kb/
```

- [ ] **Step 2: Re-embed the corpus with the existing multilingual model**

```bash
# Only if a re-embed is in scope (decision pending — confirm with the user
# before running the embedder; default to "punt to v0.9, copy vectors.bin
# as-is" unless explicitly authorised).
# If YES, run the project's existing tool/bundle_embedder.py against
# assets/data/corpus.json (bn) + a future assets/data/corpus_en.json
# (en), and write a single bilingual vectors.bin or two parallel files.
# If NO, copy vectors.bin into place as-is and ship bn-only corpus in v0.9.
```

Decision: confirm with the user before running the embedder. If the answer is "punt to v0.9", skip to step 3.

- [ ] **Step 3: Bilingualise the corpus**

Open `/tmp/corpus.json.backup`, add `lang: "bn"` is already present, add parallel `en.text` and `en.source` per row in `assets/data/corpus.json`:

```jsonc
[
  {
    "id": "ors_recipe_basic",
    "topic": "ors",
    "lang": "bn",
    "source_bn": "WHO Cholera fact sheet, 2024",
    "text_bn": "ORS তৈরির সহজ উপায়: ১ লিটার পরিষ্কার পানি নিন। …",
    "keywords_bn": ["ORS", "ডায়রিয়া", "পানিশূন্যতা", …],
    "source": "WHO Cholera fact sheet, 2024",
    "text": "ORS preparation: Take 1 litre of clean water. ...",
    "keywords": ["ORS", "diarrhoea", "dehydration", …]
  }
]
```

- [ ] **Step 4: Update `kb_loader.dart`**

```dart
// lib/knowledge/kb_loader.dart (path + bilingual parsing)
static const _kCorpusPath = 'assets/data/corpus.json';
// ... existing parser, but reads 'text' instead of 'text_bn', and 'keywords'
// instead of 'keywords_bn'. The `lang` field is dropped from each chunk
// because the loader is locale-aware now.
```

- [ ] **Step 5: Run + commit**

```bash
flutter test test/unit/keyword_retriever_test.dart 2>&1 | tail -5
git rm assets/kb/corpus.json
git add assets/data/corpus.json lib/knowledge/kb_loader.dart
git commit -m "feat(kb): corpus now bilingual, lives in assets/data/corpus.json"
```

### Task 2.5: Confirm Phase 2 cleanup

- [ ] **Step 1: `flutter pub get` + full test + analyze**

```bash
flutter pub get
flutter test 2>&1 | tail -5
flutter analyze --fatal-infos 2>&1 | tail -5
```

- [ ] **Step 2: Snapshot the Bangla-literal count**

```bash
grep -rP "[\x{0980}-\x{09FF}]" lib --include="*.dart" -c \
  | grep -v ":0$" | grep -v "app_localizations_" \
  | awk -F: '{sum+=$2} END {print sum}'
```

Expected: ~700 fewer than the 1451 baseline (≈ 750, the count of Bangla lines in cards + districts + prompts).

- [ ] **Step 3: Commit the snapshot**

```bash
echo "$(grep -rP "[\x{0980}-\x{09FF}]" lib --include="*.dart" -c | grep -v ":0$" | grep -v "app_localizations_" | awk -F: '{sum+=$2} END {print sum}')" > AFTER-phase-2-bangla-count.txt
git add AFTER-phase-2-bangla-count.txt
git commit -m "chore(text): record Bangla-literal count after phase 2"
```

---

## Phase 3 — Prompts → JSON (the long stretch)

### Task 3.1: Planner prompt

**Files:**
- Create: `assets/prompts/planner.json`
- Create: `lib/features/planner/prompt_loader.dart`
- Modify: `lib/features/planner/planner_prompt_builder.dart`
- Modify: existing test `test/unit/planner_prompt_builder_test.dart`

- [ ] **Step 1: Extract every Bangla literal from `planner_prompt_builder.dart` into the asset**

`assets/prompts/planner.json`:
```jsonc
{
  "bn": {
    "buildPlan": {
      "intro": [
        "তুমি সংযোগ, একজন উষ্ণ বাংলা দুর্যোগ সহায়ক।",
        "নিচের পরিবারের তথ্যের ভিত্তিতে একটি ব্যক্তিগতকৃত দুর্যোগ প্রস্তুতি পরিকল্পনা তৈরি করো। বাংলায় উত্তর দাও। বাংলা সংখ্যা (০-৯) ব্যবহার করো।"
      ],
      "sectionFamily": "পরিবারের তথ্য:",
      "rowTotal": "• মোট সদস্য: {n} জন",
      "rowChildren": "• শিশু: {n} জন",
      "rowElderly": "• প্রবীণ: {n} জন",
      "rowPets": "• পোষা প্রাণী আছে",
      "rowHomeType": "• ঘরের ধরন: {name}",
      "rowFloor": "• ফ্ল্যাটের তলা: {n}",
      "rowMedical": "• চিকিৎসা অবস্থা: {list}",
      "rowRiver": "• নিকটবর্তী নদী আছে",
      "rowCoast": "• সমুদ্রতীরের কাছে",
      "sectionIncludes": "যা যা অন্তর্ভুক্ত করো:",
      "includes": [
        "১. জরুরি পদক্ষেপ (ঘূর্ণিঝড়/বন্যা আসার আগে ও সময়)",
        "২. স্থানান্তর পরিকল্পনা (কোথায় যাবেন, কীভাবে)",
        "৩. বিশেষ সতর্কতা (শিশু, প্রবীণ, পোষা প্রাণী, চিকিৎসা)",
        "৪. জরুরি যোগাযোগের তালিকা",
        "৫. প্রস্তুতির সময়রেখা"
      ],
      "tailLabel": "পরিকল্পনা:"
    },
    "fallbackPlan": {
      "heading": "সাধারণ দুর্যোগ প্রস্তুতি পরিকল্পনা:",
      "lines": [
        "১. নিরাপদ শূন্যস্থান চিহ্নিত করুন (নিকটস্থ সাইক্লোন শেল্টার)।",
        "২. জরুরি কিট প্রস্তুত রাখুন (পানি, খাবার, ওষুধ, ফ্ল্যাশলাইট)।",
        "৩. গুরুত্বপূর্ণ কাগজপত্র জলরোধী ব্যাগে রাখুন।",
        "৪. {childrenLine}",
        "৫. {elderlyLine}",
        "৬. স্থানান্তরের রুট আগে থেকে জেনে রাখুন।"
      ],
      "withChildren": "শিশুদের জন্য বিশেষ খাবার ও কাপড় প্রস্তুত রাখুন।",
      "withoutChildren": "প্রতিটি সদস্যের জন্য পর্যাপ্ত খাবার ও পানি রাখুন।",
      "withElderly": "প্রবীণদের ওষুধ ও বিশেষ যত্নের তালিকা তৈরি করুন।",
      "withoutElderly": "প্রতিটি সদস্যের দায়িত্ব নির্ধারণ করুন।",
      "tailEscalation": "জরুরি সাহায্যের জন্য ৯৯৯ এ কল করুন।"
    }
  },
  "en": {
    "buildPlan": {
      "intro": [
        "You are Shongjog, a warm Bangladeshi disaster-prep assistant.",
        "Using the family information below, draft a personalised disaster preparedness plan. Reply in English."
      ],
      "sectionFamily": "Family information:",
      "rowTotal": "• Total members: {n}",
      "rowChildren": "• Children: {n}",
      "rowElderly": "• Elderly: {n}",
      "rowPets": "• Pets present",
      "rowHomeType": "• Home type: {name}",
      "rowFloor": "• Apartment floor: {n}",
      "rowMedical": "• Medical conditions: {list}",
      "rowRiver": "• Near a river",
      "rowCoast": "• Near the coast",
      "sectionIncludes": "Include:",
      "includes": [
        "1. Emergency steps (before and during a cyclone/flood)",
        "2. Evacuation plan (where, how)",
        "3. Special cautions (children, elderly, pets, medical)",
        "4. Emergency contact list",
        "5. Preparedness timeline"
      ],
      "tailLabel": "Plan:"
    },
    "fallbackPlan": {
      "heading": "General disaster preparedness plan:",
      "lines": [
        "1. Identify a safe zone (nearest cyclone shelter).",
        "2. Keep an emergency kit ready (water, food, medicine, flashlight).",
        "3. Store important documents in waterproof bags.",
        "4. {childrenLine}",
        "5. {elderlyLine}",
        "6. Know the evacuation route in advance."
      ],
      "withChildren": "Prepare special food and clothing for the children.",
      "withoutChildren": "Keep enough food and water for every member.",
      "withElderly": "Prepare a list of medications and special care for the elderly.",
      "withoutElderly": "Assign a responsibility to every member.",
      "tailEscalation": "For emergencies, call 999."
    }
  }
}
```

- [ ] **Step 2: Write `lib/features/planner/prompt_loader.dart`**

```dart
// lib/features/planner/prompt_loader.dart
import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/planner.json';

class PlannerPromptBundle {
  final Map<String, dynamic> buildPlan;
  final Map<String, dynamic> fallbackPlan;
  const PlannerPromptBundle({required this.buildPlan, required this.fallbackPlan});
}

PlannerPromptBundle _parse(String raw, String? locale) {
  final outer = jsonDecode(raw) as Map<String, dynamic>;
  final block = TextLoader.pickBundle(outer, locale);
  return PlannerPromptBundle(
    buildPlan: block['buildPlan'] as Map<String, dynamic>,
    fallbackPlan: block['fallbackPlan'] as Map<String, dynamic>,
  );
}

Future<PlannerPromptBundle> loadPlannerPrompts(String? locale) {
  return TextLoader.loadJson<PlannerPromptBundle>(
    _kAssetPath,
    (raw) => _parse(raw, locale),
  );
}
```

- [ ] **Step 3: Update `planner_prompt_builder.dart`**

```dart
// lib/features/planner/planner_prompt_builder.dart
//
// Prompt text now lives in assets/prompts/planner.json (bn+en).
// This file contains only the *structure* of the prompt.
import 'package:shongjog/core/bangla_numerals.dart';
import 'family_profile.dart';
import 'prompt_loader.dart';

class PlannerPromptBuilder {
  PlannerPromptBuilder._();

  static String? buildPlanSync(FamilyProfile p, PlannerPromptBundle bundle) {
    if (p.isEmpty) return null;
    final bp = bundle.buildPlan;
    final buf = StringBuffer();
    for (final line in (bp['intro'] as List<dynamic>).cast<String>()) {
      buf.writeln(line);
    }
    buf.writeln();
    buf.writeln(bp['sectionFamily'] as String);
    buf.writeln(_t(bp, 'rowTotal', {'n': p.familySize}));
    if (p.childrenCount > 0) {
      buf.writeln(_t(bp, 'rowChildren', {'n': p.childrenCount}));
    }
    if (p.elderlyCount > 0) {
      buf.writeln(_t(bp, 'rowElderly', {'n': p.elderlyCount}));
    }
    if (p.hasPets) buf.writeln(bp['rowPets'] as String);
    buf.writeln(_t(bp, 'rowHomeType', {'name': p.homeType.name}));
    if (p.homeType == HomeType.apartment && p.floorNumber != null) {
      buf.writeln(_t(bp, 'rowFloor', {'n': p.floorNumber}));
    }
    if (p.medicalConditions.isNotEmpty) {
      buf.writeln(_t(bp, 'rowMedical', {'list': p.medicalConditions.join(', ')}));
    }
    if (p.nearbyRiver) buf.writeln(bp['rowRiver'] as String);
    if (p.nearbyCoast) buf.writeln(bp['rowCoast'] as String);
    buf.writeln();
    buf.writeln(bp['sectionIncludes'] as String);
    for (final line in (bp['includes'] as List<dynamic>).cast<String>()) {
      buf.writeln(line);
    }
    buf.writeln();
    buf.write(bp['tailLabel'] as String);
    return buf.toString();
  }

  static String fallbackPlanSync(FamilyProfile p, PlannerPromptBundle bundle) {
    final fb = bundle.fallbackPlan;
    final buf = StringBuffer();
    buf.writeln(fb['heading'] as String);
    buf.writeln();
    final childrenLine = p.childrenCount > 0
        ? fb['withChildren'] as String
        : fb['withoutChildren'] as String;
    final elderlyLine = p.elderlyCount > 0
        ? fb['withElderly'] as String
        : fb['withoutElderly'] as String;
    for (final line in (fb['lines'] as List<dynamic>).cast<String>()) {
      buf.writeln(line
          .replaceAll('{childrenLine}', childrenLine)
          .replaceAll('{elderlyLine}', elderlyLine));
    }
    buf.writeln();
    buf.write(fb['tailEscalation'] as String);
    return buf.toString();
  }

  static String _t(Map<String, dynamic> block, String key, Map<String, Object?> args) {
    final raw = block[key] as String;
    var out = raw;
    args.forEach((k, v) {
      out = out.replaceAll('{$k}', v.toString());
    });
    return out;
  }
}
```

- [ ] **Step 4: Update existing planner-prompt-builder test to load the bundle**

```dart
// test/unit/planner_prompt_builder_test.dart
import 'package:shongjog/core/text_loader.dart';
import 'package:shongjog/features/planner/prompt_loader.dart';
import 'package:shongjog/features/planner/planner_prompt_builder.dart';
import 'package:shongjog/features/planner/family_profile.dart';

void main() {
  setUp(() => TextLoader.debugClearCache());

  test('buildPlanSync returns null for empty profile', () async {
    final bundle = await loadPlannerPrompts('bn');
    expect(PlannerPromptBuilder.buildPlanSync(FamilyProfile.empty(), bundle), isNull);
  });

  test('buildPlanSync includes family rows (bn)', () async {
    final bundle = await loadPlannerPrompts('bn');
    final p = FamilyProfile.sample(seed: 1);
    final out = PlannerPromptBuilder.buildPlanSync(p, bundle);
    expect(out, contains('পরিবারের তথ্য'));
    expect(out, contains('৯৯৯'));
  });

  test('buildPlanSync includes family rows (en)', () async {
    final bundle = await loadPlannerPrompts('en');
    final p = FamilyProfile.sample(seed: 1);
    final out = PlannerPromptBuilder.buildPlanSync(p, bundle);
    expect(out, contains('Family information'));
    expect(out, contains('999'));
  });
}
```

- [ ] **Step 5: Fix all call sites**

```bash
grep -rn "PlannerPromptBuilder.buildPlan\b\|PlannerPromptBuilder.fallbackPlan" lib --include="*.dart"
```

For each site:
```dart
final bundle = await loadPlannerPrompts(locale.languageCode);
final plan = PlannerPromptBuilder.buildPlanSync(profile, bundle);
```

- [ ] **Step 6: Run tests**

```bash
flutter test test/unit/planner_prompt_builder_test.dart 2>&1 | tail -10
flutter test 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add assets/prompts/planner.json lib/features/planner/
git commit -m "feat(planner): planner prompt now loads from assets/prompts/planner.json"
```

### Task 3.2: Kit prompt

**Files:**
- Create: `assets/prompts/kit.json`
- Create: `lib/features/planner/kit_prompt_loader.dart`
- Modify: `lib/features/planner/kit_prompt_builder.dart`
- Modify: existing test `test/unit/kit_prompt_builder_test.dart`

- [ ] **Step 1: Extract kit's Bangla literals into `kit.json`**

The kit prompt builder has roughly 28 lines of Bangla. The JSON shape mirrors `planner.json`: `{bn: {…}, en: {…}}`. English translations are idiomatic — for example, "জরুরি কিট" → "Emergency Kit", "পরিবারের সদস্য" → "Family Member", "বয়স" → "age".

- [ ] **Step 2: Write the loader (same pattern as `prompt_loader.dart` — copy + adapt)**

- [ ] **Step 3: Update the builder** — strip literals, replace with bundle lookups (same `_t()` pattern as Task 3.1).

- [ ] **Step 4: Update existing test to load the bundle**

- [ ] **Step 5: Run + commit**

```bash
flutter test test/unit/kit_prompt_builder_test.dart 2>&1 | tail -5
flutter test 2>&1 | tail -5
git add assets/prompts/kit.json lib/features/planner/
git commit -m "feat(kit): kit prompt now loads from assets/prompts/kit.json"
```

### Task 3.3: Risk prompt

Same pattern as Task 3.2.

- Files: `assets/prompts/risk.json`, `lib/features/planner/risk_prompt_loader.dart`, `lib/features/planner/risk_prompt_builder.dart`, `test/unit/risk_prompt_builder_test.dart`
- Commit: `feat(risk): risk prompt now loads from assets/prompts/risk.json`

### Task 3.4: Urgency, rumour, repetition (RAG tier)

- Files (urgency):
  - Create `assets/prompts/urgency.json`
  - Create `lib/rag/urgency_loader.dart`
  - Modify `lib/rag/urgency_classifier.dart`
  - Modify existing test
- Files (rumour):
  - Create `assets/prompts/rumour.json`
  - Create `lib/rag/rumour_loader.dart`
  - Modify `lib/rag/rumour_checker.dart`
  - Modify existing test
- Files (repetition):
  - Create `assets/prompts/repetition.json`
  - Create `lib/rag/repetition_loader.dart`
  - Modify `lib/rag/repetition_detector.dart`
  - Modify existing test

Each follows the loader pattern from Tasks 3.1-3.3. English counterparts: every Bangla excerpt in each prompt + the regex exemplar in `repetition_detector.dart` (parsed from `assets/prompts/repetition.json` under `regexPatterns.bn` / `regexPatterns.en`).

Commit each as a single task (3.4a urgency, 3.4b rumour, 3.4c repetition).

### Task 3.5: Damage-scan, situation-summary, shelter (single combined task)

These three families share the same loader pattern, so we batch them:

- Files (damage_scan):
  - Create `assets/prompts/damage_scan.json`, `lib/features/damage_scanner/scan_loader.dart`
  - Modify `lib/features/damage_scanner/damage_scan_service.dart`
  - Existing test
- Files (situation_summary):
  - Create `assets/prompts/situation_summary.json`, `lib/features/intelligence/summary_loader.dart`
  - Modify `lib/features/intelligence/situation_summary_service.dart`
  - Existing test
- Files (shelter):
  - Create `assets/prompts/shelter.json`, `lib/features/shelter/shelter_loaders.dart`
  - Modify `lib/features/shelter/shelter_brief_builder.dart`, `shelter_tool_dispatcher.dart`, `shelter_tool_result_formatter.dart`, `semantic_search_service.dart`, `nominatim_service.dart`
  - Existing test(s)

English copy is drafted inline. Single commit at the end:

```bash
git commit -m "feat(prompts): damage_scan + situation_summary + shelter prompts load from assets/prompts/"
```

### Task 3.6: Phase 3 cleanup

- [ ] **Step 1: Grep sweep**

```bash
grep -rP "[\x{0980}-\x{09FF}]" lib --include="*.dart" -c \
  | grep -v ":0$" | grep -v "app_localizations_" \
  | awk -F: '{sum+=$2} END {print sum}'
```

Expected: should be < 200 (down from 1451), and concentrated in:
- comment-only files (`theme.dart`, `device_capability.dart`, `typewriter_text.dart` — allow-listed)
- notification copy moving in Phase 4

- [ ] **Step 2: Full test + analyze**

```bash
flutter test 2>&1 | tail -5
flutter analyze --fatal-infos 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
echo "<count>" > AFTER-phase-3-bangla-count.txt
git add AFTER-phase-3-bangla-count.txt
git commit -m "chore(text): record Bangla-literal count after phase 3"
```

---

## Phase 4 — UI strings → ARB (Group A)

### Task 4.1: Inventory the remaining user-facing copy

- [ ] **Step 1: List every file outside the allowlist that still contains user-facing Bangla**

```bash
grep -rPn "[\x{0980}-\x{09FF}]" lib --include="*.dart" \
  | grep -v "app_localizations_" \
  | grep -v "^.*:.*//" \
  | grep -v "^.*:.*///" \
  | grep -v "_loader.dart:"
```

This is the list of files that need Group A changes.

### Task 4.2: Add new keys to both ARB files

For each user-facing Bangla string identified in Task 4.1:

- [ ] **Step 1: Pick a key in snake_case** (e.g. `chatCannedCantAnswer`, `demoQueryFire`, `notifChannelTitle`, `safeBeaconSafeDefault`, `sosGpsUnavailableDefault`).

- [ ] **Step 2: Add to `app_bn.arb` with the existing Bangla text**

```jsonc
"chatCannedCantAnswer": "আমার কাছে এই প্রশ্নের উত্তর নেই। ৯৯৯ এ কল করুন।",
"@chatCannedCantAnswer": {
  "description": "Canned Tier-4 fallback message when the chat pipeline can't answer."
}
```

- [ ] **Step 3: Add to `app_en.arb` with the English counterpart**

```jsonc
"chatCannedCantAnswer": "I don't have an answer for this. Please call 999.",
"@chatCannedCantAnswer": {
  "description": "Canned Tier-4 fallback message when the chat pipeline can't answer."
}
```

- [ ] **Step 4: Run `flutter gen-l10n`**

```bash
flutter gen-l10n 2>&1 | tail -5
```

### Task 4.3: Replace literal text with `AppLocalizations.of(context).x` (or equivalent for services)

Repeat for each affected file:

- `lib/features/chat/chat_repository.dart` line ~187
- `lib/features/chat/demo_seeder.dart` (3 queries)
- `lib/core/local_notification_service.dart` (Android tray title)
- `lib/features/safe_beacon/safe_beacon_payload.dart` (default payload)
- `lib/features/emergency/sos_sms_template.dart` (default + body)
- `lib/features/emergency/sos_function_schema.dart` (function-call copy)
- `lib/features/emergency/sos_composer_screen.dart` (UI)
- `lib/features/emergency/emergency_sheet.dart` (UI)
- `lib/features/intelligence/{notification_service,proximity_notification_service}.dart`
- `lib/features/intelligence/{intelligence_engine,user_profile,situation_summary_screen}.dart`
- `lib/features/admin/admin_pages.dart`
- `lib/features/about/about_screen.dart`
- `lib/features/home/{live_hazards_card,air_quality_card,hazards_list_screen}.dart`
- `lib/features/weather/weather_service.dart`
- `lib/features/hazards/{gdacs_service,eonet_service}.dart`
- `lib/features/mesh_comm/{mesh_chat_screen,mesh_radar_screen}.dart`
- `lib/features/triage/{triage_state,triage_wizard_screen}.dart`
- `lib/features/voice/speech_to_text_provider.dart`
- `lib/features/safe_beacon/{safety_status_service,safety_status_screen}.dart`
- `lib/features/shelter/widgets/shelter_route_info_card.dart`
- `lib/features/planner/family_profile.dart`
- `lib/core/admin_broadcast_service.dart`

For widgets: pass `BuildContext context` and use `AppLocalizations.of(context).keyName`. For services that don't have a context (notification, safe-beacon), inject `LocaleController` and resolve via `LocaleController.instance.languageCode`.

- [ ] **Step 1: For each file: write the ARB entries (Task 4.2), generate, replace each literal with `AppLocalizations.of(context).key`.**

- [ ] **Step 2: Run + commit at the end of each file**

```bash
flutter test 2>&1 | tail -5
flutter analyze --fatal-infos 2>&1 | tail -5
git add -A
git commit -m "chore(arb): move <file>'s user-facing copy into app_bn.arb/app_en.arb"
```

### Task 4.4: Phase 4 cleanup

- [ ] **Step 1: Confirm only the allow-list contains raw Bangla literals**

```bash
grep -rP "[\x{0980}-\x{09FF}]" lib --include="*.dart" -c \
  | grep -v ":0$" | grep -v "app_localizations_"
```

Expected: only `lib/app/theme.dart`, `lib/core/device_capability.dart`, `lib/features/chat/typewriter_text.dart` (all comment-only, allow-listed).

- [ ] **Step 2: Snapshot + commit**

```bash
echo "<count>" > AFTER-phase-4-bangla-count.txt
git add AFTER-phase-4-bangla-count.txt
git commit -m "chore(text): record final Bangla-literal count after phase 4"
```

---

## Phase 5 — Lint + sweep test

### Task 5.1: Add `custom_lint` as a dev-dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Add the dev-dep**

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
```

- [ ] **Step 2: Configure the plugin**

In `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

- [ ] **Step 3: Add an empty placeholder plugin package**

```bash
mkdir -p packages/shongjog_lints
cat > packages/shongjog_lints/pubspec.yaml <<'EOF'
name: shongjog_lints
description: Internal lint rules for Shongjog.
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  custom_lint_builder: ^0.7.0
EOF
cat > packages/shongjog_lints/lib/shongjog_lints.dart <<'EOF'
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'src/no_user_facing_bangla.dart';

PluginBase createPlugin() => _ShongjogLints();

class _ShongjogLints extends PluginBase {
  @override
  List<LintRule> get lintRules => const [NoUserFacingBangla()];
}
EOF
```

- [ ] **Step 4: Wire the package**

In `pubspec.yaml`:
```yaml
dev_dependencies:
  shongjog_lints:
    path: packages/shongjog_lints
```

- [ ] **Step 5: `flutter pub get` + commit**

```bash
flutter pub get
git add pubspec.yaml pubspec.lock analysis_options.yaml packages/shongjog_lints/
git commit -m "chore(lint): scaffold internal lint package shongjog_lints"
```

### Task 5.2: Implement the `no_user_facing_bangla` rule

**Files:**
- Create: `packages/shongjog_lints/lib/src/no_user_facing_bangla.dart`

- [ ] **Step 1: Implement the rule**

```dart
// packages/shongjog_lints/lib/src/no_user_facing_bangla.dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flag the use of Bengali script (U+0980..U+09FF) outside `lib/l10n/`,
/// loader files, and `/// | // | /* */` comments. Bengali in the source
/// outside these locations is a regression of the text-consolidation sweep.
class NoUserFacingBangla extends LintRule {
  const NoUserFacingBangla() : super(code: _code);

  static const _code = LintCode(
    'no_user_facing_bangla',
    'User-facing Bangla literals must live in lib/l10n/app_bn.arb or an '
    'assets/* JSON asset. Move the text into one of those sources and '
    'read it via AppLocalizations.of(context) or a TextLoader accessor. '
    'Allow-listed: generated app_localizations_*.dart, comment sites, '
    'loader files, and analyzer-internal excludes.',
  );

  static final _banglaRe = RegExp(r'[\u{0980}-\u{09FF}]', unicode: true);

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    final path = resolver.path;
    if (!path.endsWith('.dart')) return;

    final allowed = {
      // generated ARB classes
      RegExp(r'/lib/l10n/app_localizations(_bn|_en)?\.dart$'),
      // per-feature loaders explicitly run through the asset pipeline
      RegExp(r'/lib/.*_loader\.dart$'),
      RegExp(r'/lib/.*_loaders\.dart$'),
      // comment-only illustration sites; do not introduce new ones
      RegExp(r'/lib/app/theme\.dart$'),
      RegExp(r'/lib/core/device_capability\.dart$'),
      RegExp(r'/lib/features/chat/typewriter_text\.dart$'),
      RegExp(r'/lib/lints/.*\.dart$'),
    };
    if (allowed.any((re) => re.hasMatch(path))) return;

    final visitor = _AstVisitor(reporter);
    context.addPostRun(() => null); // no-op; kept symmetrical with conventions
    resolver
      .getFile()
      .visitChildren(visitor);
  }
}

class _AstVisitor extends GeneralizingAstVisitor<void> {
  _AstVisitor(this.reporter);
  final ErrorReporter reporter;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _check(node, node.value, node.offset);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // The literal segments between interpolation expressions.
    for (final element in node.elements) {
      if (element is InterpolationString) {
        _check(node, element.value, element.offset);
      }
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    for (final s in node.strings) {
      if (s is SimpleStringLiteral) {
        _check(node, s.value, s.offset);
      }
    }
    super.visitAdjacentStrings(node);
  }

  bool _check(AstNode node, String value, int offset) {
    if (NoUserFacingBangla._banglaRe.hasMatch(value)) {
      reporter.atOffset(
        offset: offset,
        length: value.length,
        errorCode: NoUserFacingBangla._code,
      );
      return true;
    }
    return false;
  }
}
```

- [ ] **Step 2: `cd packages/shongjog_lints && pub get && dart run custom_lint:build`**

```bash
cd packages/shongjog_lints
flutter pub get
dart run custom_lint:build
cd ../..
```

- [ ] **Step 3: Run the analyzer and confirm zero new violations**

```bash
dart run custom_lint 2>&1 | tail -10
```

Expected: nothing printed (zero violations) once Phase 4 is complete. If anything prints, fix it (probably a missed comment-only site → add to allowlist).

- [ ] **Step 4: Commit**

```bash
git add packages/shongjog_lints/
git commit -m "feat(lint): add no_user_facing_bangla rule"
```

### Task 5.3: Add the CI sweep test

**Files:**
- Create: `test/lint/no_scattered_bangla_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/lint/no_scattered_bangla_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Walks lib/**/*.dart and asserts no file outside the allow-list contains
/// Bengali-script literals (U+0980..U+09FF). This is the runtime companion
/// to the `no_user_facing_bangla` custom_lint rule. Both must stay green;
/// either failing fails CI.
void main() {
  test('no scattered Bangla literals outside allowlist', () {
    final banglaRe = RegExp(r'[\u{0980}-\u{09FF}]', unicode: true);
    final allowed = [
      RegExp(r'/lib/l10n/app_localizations(_bn|_en)?\.dart$'),
      RegExp(r'/lib/.*_loader\.dart$'),
      RegExp(r'/lib/.*_loaders\.dart$'),
      RegExp(r'/lib/app/theme\.dart$'),
      RegExp(r'/lib/core/device_capability\.dart$'),
      RegExp(r'/lib/features/chat/typewriter_text\.dart$'),
      RegExp(r'/lib/lints/.*\.dart$'),
      RegExp(r'/lib/core/text_loader\.dart$'),
    ];
    final offenders = <String>[];

    void walk(Directory d) {
      for (final ent in d.listSync(recursive: false)) {
        if (ent is Directory) {
          walk(ent);
        } else if (ent is File && ent.path.endsWith('.dart')) {
          if (allowed.any((re) => re.hasMatch(ent.path))) continue;
          final src = ent.readAsStringSync();
          // Strip line comments and block comments before scanning.
          final stripped = src
              .replaceAll(RegExp(r'///.*'), '')
              .replaceAll(RegExp(r'//.*'), '')
              .replaceAll(RegExp(r'/\*.*?\*/', dotMatchAll: true), '');
          if (banglaRe.hasMatch(stripped)) {
            offenders.add(ent.path);
          }
        }
      }
    }

    walk(Directory('lib'));

    expect(offenders, isEmpty,
        reason: 'Files contain raw Bangla literals outside the allowlist: '
            '${offenders.join("\n")}. Move the text into lib/l10n/app_bn.arb '
            'or an assets/* JSON asset and read it via AppLocalizations or '
            'TextLoader.');
  });
}
```

- [ ] **Step 2: Run**

```bash
flutter test test/lint/no_scattered_bangla_test.dart 2>&1 | tail -10
```

Expected: passes.

- [ ] **Step 3: Add a small file `test/lint/one_source_of_truth_test.dart`**

```dart
// test/lint/one_source_of_truth_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `*_prompt_builder.dart` should now be a thin wrapper that
/// delegates to a `lib/features/.../prompt_loader*.dart`. The body must
/// not contain Bangla literals — the test asserts each builder file's
/// src, after stripping comments, contains no Bengali script.
void main() {
  test('no prompt_builder file contains raw Bangla', () {
    final banglaRe = RegExp(r'[\u{0980}-\u{09FF}]', unicode: true);
    final offenders = <String>[];
    for (final ent in Directory('lib').listSync(recursive: true)) {
      if (ent is! File) continue;
      final n = ent.path;
      if (!n.endsWith('_prompt_builder.dart') &&
          !n.endsWith('prompt_builder.dart') &&
          !n.endsWith('prompt_loaders.dart')) {
        continue;
      }
      final src = ent.readAsStringSync()
        ..replaceAll(RegExp(r'///.*'), '')
        ..replaceAll(RegExp(r'//.*'), '')
        ..replaceAll(RegExp(r'/\*.*?\*/', dotMatchAll: true), '');
      if (banglaRe.hasMatch(src)) offenders.add(n);
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 4: Run + commit**

```bash
flutter test test/lint/ 2>&1 | tail -5
git add test/lint/
git commit -m "test(lint): no-scattered-bangla + one-source-of-truth sweep tests"
```

### Task 5.4: Phase 5 cleanup

- [ ] **Step 1: Full sweep**

```bash
flutter test 2>&1 | tail -5
flutter analyze --fatal-infos 2>&1 | tail -5
dart run custom_lint 2>&1 | tail -5
```

Expected: all three clean.

- [ ] **Step 2: Commit the snapshot**

```bash
echo "<count>" > AFTER-phase-5-bangla-count.txt
git add AFTER-phase-5-bangla-count.txt
git commit -m "chore(text): final lint-clean state"
```

---

## Phase 6 — Docs + final verification

### Task 6.1: Write `docs/content-i18n-sweep.md`

- [ ] **Step 1: Create the doc**

```markdown
# Shongjog Content & i18n Model

> **Audience:** anyone adding or changing user-facing strings, LLM prompts, or data tables in the Shongjog codebase.

## Rule of thumb

> All Bangla text comes from `lib/l10n/app_bn.arb`. All English text comes from `lib/l10n/app_en.arb`. All prompts come from `assets/prompts/*.json`. All data tables come from `assets/data/*.json`. Nowhere else.

## Where text lives

| Kind of text | Source file |
| --- | --- |
| UI strings (every `Text(widget, ...)` you see on a screen) | `lib/l10n/app_bn.arb` + `lib/l10n/app_en.arb` |
| Canned chat fallbacks, demo seeds, notification titles, safe-beacon defaults, SOS messages, admin tooltips, hazard labels, weather labels | same ARB pair as UI strings |
| LLM prompts (persona, planner, kit, risk, urgency, rumour, repetition, damage_scan, situation_summary, shelter) | `assets/prompts/<feature>.json` |
| Quick cards (titles + steps) | `assets/data/cards.json` |
| District names | `assets/data/districts.json` |
| Emergency directory | `assets/data/emergency_directory.json` |
| RAG corpus | `assets/data/corpus.json` |

## How to add a new string

### Add a new UI string

1. Choose a key in snake_case (e.g. `chatCannedCantAnswer`).
2. Add it to `app_bn.arb` with the Bangla value and a metadata block.
3. Add the same key to `app_en.arb` with the English value and a metadata block.
4. Run `flutter gen-l10n`.
5. Reference `AppLocalizations.of(context).chatCannedCantAnswer` in the widget tree.

### Add a new prompt

1. If the JSON file exists, add a key under both `bn` and `en`.
2. If the JSON file does not exist, create it with the same shape (see any existing `assets/prompts/<name>.json`).
3. Update the loader (`lib/features/.../prompt_loader*.dart`) to expose the new key.
4. Update the builder (`lib/features/.../*_prompt_builder.dart`) to read from the bundle.
5. Update the existing test to cover the new key in both locales.

### Add a new data table row

1. Locate the JSON file under `assets/data/`.
2. Append the new entry under both `bn` and `en` blocks.
3. If the row uses an icon not in the registry in `cards_loader.dart`, add it to the registry there.

## How to add a third locale

1. Add `app_xx.arb` to `lib/l10n/` mirroring the `app_bn.arb` structure.
2. Add a `xx` block next to each `bn`/`en` block in every `assets/prompts/*.json` and `assets/data/*.json` file.
3. Extend `TextLoader.pickBundle` to dispatch on the new locale tag.
4. Run `flutter gen-l10n`.
5. Re-run the lint sweep.

## How the lint enforces this

- `lib/lints/no_user_facing_bangla.dart` (custom_lint rule) flags raw Bangla literals outside the allow-list (the generated ARB classes, the loader files, and three document-only illustration sites).
- `test/lint/no_scattered_bangla_test.dart` does the same check at CI time so even a misconfigured IDE can't silently ignore the rule.
- `test/lint/one_source_of_truth_test.dart` asserts every `*_prompt_builder.dart` is a thin loader-wrapper, not a literal store.
```

- [ ] **Step 2: Commit**

```bash
git add docs/content-i18n-sweep.md
git commit -m "docs(content-i18n-sweep): describe new content model"
```

### Task 6.2: Update `docs/architecture.md`, `PROJECT-STATUS.md`, `CHANGELOG.md`, `README.md`

- [ ] **Step 1: Architecture**

In `docs/architecture.md`, add under "Module map" a new section **Content & i18n** that points to `docs/content-i18n-sweep.md` and lists the three asset roots (`lib/l10n/`, `assets/data/`, `assets/prompts/`).

- [ ] **Step 2: Project status**

In `docs/PROJECT-STATUS.md`, replace any stale "Cloud AI fallback" copy that lives in the Features area with the new content-model note.

- [ ] **Step 3: Changelog**

Append under `[Unreleased]`:

```markdown
### Changed

- **Text consolidation sweep.** All user-facing Bangla + English text now
  comes from one of:
  - `lib/l10n/app_bn.arb` + `lib/l10n/app_en.arb` (UI strings; wired through `gen-l10n`).
  - `assets/prompts/<name>.json` (LLM prompts, bilingual).
  - `assets/data/<name>.json` (quick cards, district lists, emergency directory, RAG corpus).
  - A `lib/core/text_loader.dart` (cached async JSON loader + locale dispatch) reads each one.
  - The new `custom_lint` rule `no_user_facing_bangla` and the CI sweep
    `test/lint/no_scattered_bangla_test.dart` enforce this; adding a new
    Bangla literal outside the allow-list fails CI.
```

- [ ] **Step 4: README**

Add a link to `docs/content-i18n-sweep.md` from `docs/README.md` (or the README's table of contents).

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "docs: reflect new content model across architecture/status/changelog/readme"
```

### Task 6.3: Final verification

- [ ] **Step 1: Clean re-run**

```bash
flutter clean
flutter pub get
flutter test 2>&1 | tail -5
flutter analyze --fatal-infos 2>&1 | tail -5
dart run custom_lint 2>&1 | tail -5
```

Expected: 955+ tests pass, no analyzer warnings, no custom_lint warnings.

- [ ] **Step 2: APK smoke build**

```bash
flutter build apk --debug 2>&1 | tail -10
```

Expected: builds cleanly. (Use `--debug` for speed; final release build is a follow-up.)

- [ ] **Step 3: Final snapshot + cleanup**

```bash
echo "<count>" > AFTER-text-consolidation-bangla-count.txt
git add AFTER-text-consolidation-bangla-count.txt
# Remove the BEFORE.md scratch file we created in Task 0.1, since it is in
# the index only as a transient build artefact.
git rm BEFORE.md BEFORE-bangla-count.txt
git commit -m "chore(text): remove pre-flight scratch files; record final Bangla count"
```

- [ ] **Step 4: Hand-off summary**

```bash
git log --oneline $(git log --grep="^chore(text): capture baseline" -1 --format=%H)..HEAD
```

Open a PR with the title **"Text consolidation: single source of truth for every string"** that includes the commit range, a summary of the new content model (link `docs/content-i18n-sweep.md`), and the three "after" snapshots.

---

## Appendix A — Files touched (final count)

- **New files (38):** 12 asset JSON files (4 data + 10 prompt minus the 2 already deleted from `assets/emergency/` and `assets/kb/`); 8 loader files; 1 lint rule; 1 ci test dir; 1 plan doc; 1 content-model doc; 2 sweep tests.
- **Modified files (~70):** every ARB file (2), every prompt builder (10), every data-table consumer (4 categories of screens), every UI screen that contained inline Bangla, plus `pubspec.yaml`, `analysis_options.yaml`, the four top-level docs.
- **Deleted files (2):** `assets/emergency/directory.json`, `assets/kb/corpus.json`.

## Appendix B — Risks + how this plan mitigates each

| Risk | Mitigation |
| --- | --- |
| Phase 1 loader scaffolding breaks the existing tests because `kSystemInstruction` becomes dynamic | Each call site is updated as part of Task 1.4's "Step 6"; the existing `prompt_builder_test.dart` is run at every commit checkpoint. |
| Phase 2 cards-loader breaks `quick_cards_screen_test.dart` because the test was synchronous | Task 2.1 ships a `cachedCards()` accessor + `staticCards(locale)` bridge so callers migrate to async without changing their tests. |
| Phase 3 prompts-loader breaks the bilingual parity of the existing tests | Every prompt test is updated to call the loader in both `bn` and `en`, asserting identical structural shape across locales. |
| Phase 4 ARB additions introduce drift between `app_bn.arb` and `app_en.arb` | Task 0.2 established the metadata-sync discipline; every new key is added to both ARBs in the same step. |
| Phase 5 lint rule has false positives for unavoidable cases | The allow-list covers the three known comment-only files and the loader family; future sites of this kind go on the list with a rationale in the PR. |
| The custom_lint package build requires extra setup | Task 5.1 scaffolds a real local package with its own pubspec; `dart run custom_lint` is run in CI from the project root. |
| The English-translated copy misses idioms or reads awkwardly | The existing `kaggle-writeup.md` review pipeline is run as a sanity check before the Phase 6 PR; copy is reviewed. |
| Phase 6 APK build runs out of disk | `flutter clean` is called as Phase 6 Step 1. |

---

## Appendix C — Universal Loader Recipe (for Phase 3 Tasks 3.2–3.5)

Phase 3 tasks 3.1 (Planner) is the **worked example**. Tasks 3.2 (Kit), 3.3 (Risk), 3.4 (Urgency / Rumour / Repetition) and 3.5 (Damage-scan / Situation-summary / Shelter) all follow **exactly the same five-artefact recipe** below. Substitute the strings and the feature name; do not deviate from the shape.

### C.1 Asset file (`assets/prompts/<feature>.json`)

```jsonc
{
  "bn": {
    // Every Bangla literal that used to live inside the *_prompt_builder.dart
    // moves here, keyed by a stable snake_case name. Keep the same strings —
    // no translation edits during the migration, just relocation.
    "intro": "...",
    "sectionA": "...",
    "listItem1": "...",
    "listItem2": "...",
    "tail": "..."
  },
  "en": {
    // English counterparts drafted in the same step. Keep the same key set
    // so the loader's pickBundle dispatch works without conditional code.
    "intro": "...",
    "sectionA": "...",
    "listItem1": "...",
    "listItem2": "...",
    "tail": "..."
  }
}
```

### C.2 Loader file (`lib/features/<area>/<feature>_loader.dart`)

```dart
import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/<feature>.json';

class <Feature>Bundle {
  // Typed surface — one field per top-level key in the bn/en block.
  final String intro;
  final String sectionA;
  final List<String> listItems;
  final String tail;

  const <Feature>Bundle({
    required this.intro,
    required this.sectionA,
    required this.listItems,
    required this.tail,
  });
}

<Feature>Bundle _decodeBundle(String raw, String? locale) {
  final outer = jsonDecode(raw) as Map<String, dynamic>;
  final block = TextLoader.pickBundle(outer, locale);
  return <Feature>Bundle(
    intro: block['intro'] as String,
    sectionA: block['sectionA'] as String,
    listItems: (block['listItems'] as List<dynamic>).cast<String>(),
    tail: block['tail'] as String,
  );
}

Future<<Feature>Bundle> load<Feature>Bundle(String? locale) {
  return TextLoader.loadJson<<Feature>Bundle>(
    _kAssetPath,
    (raw) => _decodeBundle(raw, locale),
  );
}
```

### C.3 Builder file (`lib/features/<area>/<feature>_prompt_builder.dart`)

```dart
//
// Prompt text now lives in assets/prompts/<feature>.json (bn+en). This file
// contains only the structure of the prompt.

import '<feature>_loader.dart';

class <Feature>PromptBuilder {
  <Feature>PromptBuilder._();

  static String buildSync(/* inputs */, <Feature>Bundle b) {
    final buf = StringBuffer()
      ..writeln(b.intro)
      ..writeln()
      ..writeln(b.sectionA);
    for (final line in b.listItems) {
      buf.writeln(line);
    }
    buf
      ..writeln()
      ..write(b.tail);
    return buf.toString();
  }
}
```

### C.4 Test file (`test/unit/<feature>_prompt_builder_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/text_loader.dart';
import 'package:shongjog/features/<area>/<feature>_loader.dart';
import 'package:shongjog/features/<area>/<feature>_prompt_builder.dart';

void main() {
  setUp(() => TextLoader.debugClearCache());

  test('buildSync for bn', () async {
    final b = await load<Feature>Bundle('bn');
    final out = <Feature>PromptBuilder.buildSync(/* inputs */, b);
    expect(out, contains(<a uniquely Bangla snippet from the asset>));
  });

  test('buildSync for en', () async {
    final b = await load<Feature>Bundle('en');
    final out = <Feature>PromptBuilder.buildSync(/* inputs */, b);
    expect(out, contains(<a uniquely English snippet from the asset>));
  });
}
```

### C.5 Call-site updates

Find every call to `<Feature>PromptBuilder.build*` and replace it with:

```dart
final bundle = await load<Feature>Bundle(localeController.languageCode);
final out = <Feature>PromptBuilder.buildSync(/* inputs */, bundle);
```

### C.6 Variables for each Phase 3 sub-task

| Task | Feature name | Loader / builder path | Inputs to `buildSync` |
| --- | --- | --- | --- |
| 3.2 | `kit` | `lib/features/planner/kit_prompt_loader.dart` + `kit_prompt_builder.dart` | existing `KitInputs` |
| 3.3 | `risk` | `lib/features/planner/risk_prompt_loader.dart` + `risk_prompt_builder.dart` | existing `RiskInputs` |
| 3.4a | `urgency` | `lib/rag/urgency_loader.dart` + `urgency_classifier.dart` | the user's query |
| 3.4b | `rumour` | `lib/rag/rumour_loader.dart` + `rumour_checker.dart` | the claim text |
| 3.4c | `repetition` | `lib/rag/repetition_loader.dart` + `repetition_detector.dart` | the candidate text (regex pulled from `regexPatterns.bn/en`) |
| 3.5a | `damage_scan` | `lib/features/damage_scanner/scan_loader.dart` + `damage_scan_service.dart` | the photo + caption |
| 3.5b | `situation_summary` | `lib/features/intelligence/summary_loader.dart` + `situation_summary_service.dart` | reports list |
| 3.5c | `shelter` | `lib/features/shelter/shelter_loaders.dart` + `shelter_brief_builder.dart` (and the four sibling files) | the shelter + query |

For each of these, paste the recipe in C.1–C.5 with the substitutions from the table above. No deviation from the five-artefact shape.
