# Bilingual Localization Architecture

Shongjog is designed **Bangla-first** with full, comprehensive **English** localization across the entire application interface and AI pipeline.

---

## 1. UI Localization & State Management

Localization is managed dynamically without requiring an app restart:

- **LocaleController** ([`lib/core/locale_controller.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/core/locale_controller.dart)):
  - Manages the active `Locale` (`Locale('bn', 'BD')` vs `Locale('en', 'US')`).
  - Persists preference in `SharedPreferences` under key `language_code`.
  - Notifies listeners to trigger an instant reactive rebuild of the `MaterialApp` widget tree.
- **ARB Localization Templates**:
  - `lib/l10n/app_bn.arb`: 888 localized strings.
  - `lib/l10n/app_en.arb`: 834 localized strings.
  - Generates Flutter's type-safe `AppLocalizations` class.
- **Dynamic Feature String Loaders**:
  In addition to static ARB files, dynamic content bundles are loaded via specialized loaders:
  - `damage_scan_strings_loader.dart`: Localized damage labels and severity descriptions.
  - `shelter_strings_loader.dart`: Localized shelter types and capacity chips.
  - `situation_summary_strings_loader.dart`: Incident categories and briefing headers.
  - `cards_loader.dart`: 25 bilingual quick cards with full emergency instructions in both scripts.

---

## 2. Bilingual AI & Prompt Invariants

When the user switches language, the RAG and LLM pipeline automatically adapts its system prompt, context chunks, and generation rules ([`lib/rag/prompt_builder.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/rag/prompt_builder.dart) & [`assets/prompts/persona.json`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/assets/prompts/persona.json)):

```
                                  [ User Query ]
                                        │
                         Check Active App Locale & Query Script
                                  ├──► BANGLA (bn)
                                  │    • Inject chunk.text (Bangla)
                                  │    • Use Bengali numerals (০, ১, ২...)
                                  │    • Refusal: "আমি নিশ্চিত নই..."
                                  │    • Myth prefix: "না, এটি ভুল..."
                                  │
                                  └──► ENGLISH (en)
                                       • Inject chunk.textEn (English)
                                       • Use Arabic numerals (0, 1, 2...)
                                       • Refusal: "I'm not certain..."
                                       • Myth prefix: "No, that's wrong..."
```

### Invariant Rules for English Mode

1. **Context Chunk Selection**: All 48 chunks in `assets/kb/corpus.json` carry both `text` (Bangla) and `textEn` (English). When `localeCode == 'en'`, `PromptBuilder` injects `textEn` into the prompt, preventing the model from having to translate technical medical guidance on the fly.
2. **Language Mirroring**: The model is instructed to match the user's conversational language. If a user asks in English while the app is in English mode, the response must be 100% natural English. If a user asks in Banglish (phonetic Bengali written in Latin letters), the model replies in Bangla or clarifying English.
3. **Safe Refusal Standard**:
   - **Bangla**: *"আমি নিশ্চিত নই, দরকার হলে ৯৯৯ এ কল করুন।"*
   - **English**: *"I'm not certain. Call 999 for emergencies."*
4. **Direct Myth Refutation**:
   - **Bangla**: *"না, এটি ভুল..."*
   - **English**: *"No, that's wrong..."*
5. **Numeral Formatting**:
   - In Bangla mode, all quantities, telephone numbers, and distances must be rendered in Bengali numerals (`১, ২, ৩, ৪, ৫`).
   - In English mode, numbers are strictly rendered in standard Arabic digits (`1, 2, 3, 4, 5`).
