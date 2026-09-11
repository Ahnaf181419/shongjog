# Emergency & Safety Systems

## 1. Deterministic Triage Wizard

The Triage Wizard ([`lib/features/triage/triage_wizard_screen.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/triage/triage_wizard_screen.dart)) is an offline medical first-aid decision tree built entirely in pure Dart:

- **Zero LLM Risk**: Does not rely on on-device or cloud language models. It cannot hallucinate dosages, reverse triage priorities, or invent non-standard medical procedures.
- **8 Terminal Action Routes**:
  1. **Unconscious / No Breathing** ➔ Immediate CPR Guidance (Hands-only, 100-120 bpm metronome).
  2. **Severe Arterial Bleeding** ➔ Direct pressure, elevation, and tourniquet protocols.
  3. **Choking / Airway Obstruction** ➔ Heimlich maneuver & back blows.
  4. **Snakebite (Viper / Krait / Cobra)** ➔ Immobilization, no tourniquets, no incision, anti-venom center dispatch.
  5. **Drowning / Submersion** ➔ Rescue breaths, drainage avoidance, hypothermia prevention.
  6. **Severe Burn (Heat / Chemical / Electrical)** ➔ Cool running water, sterile cover, blister preservation.
  7. **Heat Stroke / Dehydration** ➔ Rapid cooling, ORS fluid replenishment.
  8. **Fracture / Spinal Trauma** ➔ Neutral alignment, rigid splinting, minimal movement.
- **Immediate Escalation**: Every terminal step features a prominent **৯৯৯ কল করুন (Call 999)** action button directly launching the phone dialer.

---

## 2. Slide-to-Confirm 999 Dialer

To prevent accidental emergency pocket dials during panic while ensuring immediate access in critical moments:

- **Implementation**: [`lib/features/emergency/emergency_dialer.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/emergency).
- **Single GestureDetector Mechanism**: A smooth, drag-constrained slider that requires intentional rightward translation.
- **Multi-Stage Haptic Feedback**:
  - `50%`: Subtle tick haptic indicating movement.
  - `90%`: Distinct warning haptic indicating imminent trigger.
  - `100%`: Heavy confirmation haptic and immediate system call intent dispatch via `url_launcher` (`tel:999`).

---

## 3. SOS SMS Composer & GPS Encoding

When cellular voice channels are jammed or signal strength is too weak for voice, SMS text messages often succeed due to signaling channel delivery.

- **Automated GPS Fix**: Queries high-accuracy location from `Geolocator`.
- **Location Encoding**: Automatically generates a standardized distress text:
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
- **Offline Tile Cache**: Tiles downloaded while online are cached persistently via `CachedNetworkTileProvider`. When offline, the map renders cached tiles alongside stylized vector fallback basemaps.
- **OSRM Turn-by-Turn Routing**: Turn-by-turn directions generated via Open Source Routing Machine (OSRM) endpoints when connected, with distance and compass bearing guidance when offline.

---

## 5. Offline Quick Cards & Emergency Directory

- **25 Quick Cards** ([`lib/features/quick_cards/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/quick_cards)): Instant, expandable medical and survival cards covering ORS preparation, water purification, CPR, snakebites, burn treatment, and flood precautions.
- **22-Entry Offline Directory** ([`assets/emergency/directory.json`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/assets/emergency/directory.json)): Pre-packaged national numbers including National Emergency (999), Fire Service, Coast Guard, Disaster Management Control Room, Red Crescent, and Women & Child Support lines.
