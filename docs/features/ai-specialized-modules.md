# Specialized AI Domain Modules

Beyond the central conversational assistant ([AI Chat](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/chat)), Shongjog provides **7 specialized AI modules** purpose-built for disaster preparedness, damage triage, and emergency response.

---

## The 7 Modules at a Glance

| # | Module | Implementation | Mode | Primary Engine | Deterministic Fallback |
|---|---|---|---|---|---|
| 1 | **Family Disaster Planner** | [`planner_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/planner_service.dart) | Offline | Gemma 4 on-device | `PlannerPromptBuilder.fallbackPlan` |
| 2 | **Emergency Kit Generator** | [`kit_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/kit_service.dart) | Offline | Gemma 4 on-device | `KitPromptBuilder.fallbackKit` |
| 3 | **AI Risk Assessment** | [`risk_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/risk_service.dart) | Offline | Gemma 4 on-device | `RiskPromptBuilder.fallbackScore` |
| 4 | **AI Damage Scanner** | [`damage_scan_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/damage_scanner/damage_scan_service.dart) | Cloud | Gemini 1.5/3.1 Multimodal | `DamageScanResult.unanalysable` |
| 5 | **AI Situation Summary** | [`situation_summary_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/intelligence/situation_summary_service.dart) | Offline | Gemma 4 on-device | `SituationSummaryService.fallbackSituationSummary` |
| 6 | **AI Shelter Brief** | [`shelter_brief_builder.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/shelter/shelter_brief_builder.dart) | Offline | Gemma 4 on-device | `ShelterBriefBuilder.fallbackBrief` |
| 7 | **AI Safety Re-Ranking** | [`shelter_safety_ranker.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/shelter/shelter_safety_ranker.dart) | Offline | Gemma 4 on-device | Haversine Spherical Distance Sorting |

---

## 1. Family Disaster Planner

- **File Location**: [`lib/features/planner/planner_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/planner_service.dart)
- **Input Context**: Takes a structured `FamilyProfile` (`family_profile.dart`) detailing total members, vulnerable household demographics (infants, elderly, pregnant women, pets, chronic medical dependencies), geographic district, and house structural category (tin-shed, earthen, brick, multi-story).
- **Inference & Execution**: Feeds structured parameters into `PlannerPromptBuilder.buildPrompt()`, invoking local Gemma 4 to formulate an actionable 4-phase plan:
  1. *Immediate Pre-Disaster Actions* (safe room selection, vital document protection).
  2. *Vulnerable Member Care* (baby food, essential medicines, mobility aids).
  3. *Evacuation Route & Trigger Criteria* (cyclone signal thresholds, flood line triggers).
  4. *Reunion Protocol* (predetermined meeting point, out-of-district contact).
- **Fail-Soft Guarantee**: If Gemma 4 is offline or uninstalled, `PlannerPromptBuilder.fallbackPlan()` immediately returns a fully formatted, rule-based evacuation plan derived from BDRCS guidelines.

---

## 2. AI Emergency Kit Generator

- **File Location**: [`lib/features/planner/kit_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/kit_service.dart)
- **Input Context**: Family member headcount, presence of infants/elderly, and targeted preparedness duration (e.g. 3 days vs 7 days).
- **Inference & Output**: Gemma 4 outputs an itemized, quantified emergency supply checklist in Bengali:
  - *Clean Drinking Water*: Exact liters calculated per person/day.
  - *Dry Food & Nutrition*: Non-perishable foods (chira, gur, biscuits, baby formula).
  - *Medical Supplies*: Specific quantities of ORS packets, water purification tablets (halazone), antiseptic, bandage rolls.
  - *Survival Hardware*: Torch/flashlight, extra batteries, whistle, waterproof matches, power bank.
- **Fail-Soft Guarantee**: `KitPromptBuilder.fallbackKit()` performs deterministic arithmetic calculation of rations and items if model inference is unavailable.

---

## 3. AI Risk Assessment

- **File Location**: [`lib/features/planner/risk_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/risk_service.dart)
- **Input Context**: User's home district, dwelling type (kacha / semi-pucca / pucca), floor level, distance to rivers or coastal embankments, and emergency reserve status.
- **Inference & Scoring (`RiskResult`)**:
  - Computes a holistic vulnerability score from **১ to ১০** (1–10).
  - Normalizes Bengali numerals (`০-৯`) to system integers.
  - Generates specific danger factor highlights (e.g., storm surge exposure, mud wall collapse vulnerability) and 3 prioritized mitigation actions.
