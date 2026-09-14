# Emergency & Safety Systems

## 1. Deterministic Triage Wizard

The Triage Wizard ([`lib/features/triage/triage_wizard_screen.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/triage/triage_wizard_screen.dart)) is an offline medical first-aid decision tree built entirely in pure Dart (`lib/features/triage/decision_tree.dart`):

- **Zero LLM Risk**: Does not rely on on-device or cloud language models. It cannot hallucinate dosages, reverse triage priorities, or invent non-standard medical procedures.
- **8 Terminal Action Routes (`TriageRoute`)**:
  1. **CPR (`cpr`)**: Unconscious, non-breathing casualty. Immediate hands-only chest compressions (100–120 bpm metronome, 5–6 cm depth).
  2. **Severe Arterial Bleeding (`bleeding`)**: Direct wound pressure, sterile dressing, limb elevation, and tourniquet protocols.
  3. **Choking / Airway Obstruction (`choking`)**: Heimlich maneuver / 5 back blows followed by 5 abdominal thrusts.
  4. **Snakebite (`snakebite`)**: Immobilization with pressure bandage, no tourniquets, no incision, no suction, urgent anti-venom dispatch.
  5. **Drowning / Submersion (`drowning`)**: 5 initial rescue breaths followed by 30:2 CPR cycle. Never perform abdominal thrusts to drain water.
  6. **Burns (`burn`)**: Cool running clean water for 20+ minutes, sterile covering, blister preservation.
  7. **Unconscious but Breathing (`unconsciousBreathing`)**: Immediate placement in the recovery position (side-lying) to keep airway patent.
  8. **Immediate Emergency Escalation (`escalation999`)**: High-risk acute symptoms requiring immediate hospital dispatch.
- **Immediate Escalation**: Every terminal step features a prominent **৯৯৯ কল করুন (Call 999)** action button that directly launches the system dialer via `url_launcher`.

---

## 2. Slide-to-Confirm 999 Dialer

To prevent accidental emergency pocket dials during panic while ensuring immediate access in critical moments:

- **Implementation**: Embedded within the Emergency Sheet ([`lib/features/emergency/emergency_sheet.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/emergency/emergency_sheet.dart)).
- **Single GestureDetector Mechanism**: A smooth, drag-constrained slider that requires intentional rightward translation.
- **Multi-Stage Haptic Feedback**:
  - `50%`: Subtle tick haptic indicating movement.
  - `90%`: Distinct warning haptic indicating imminent trigger.
  - `100%`: Heavy confirmation haptic and immediate system call intent dispatch via `url_launcher` (`tel:999`).

---

## 3. SOS SMS Composer & GPS Encoding

When cellular voice channels are congested or signal strength is too weak for voice calls, SMS text messages often succeed due to lower bandwidth signaling channel delivery.

- **Automated GPS Fix**: Queries high-accuracy coordinates from `Geolocator`.
- **Location Encoding**: Automatically generates a standardized distress text ([`lib/features/emergency/sos_composer_screen.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/emergency/sos_composer_screen.dart)):
  ```
  [জরুরি সংকেত - Shongjog SOS]
  নাম: {UserName}
  ফোন: {UserPhone}
  অবস্থান: 22.3568° N, 91.7832° E
  ম্যাপ: https://maps.google.com/?q=22.3568,91.7832
  বার্তা: আমি বিপদে আছি, জরুরি সাহায্য প্রয়োজন!
  ```
- **SMS Queue**: If outbound network service is temporarily unavailable, messages are stored in [`lib/features/safe_beacon/sms_queue.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/safe_beacon/sms_queue.dart) for retry upon link recovery.

---

## 4. Offline Shelter GIS & Turn-by-Turn Navigation

- **263 Bundled Shelters**: Stored locally in GeoJSON format ([`assets/shelter/cyclone_shelters.geojson`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/assets/shelter/cyclone_shelters.geojson)). Includes coastal cyclone shelters, flood havens, and designated community schools across vulnerable districts.
- **Haversine Distance Ranking**: Pure-Dart spherical geometry calculates distance from current device coordinates to all 263 shelters in under 2 milliseconds.
- **Dual Map/List Views**: Segmented control allows switching between an interactive GIS map and a distance-sorted list view.
- **Offline Tile Cache**: Tiles downloaded while online are cached persistently via `CachedTileProvider`. When offline, the map renders cached tiles alongside stylized vector fallback basemaps.
- **OSRM Turn-by-Turn Routing**: Turn-by-turn directions generated via Open Source Routing Machine (OSRM) endpoints when connected, with distance and compass bearing guidance when offline.

---

## 5. Offline Quick Cards & Emergency Directory

- **25 Quick Cards** ([`lib/features/quick_cards/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/quick_cards)): Instant, expandable medical and survival cards covering ORS preparation, water purification, CPR, snakebites, burn treatment, fractures, heat stroke, and flood precautions.
- **22-Entry Offline Directory** ([`assets/emergency/directory.json`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/assets/emergency/directory.json)): Pre-packaged national numbers including National Emergency (999), Fire Service, Coast Guard, Disaster Management Control Room, Red Crescent, and Women & Child Support lines.
