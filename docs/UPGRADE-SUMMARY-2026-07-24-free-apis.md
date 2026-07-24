# Shongjog — Free-APIs Integration (2026-07-24)

**Source:** User asked to integrate all the free, key-less APIs found in
the API scan. Five services + one home-screen card, each with unit tests.

---

## What shipped

Six commits, each bisectable. One round = one focused commit per the
round-based-execution skill.

| # | Commit | What |
|---|--------|------|
| R1 | `9d7a5b9` | `feat(hazards): NASA EONET live-hazards service` |
| R2 | `f4c1fcc` | `feat(hazards): USGS earthquake service` |
| R3 | `76fb709` | `feat(environment): Open-Meteo air quality service` |
| R4 | `3d40f27` | `feat(environment): Open-Meteo marine wave-forecast service` |
| R5 | `d065551` | `feat(hazards): GDACS disaster alerts service` |
| R6 | `6e498b8` | `feat(home): live-hazards card surfaces EONET + USGS + GDACS` |

---

## The five services

All free, all key-less, all verified live with curl from this machine
on 2026-07-24 before integration. Each degrades to `null` on offline
or any transport/parse failure, matching the established
`WeatherService` pattern.

### Hazards (3)

1. **NASA EONET** — `lib/features/hazards/eonet_service.dart`
   - URL: `https://eonet.gsfc.nasa.gov/api/v3/events?status=open&bbox=...`
   - Returns: cyclones, floods, wildfires, volcanoes, earthquakes,
     landslides, droughts with geo-coordinates.
   - Default bbox: Bangladesh + Bay of Bengal cyclone basin.
   - 11 typed categories with Bangla labels + Material icon keys.

2. **USGS Earthquakes** — `lib/features/hazards/usgs_earthquake_service.dart`
   - URL: `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson`
   - Returns: last 30 days, M ≥ 4.0, within the Bangladesh bbox.
   - Severity bucket: light / moderate / strong, Bangla-labelled.
   - Pairs with the triage wizard's earthquake card.

3. **GDACS** — `lib/features/hazards/gdacs_service.dart`
   - URL: `https://www.gdacs.org/xml/rss.xml`
   - Returns: UN/JRC alerts with Green/Orange/Red severity.
   - RSS parsed with a lightweight regex (no XML dependency).
   - RFC-822 pubDate parser included (Dart's DateTime.parse can't handle it).
   - Filters to the Bangladesh bounding box after parsing.

### Environment (2)

4. **Open-Meteo Air Quality** — `lib/features/environment/air_quality_service.dart`
   - URL: `https://air-quality-api.open-meteo.com/v1/air-quality`
   - Returns: PM2.5, PM10, CO, NO2, SO2, O3, European AQI.
   - Severity bucket from WHO 2021 PM2.5 thresholds (5 levels, Bangla).

5. **Open-Meteo Marine** — `lib/features/environment/marine_service.dart`
   - URL: `https://marine-api.open-meteo.com/v1/marine`
   - Returns: 3-day wave-height + wave-direction forecast.
   - Cyclone-relevant for the southern coast (Cox's Bazar, Chittagong).
   - Wave-severity bucket: calm / moderate / rough / very rough.

---

## The home-screen card

`lib/features/home/live_hazards_card.dart` — a single "সতর্কতা" (warning)
card placed between the offline-message tile and the insights list on
the home screen. Pulls EONET + USGS + GDACS in parallel via
`Future.wait`, normalises each item into a common (icon, title, color,
weight) shape, sorts by urgency, and shows the top 3.

State matrix:
- **Offline** → card not rendered (no noise).
- **All 3 feeds failed** → tap-to-retry.
- **Feeds OK, 0 items** → green "এই মুহূর্তে কোনো ঝুঁকি নেই".
- **Feeds OK with items** → sorted top-3 list + "+N more" footer.

Air Quality and Marine services are shipped but not yet wired into a
card — see Next Steps.

---

## Before / after metrics

| Metric | Before | After | Δ |
|---|---|---|---|
| Tests passing | 357 | 402 | **+45** |
| `flutter analyze` (new files) | — | 0 issues | — |
| Dart files in `lib/` | 101 | 106 | +5 services |
| Network services | 3 (weather, OSRM, OSM tiles) | 8 | +5 |
| External APIs | 3 | 8 | +5 |
| API keys required | 0 | 0 | — |
| Home-screen cards | weather + tip + offline + insights | + live hazards | +1 |

---

## Verification

Every commit was followed by:
1. `flutter analyze` on the changed paths — 0 issues.
2. `flutter test` on the new test file — all pass.
3. `flutter test` (full suite) after R6 — 402 passed, 1 skipped, 0 failed.

The new services are pure-Dart and unit-tested without a device. The
home-screen card is presentation-only (all network logic lives in the
services) and is best verified on-device during demo prep.

---

## Next steps (user-owned)

1. **Wire Air Quality + Marine into cards.** The services exist and are
   tested; they need a small card widget each (mirror `WeatherCard`).
   Suggested placement: AQI as a chip inside the existing weather card,
   Marine as a collapsible card shown only when the user's GPS is near
   the southern coast.
2. **On-device smoke test of the live-hazards card.** Needs a phone
   with internet — confirm the parallel fetch, the empty-state, and
   the offline hide behaviour.
3. **Tap-to-detail.** Each hazard row currently shows title only. A
   future iteration could deep-link to the shelter map (for cyclones)
   or the triage wizard (for earthquakes).
4. **Refresh on connectivity change.** The card loads once on first
   build; consider re-fetching when `connectivityProvider` flips to
   online, so a user coming back online sees fresh hazards without a
   manual pull.

---

*All five APIs were live-verified with curl from this environment on
2026-07-24 before integration. None require a key. The INTERNET
permission was already in the manifest for the model download and the
existing weather/OSM/tiles paths — no manifest change was needed.*