- **Fail-Soft Guarantee**: `RiskPromptBuilder.fallbackScore()` evaluates risk via a deterministic heuristic matrix.

---

## 4. AI Damage Scanner (Multimodal Cloud Vision)

- **File Location**: [`lib/features/damage_scanner/damage_scan_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/damage_scanner/damage_scan_service.dart)
- **Input Context**: Image bytes (`Uint8List`) captured via camera or selected from device gallery.
- **Inference Pipeline**:
  - Dispatches image bytes as base64 `inline_data` to Gemini Vision API via `CloudAiService`.
  - Prompts model with a strict JSON schema requiring structural hazard classification:
    - `damageType`: `flood`, `fire`, `collapsedBuilding`, `fallenTree`, `roadBlocked`, or `unknown`.
    - `severity`: `low`, `medium`, `high`, or `critical`.
    - `confidence`: Confidence score (0.0 to 1.0).
    - `description`: Plain-language assessment of structural damage.
    - `recommendations`: Tactical safety advice (e.g., "Do not enter, risk of secondary collapse, isolate electrical main").
- **Offline / Failure Behavior**: Because local Gemma 4 E2B is text-only, damage scanning is explicitly marked as a cloud-assisted feature. If offline or if the image cannot be evaluated, it fails gracefully with `DamageScanResult.unanalysable()`.

---

## 5. AI Situation Summary

- **File Location**: [`lib/features/intelligence/situation_summary_service.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/intelligence/situation_summary_service.dart)
- **Input Context**: Aggregates recent local interactions, safety beacon statuses, recorded hazard reports, and distress pings.
- **Output**: Generates a unified, executive situational briefing:
  - Total local SOS pings within radius.
  - Primary emerging hazard (e.g. rapidly rising flood levels).
  - Recommended civil protection measures.
- **Fail-Soft Guarantee**: Uses `SituationSummaryService.fallbackSituationSummary()` to aggregate counts and format a deterministic status report without AI.

---

## 6. AI Shelter Brief

- **File Location**: [`lib/features/shelter/shelter_brief_builder.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/shelter/shelter_brief_builder.dart)
- **Input Context**: Tapped shelter metadata (name, capacity, current distance) combined with active GDACS alerts and nearby NASA EONET storm/flood hazards.
- **Inference & Output**: Uses local Gemma 4 to formulate a rapid 1–2 sentence contextual briefing when a user selects a shelter pin:
  - *Example*: *"এই আশ্রয়কেন্দ্রটি ৩.২ কিমি দূরে অবস্থিত। আশেপাশের রাস্তাটি জলমগ্ন হতে পারে, তাই অবিলম্বে রওয়ানা হওয়া নিরাপদ।"* (This shelter is 3.2 km away. Approaching roads may be submerged, recommend moving immediately).
- **Fail-Soft Guarantee**: `ShelterBriefBuilder.fallbackBrief()` produces a clean, localized template string.

---

## 7. AI Safety Re-Ranking

- **File Location**: [`lib/features/shelter/shelter_safety_ranker.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/shelter/shelter_safety_ranker.dart)
- **Problem Solved**: The nearest shelter by straight-line distance is not always the safest if an active storm surge, swollen river, or mudslide lies directly along the path.
- **Inference**: Gemma 4 is supplied with candidate shelters and active hazard bounding boxes. It outputs a reordered JSON array of shelter indices ranked by true path safety.
- **Fail-Soft Guarantee**: If inference fails, times out, or returns malformed JSON, the ranker immediately falls back to pure-Dart Haversine distance ranking without interrupting navigation.
