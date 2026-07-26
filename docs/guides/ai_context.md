# Shongjog — AI Context and Documentation Log

This document tracks recent technical changes, architectural fixes, and UI updates. It acts as an anchor for future AI development sessions to quickly understand the current state, constraints, and features of the app.

---

## 2026-07-15 — Recent UI, Logic, and Routing Updates

### 1. UI Additions
* **'Prosno korun' Header Height Reduction:** 
  * Reduced the vertical footprint/padding of the primary query header ("প্রশ্ন করুন") in the AI Chat screen (`chat_screen.dart`). This optimizes vertical space, making suggestion chips and previous messages more visible above the keyboard overlay.
* **Weather Forecast Widget Integration:**
  * Integrated a new connectivity-aware weather forecast tile (`WeatherCard` widget from `lib/features/weather/weather_card.dart`) on the `HomeScreen` bento grid layout. It uses `weather_service.dart` to fetch data from Open-Meteo when online and gracefully renders static placeholder indicators when offline.
* **Exhaustive Disaster Category Cards:**
  * Expanded the static list `kQuickCards` inside [cards_data.dart](file:///d:/Project/Team_Project/shongjog/lib/features/quick_cards/cards_data.dart) from 8 cards to 20 cards. The list now includes an exhaustive set of 12 new natural and man-made disaster cards: Flood (বন্যা), Cyclone/Tornado (ঘূর্ণিঝড়/টর্নেডো), Earthquake (ভূমিকম্প), Fire Incident (অগ্নিকাণ্ড), Landslide (ভূমিধস), Lightning Strike (বজ্রপাত), Riverbank Erosion (নদীভাঙন), Heatwave (তীব্র দাবদাহ), Cold Wave (শৈত্যপ্রবাহ), Tsunami (সুনামি), Drought (খরা), and Industrial/Chemical Disaster (রাসায়নিক দুর্ঘটনা).
  * Icons and descriptions perfectly match the existing design rules and source attribution constraints.

### 2. Logic & Localization Updates
* **Dynamic Emergency Card Subtitle:**
  * Modified the Emergency Card (`_TriadTile` under `_EmergencyTriad`) on the `HomeScreen` in [home_screen.dart](file:///d:/Project/Team_Project/shongjog/lib/features/home/home_screen.dart) to show a dynamic count of disaster cards instead of a hardcoded value.
  * Implemented a `_bnNum` conversion helper that converts `kQuickCards.length` (integer) into Bengali Unicode numerals (e.g. `20` to `২০`), rendering the dynamic subtitle string exactly as `'$countBnটি দ্রুত নির্দেশিকা'`.
* **Back Navigation and Routing Stack Fixes:**
  * Cleaned up the routing behavior to prevent loops and stack leaks when users hit the back button on sub-routes.
  * Ensured push routes (e.g., settings, emergency contacts, mesh radar) use `pushNamedSafe` / correct navigation pop checks so that users always return to the correct main shell tab without corrupting the underlying `IndexedStack` state.

---

### UI & Architecture Constraints for Future AI Sessions
* **Pure Dart Seams:** Keep core logic (retrievers, haversine distance math, prompt builders, SMS template builders) purely Dart-native (no `flutter/material.dart` or plugin imports) to ensure they remain fully unit-testable.
* **Offline-First Thesis:** No network requests inside the core chat loop. Any data fetching or background service must check connectivity status via `ConnectivityHelper` first and have an offline fallback.
* **Bangla Content Policy:** All user-facing copy must use Bengali Unicode characters, Bengali digits (`০-৯`), and danda (`।`) instead of Latin full stops. English is restricted to logs, code identifiers, and docs.
